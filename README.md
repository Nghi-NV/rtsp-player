# RTSP Player cho iOS

Thư viện này cung cấp một giải pháp đơn giản để phát video RTSP trên iOS, hỗ trợ cả H.264 và H.265 (HEVC).

## Tính năng

- Hỗ trợ streaming RTSP
- Hỗ trợ codec H.264 và H.265 (HEVC)
- Xử lý video hardware-accelerated
- Tùy chỉnh hiển thị video
- Xử lý authentication
- Quản lý kết nối tự động

## Yêu cầu

- iOS 11.0+
- Xcode 12.0+
- Swift 5.0+

## Cài đặt

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/RtspPlayer.git", from: "1.0.0")
]
```

## Cách sử dụng

### Khởi tạo và cấu hình

```swift
import RtspPlayer

class ViewController: UIViewController {
    @IBOutlet weak var videoContainerView: UIView!
    private var rtspClient: RTSPClient!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupRTSPClient()
    }
    
    private func setupRTSPClient() {
        rtspClient = RTSPClient()
        rtspClient.delegate = self
        
        // Thiết lập thông tin đăng nhập nếu cần
        rtspClient.setCredentials(username: "user", password: "pass")
        
        // Thiết lập view để hiển thị video
        rtspClient.setVideoDisplayView(view: videoContainerView)
    }
}
```

### Kết nối và phát video

```swift
// Kết nối đến server RTSP
if let url = URL(string: "rtsp://example.com/stream") {
    rtspClient.start(url: url)
}

// Dừng kết nối khi không cần thiết
rtspClient.stop()
```

### Xử lý sự kiện

```swift
extension ViewController: RTSPClientDelegate {
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
```

### Tùy chỉnh hiển thị video

```swift
// Trong ViewController

override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    
    // Cập nhật kích thước view video khi orientation thay đổi
    videoContainerView.frame = view.bounds
    rtspClient.updateVideoLayout()
}

// Tùy chỉnh chế độ hiển thị video
rtspClient.setVideoGravity(.resizeAspect) // hoặc .resizeAspectFill, .resize
```

## Xử lý lỗi thường gặp

1. Không kết nối được:
   - Kiểm tra URL RTSP có chính xác không
   - Kiểm tra thông tin đăng nhập
   - Kiểm tra kết nối mạng

2. Không hiển thị video:
   - Kiểm tra codec có được hỗ trợ không
   - Kiểm tra quyền truy cập camera/microphone
   - Kiểm tra view hierarchy

3. Video bị lag:
   - Kiểm tra chất lượng mạng
   - Giảm độ phân giải hoặc bitrate
   - Kiểm tra CPU/Memory usage

## Đóng góp

Mọi đóng góp đều được hoan nghênh. Vui lòng:

1. Fork repository
2. Tạo branch mới (`git checkout -b feature/AmazingFeature`)
3. Commit thay đổi (`git commit -m 'Add some AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Tạo Pull Request

## License

Project được phân phối dưới license MIT. Xem `LICENSE` để biết thêm chi tiết.

## Liên hệ

Nghi Nguyen - [@nghinguyen](https://twitter.com/nghinguyen)

Project Link: [https://github.com/yourusername/RtspPlayer](https://github.com/yourusername/RtspPlayer)