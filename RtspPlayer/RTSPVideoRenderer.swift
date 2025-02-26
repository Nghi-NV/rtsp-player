//
//  RTSPVideoRenderer.swift
//  RtspPlayer
//
//  Created by Nghi Nguyen on 26/2/25.
//
import UIKit
import CoreMedia
import Foundation
import AVFoundation
import VideoToolbox
import AVKit

class RTSPVideoRenderer {
    private let width: Int
    private let height: Int
    private let codec: VideoCodec
    private var displayLayer: AVSampleBufferDisplayLayer?
    private var displayView: UIView?
    private var decoderSession: VTDecompressionSession?
    private var formatDescription: CMVideoFormatDescription?
    
    private var onFirstFrameRenderedCallback: (() -> Void)?
    private var firstFrameRendered = false
    
    private let rtpPacketQueue = DispatchQueue(label: "com.rtsp.packetQueue")
    private var isRunning = false
    
    // MARK: - Initialization
    init(width: Int, height: Int, codec: VideoCodec = .h264) {
        self.width = width
        self.height = height
        self.codec = codec
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    func setDisplayView(view: UIView) {
        self.displayView = view
        
        // Create AVSampleBufferDisplayLayer
        let layer = AVSampleBufferDisplayLayer()
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        
        // Add as sublayer
        DispatchQueue.main.async {
            view.layer.sublayers?.forEach { if $0 is AVSampleBufferDisplayLayer { $0.removeFromSuperlayer() } }
            view.layer.addSublayer(layer)
        }
        
        self.displayLayer = layer
        
        // Setup video decoder
        setupDecoder()
    }
    
    func setOnFirstFrameRenderedListener(callback: @escaping () -> Void) {
        self.onFirstFrameRenderedCallback = callback
    }
    
    func processRtpPacket(packet: Data) {
        guard isRunning else { return }
        
        rtpPacketQueue.async { [weak self] in
            self?.parseRtpPacket(packet)
        }
    }
    
    func stop() {
        isRunning = false
        
        // Cleanup decoder
        if let decoderSession = decoderSession {
            VTDecompressionSessionInvalidate(decoderSession)
            self.decoderSession = nil
        }
        
        // Cleanup display layer
        DispatchQueue.main.async { [weak self] in
            self?.displayLayer?.removeFromSuperlayer()
            self?.displayLayer = nil
        }
    }
    
    // MARK: - Private Methods
    private func setupDecoder() {
        // Setup video format description based on codec
        createVideoFormatDescription()
        
        // Create decompression session
        guard let formatDescription = formatDescription else { return }
        
        let decoderParameters = NSMutableDictionary()
        decoderParameters[kVTDecompressionPropertyKey_RealTime] = true
        
        var outputCallback = VTDecompressionOutputCallbackRecord()
        let callback: VTDecompressionOutputCallback = { (decompressionOutputCallback: UnsafeMutableRawPointer?, 
                                                       _: UnsafeMutableRawPointer?,
                                                       status: OSStatus,
                                                       flags: VTDecodeInfoFlags,
                                                       imageBuffer: CVImageBuffer?,
                                                       presentationTimeStamp: CMTime,
                                                       presentationDuration: CMTime) in
            guard let imageBuffer = imageBuffer, status == noErr else { return }
            let renderer = unsafeBitCast(decompressionOutputCallback, to: RTSPVideoRenderer.self)
            
            var sampleBuffer: CMSampleBuffer?
            var timingInfo = CMSampleTimingInfo(
                duration: presentationDuration,
                presentationTimeStamp: presentationTimeStamp,
                decodeTimeStamp: CMTime.invalid
            )
            
            let err = CMSampleBufferCreateForImageBuffer(
                allocator: kCFAllocatorDefault,
                imageBuffer: imageBuffer,
                dataReady: true,
                makeDataReadyCallback: nil,
                refcon: nil,
                formatDescription: renderer.formatDescription ?? "" as! CMVideoFormatDescription,
                sampleTiming: &timingInfo,
                sampleBufferOut: &sampleBuffer
            )
            
            if err == noErr, let sampleBuffer = sampleBuffer {
                renderer.displayDecodedFrame(sampleBuffer: sampleBuffer)
            }
        }
        outputCallback.decompressionOutputCallback = callback
        outputCallback.decompressionOutputRefCon = Unmanaged.passUnretained(self).toOpaque()
        
        var decoderSession: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: nil,
            imageBufferAttributes: nil,
            outputCallback: &outputCallback,
            decompressionSessionOut: &decoderSession
        )
        
        if status == noErr {
            self.decoderSession = decoderSession
            isRunning = true
        }
    }
    
    private func createVideoFormatDescription() {
        switch codec {
        case .h264:
            createH264FormatDescription()
        case .h265:
            createH265FormatDescription()
        case .unknown:
            // Default to H.264 if unknown
            createH264FormatDescription()
        }
    }
    
    private func createH264FormatDescription() {
        // Create a CMVideoFormatDescription for H.264 video
        // This would typically use the SPS/PPS from the H.264 stream
        
        let parameterSets: [Data] = [
            Data([0x00, 0x00, 0x00, 0x01, 0x67, 0x42, 0x00, 0x0A, 0xF8, 0x41, 0xA2]),  // SPS
            Data([0x00, 0x00, 0x00, 0x01, 0x68, 0xCE, 0x38, 0x80])                     // PPS
        ]
        
        let pointers: [UnsafePointer<UInt8>] = parameterSets.map { $0.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt8.self) } }
        let sizes: [Int] = parameterSets.map { $0.count }
        
        var formatDescription: CMFormatDescription?
        let status = CMVideoFormatDescriptionCreateFromH264ParameterSets(
            allocator: kCFAllocatorDefault,
            parameterSetCount: parameterSets.count,
            parameterSetPointers: pointers,
            parameterSetSizes: sizes,
            nalUnitHeaderLength: 4,
            formatDescriptionOut: &formatDescription
        )
        
        if status == noErr {
            self.formatDescription = formatDescription
        }
    }
    
    private func createH265FormatDescription() {
        // Create a CMVideoFormatDescription for H.265 (HEVC) video
        // This would typically use the VPS/SPS/PPS from the H.265 stream
        
        // Example parameter sets for HEVC (these are placeholders, real implementation would extract from stream)
        let parameterSets: [Data] = [
            Data([0x00, 0x00, 0x00, 0x01, 0x40, 0x01, 0x0c, 0x01, 0xff, 0xff]),  // VPS
            Data([0x00, 0x00, 0x00, 0x01, 0x42, 0x01, 0x01, 0x01, 0x60, 0x00]),  // SPS
            Data([0x00, 0x00, 0x00, 0x01, 0x44, 0x01, 0xc0, 0xf3, 0xc0])         // PPS
        ]
        
        let pointers: [UnsafePointer<UInt8>] = parameterSets.map { $0.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: UInt8.self) } }
        let sizes: [Int] = parameterSets.map { $0.count }
        
        var formatDescription: CMFormatDescription?
        
        if #available(iOS 11.0, *) {
            let status = CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                allocator: kCFAllocatorDefault,
                parameterSetCount: parameterSets.count,
                parameterSetPointers: pointers,
                parameterSetSizes: sizes,
                nalUnitHeaderLength: 4,
                extensions: nil,
                formatDescriptionOut: &formatDescription
            )
            
            if status == noErr {
                self.formatDescription = formatDescription
            }
        } else {
            print("HEVC decoding not supported on this iOS version. Requires iOS 11+")
            // Fall back to H.264 on older iOS versions
            createH264FormatDescription()
        }
    }
    
    private func parseRtpPacket(_ packet: Data) {
        // Simplified RTP packet parsing
        // In a real implementation, you'd need to:
        // 1. Parse RTP header (12 bytes)
        // 2. Handle RTP packet fragmentation (if needed)
        // 3. Extract NAL units according to codec
        // 4. Queue complete frames for decoding
        
        // Example - extract payload starting after RTP header (12 bytes)
        guard packet.count > 12 else { return }
        
        let payload = packet.subdata(in: 12..<packet.count)
        
        // Process video frame based on codec
        switch codec {
        case .h264:
            decodeH264Frame(payload)
        case .h265:
            decodeH265Frame(payload)
        case .unknown:
            // Default to H.264 if unknown
            decodeH264Frame(payload)
        }
    }
    
    private func decodeH264Frame(_ data: Data) {
        decodeVideoFrame(data)
    }
    
    private func decodeH265Frame(_ data: Data) {
        decodeVideoFrame(data)
    }
    
    private func decodeVideoFrame(_ data: Data) {
        guard let decoderSession = decoderSession else { return }
        
        // Create a CMBlockBuffer from the video data
        var blockBuffer: CMBlockBuffer?
        let status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: data.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: data.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        
        guard status == kCMBlockBufferNoErr, let blockBuffer = blockBuffer else { return }
        
        // Copy data into block buffer
        let dataPtr = [UInt8](data)
        CMBlockBufferReplaceDataBytes(with: dataPtr, blockBuffer: blockBuffer, offsetIntoDestination: 0, dataLength: data.count)
        
        // Create a CMSampleBuffer
        var sampleBuffer: CMSampleBuffer?
        var timingInfo = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: CMTime.invalid
        )
        
        let sampleBufferStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        )
        
        guard sampleBufferStatus == noErr, let sampleBuffer = sampleBuffer else { return }
        
        // Decode the frame
        let decodeFlags = VTDecodeFrameFlags._EnableAsynchronousDecompression
        VTDecompressionSessionDecodeFrame(decoderSession, sampleBuffer: sampleBuffer, flags: decodeFlags, frameRefcon: nil, infoFlagsOut: nil)
    }
    
    private func displayDecodedFrame(sampleBuffer: CMSampleBuffer) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let displayLayer = self.displayLayer else { return }
            
            let isReady: Bool
            if #available(iOS 18.0, *) {
                isReady = displayLayer.isReadyForMoreMediaData
            } else {
                isReady = displayLayer.isReadyForMoreMediaData
            }
            
            if isReady {
                displayLayer.enqueue(sampleBuffer)
                
                if !self.firstFrameRendered {
                    self.firstFrameRendered = true
                    self.onFirstFrameRenderedCallback?()
                }
            }
        }
    }
}
