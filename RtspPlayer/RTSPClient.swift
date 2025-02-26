
//
//  Untitled.swift
//  RtspPlayer
//
//  Created by Nghi Nguyen on 26/2/25.
//
import UIKit

class RTSPClient {
    
    private var socket: Socket?
    private var videoRenderer: RTSPVideoRenderer?
    private var videoDisplayView: UIView?
    private var rtspUrl: URL?
    private var rtspUsername: String?
    private var rtspPassword: String?
    
    private var isStarted = false
    private var isConnecting = false
    private var isConnected = false
    
    private var width: Int = 0
    private var height: Int = 0
    private var videoCodec: VideoCodec = .unknown
    
    weak var delegate: RTSPClientDelegate?
    
    // MARK: - Initialization
    init() {}
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    func setCredentials(username: String, password: String) {
        self.rtspUsername = username
        self.rtspPassword = password
    }
    
    func setDataReceiveTimeout(timeout: Int) {
        // Set socket timeout
    }
    
    func setVideoDisplayView(view: UIView) {
        self.videoDisplayView = view
    }
    
    func start(url: URL) -> Bool {
        guard !isStarted, !isConnecting else { return false }
        
        self.rtspUrl = url
        isStarted = true
        isConnecting = true
        
        delegate?.onRtspStatusConnecting()
        
        // Create thread for RTSP connection
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.connectToServer()
        }
        
        return true
    }
    
    func stop() {
        guard isStarted else { return }
        
        isStarted = false
        isConnecting = false
        
        // Stop video renderer
        videoRenderer?.stop()
        videoRenderer = nil
        
        // Close socket
        socket?.close()
        socket = nil
        
        delegate?.onRtspStatusDisconnected()
    }
    
    // MARK: - Private Methods
    private func connectToServer() {
        guard let rtspUrl = rtspUrl else {
            handleConnectionFailure(message: "RTSP URL is not set")
            return
        }
        
        // Create socket connection
        socket = Socket()
        guard let socket = socket else {
            handleConnectionFailure(message: "Failed to create socket")
            return
        }
        
        do {
            try socket.connect(toHost: rtspUrl.host ?? "", onPort: Int32(rtspUrl.port ?? 554))
            
            // Send RTSP OPTIONS request
            if !sendOptionsRequest() {
                handleConnectionFailure(message: "Failed to send OPTIONS request")
                return
            }
            
            // Send RTSP DESCRIBE request
            if !sendDescribeRequest() {
                handleConnectionFailure(message: "Failed to send DESCRIBE request")
                return
            }
            
            // Send RTSP SETUP request
            if !sendSetupRequest() {
                handleConnectionFailure(message: "Failed to send SETUP request")
                return
            }
            
            // Send RTSP PLAY request
            if !sendPlayRequest() {
                handleConnectionFailure(message: "Failed to send PLAY request")
                return
            }
            
            // Create video renderer
            setupVideoRenderer()
            
            // Start receiving RTP packets
            startReceivingRtpPackets()
            
            isConnecting = false
            isConnected = true
            delegate?.onRtspStatusConnected()
            
        } catch {
            handleConnectionFailure(message: "Socket connection failed: \(error.localizedDescription)")
        }
    }
    
    private func setupVideoRenderer() {
        guard let videoDisplayView = videoDisplayView else {
            handleConnectionFailure(message: "Video display view is not set")
            return
        }
        
        videoRenderer = RTSPVideoRenderer(width: width, height: height, codec: videoCodec)
        videoRenderer?.setDisplayView(view: videoDisplayView)
        videoRenderer?.setOnFirstFrameRenderedListener { [weak self] in
            self?.delegate?.onRtspFirstFrameRendered()
        }
    }
    
    private func startReceivingRtpPackets() {
        // Start a separate thread to continuously receive RTP packets
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            while self.isConnected {
                guard let socket = self.socket, let videoRenderer = self.videoRenderer else { break }
                
                do {
                    let packet = try socket.readData(ofLength: 2048)
                    videoRenderer.processRtpPacket(packet: packet)
                } catch {
                    if self.isConnected {
                        self.handleConnectionFailure(message: "Failed to receive RTP packet: \(error.localizedDescription)")
                    }
                    break
                }
            }
        }
    }
    
    private func handleConnectionFailure(message: String) {
        isConnecting = false
        isConnected = false
        
        // Close socket
        socket?.close()
        socket = nil
        
        delegate?.onRtspStatusFailed(message: message)
    }
    
    // MARK: - RTSP Protocol Methods
    private func sendOptionsRequest() -> Bool {
        guard let socket = socket, let rtspUrl = rtspUrl else { return false }
        
        let request = "OPTIONS \(rtspUrl.absoluteString) RTSP/1.0\r\n" +
                      "CSeq: 1\r\n" +
                      "User-Agent: RTSPClientSwift\r\n\r\n"
        
        do {
            try socket.write(from: request)
            let response = try readRtspResponse()
            return response.contains("200 OK")
        } catch {
            return false
        }
    }
    
    private func sendDescribeRequest() -> Bool {
        guard let socket = socket, let rtspUrl = rtspUrl else { return false }
        
        var request = "DESCRIBE \(rtspUrl.absoluteString) RTSP/1.0\r\n" +
                      "CSeq: 2\r\n" +
                      "Accept: application/sdp\r\n" +
                      "User-Agent: RTSPClientSwift\r\n"
        
        // Add authorization if credentials provided
        if let username = rtspUsername, let password = rtspPassword {
            let authString = "\(username):\(password)"
            if let authData = authString.data(using: .utf8) {
                let base64Auth = authData.base64EncodedString()
                request += "Authorization: Basic \(base64Auth)\r\n"
            }
        }
        
        request += "\r\n"
        
        do {
            try socket.write(from: request)
            let response = try readRtspResponse()
            
            if response.contains("401 Unauthorized") {
                delegate?.onRtspStatusFailedUnauthorized()
                return false
            }
            
            if !response.contains("200 OK") {
                return false
            }
            
            // Parse SDP content to get video dimensions and codec
            parseSdpContent(response)
            return true
            
        } catch {
            return false
        }
    }
    
    private func sendSetupRequest() -> Bool {
        guard let socket = socket, let rtspUrl = rtspUrl else { return false }
        
        let request = "SETUP \(rtspUrl.absoluteString)/trackID=1 RTSP/1.0\r\n" +
                      "CSeq: 3\r\n" +
                      "Transport: RTP/AVP;unicast;client_port=5000-5001\r\n" +
                      "User-Agent: RTSPClientSwift\r\n\r\n"
        
        do {
            try socket.write(from: request)
            let response = try readRtspResponse()
            return response.contains("200 OK")
        } catch {
            return false
        }
    }
    
    private func sendPlayRequest() -> Bool {
        guard let socket = socket, let rtspUrl = rtspUrl else { return false }
        
        let request = "PLAY \(rtspUrl.absoluteString) RTSP/1.0\r\n" +
                      "CSeq: 4\r\n" +
                      "Range: npt=0.000-\r\n" +
                      "User-Agent: RTSPClientSwift\r\n\r\n"
        
        do {
            try socket.write(from: request)
            let response = try readRtspResponse()
            return response.contains("200 OK")
        } catch {
            return false
        }
    }
    
    private func readRtspResponse() throws -> String {
        guard let socket = socket else { throw NSError(domain: "RTSPClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Socket is nil"]) }
        
        var response = ""
        var buffer = Data(count: 4096)
        
        let bytesRead = try socket.read(into: &buffer)
        if bytesRead > 0 {
            response = String(data: buffer.prefix(bytesRead), encoding: .utf8) ?? ""
        }
        
        return response
    }
    
    private func parseSdpContent(_ response: String) {
        // Parse video dimensions from SDP content
        // Find video width and height
        if let rangeWidth = response.range(of: "width=(\\d+)", options: .regularExpression),
           let rangeHeight = response.range(of: "height=(\\d+)", options: .regularExpression) {
            
            let widthString = response[rangeWidth].replacingOccurrences(of: "width=", with: "")
            let heightString = response[rangeHeight].replacingOccurrences(of: "height=", with: "")
            
            width = Int(widthString) ?? 640
            height = Int(heightString) ?? 480
        } else {
            // Default values if not found
            width = 640
            height = 480
        }
        
        // Determine video codec
        if response.contains("H264") || response.contains("h264") || response.contains("avc1") {
            videoCodec = .h264
        } else if response.contains("H265") || response.contains("h265") || response.contains("HEVC") || response.contains("hevc") {
            videoCodec = .h265
        } else {
            videoCodec = .unknown
            print("Warning: Unknown video codec in SDP, defaulting to H.264")
            videoCodec = .h264
        }
    }
}
