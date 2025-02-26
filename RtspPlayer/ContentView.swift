//
//  ContentView.swift
//  RtspPlayer
//
//  Created by Nghi Nguyen on 26/2/25.
//

import SwiftUI
import AVKit

struct RTSPPlayerView: UIViewRepresentable {
    private let rtspClient: RTSPClient
    
    init(url: URL) {
        rtspClient = RTSPClient()
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        rtspClient.setVideoDisplayView(view: view)
        rtspClient.delegate = context.coordinator
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Cập nhật view nếu cần
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, RTSPClientDelegate {
        private let parent: RTSPPlayerView
        
        init(_ parent: RTSPPlayerView) {
            self.parent = parent
        }
        
        func rtspClient(_ client: RTSPClient, didConnectTo url: URL) {
            print("Đã kết nối thành công đến: \(url)")
        }
        
        func rtspClient(_ client: RTSPClient, didDisconnectWith error: Error?) {
            if let error = error {
                print("Ngắt kết nối với lỗi: \(error)")
            } else {
                print("Đã ngắt kết nối")
            }
        }
        
        func rtspClient(_ client: RTSPClient, didReceiveFirstFrame size: CGSize) {
            print("Đã nhận frame đầu tiên với kích thước: \(size)")
        }
        
        func rtspClient(_ client: RTSPClient, didFailWithError error: Error) {
            print("Lỗi: \(error)")
        }
    }
}

struct ContentView: View {
    @State private var isPlaying = false
    @State private var urlString = "rtsp://example.com/stream"
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if let url = URL(string: urlString), isPlaying {
                    RTSPPlayerView(url: url)
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(maxWidth: .infinity)
                        .frame(height: 300)
                        .cornerRadius(12)
                        .overlay(
                            Image(systemName: "video.slash")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
                
                Form {
                    Section(header: Text("Cấu hình RTSP")) {
                        TextField("URL RTSP", text: $urlString)
                            .textContentType(.URL)
                            .autocapitalization(.none)
                        
                        TextField("Tên đăng nhập", text: $username)
                            .textContentType(.username)
                            .autocapitalization(.none)
                        
                        SecureField("Mật khẩu", text: $password)
                            .textContentType(.password)
                    }
                    
                    Section {
                        Button(action: togglePlayback) {
                            HStack {
                                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                                Text(isPlaying ? "Dừng" : "Phát")
                            }
                            .foregroundColor(isPlaying ? .red : .blue)
                        }
                    }
                }
            }
            .navigationTitle("RTSP Player Demo")
            .alert("Lỗi", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func togglePlayback() {
        guard let url = URL(string: urlString) else {
            showError(message: "URL không hợp lệ")
            return
        }
        
        isPlaying.toggle()
        if isPlaying {
            startPlayback(url: url)
        } else {
            stopPlayback()
        }
    }
    
    private func startPlayback(url: URL) {
        // Bắt đầu phát video
        if !username.isEmpty && !password.isEmpty {
            // Thiết lập thông tin đăng nhập nếu có
        }
    }
    
    private func stopPlayback() {
        // Dừng phát video
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

#Preview {
    ContentView()
}
