import Foundation

class VideoCaptureViewModel {
    private let captureManager = VideoCaptureManager.shared
    
    var isRecording: Bool = false
    var statusMessage: String = "Ready to record"
    
    // 检查屏幕录制权限
    func checkPermission(completion: @escaping (Bool) -> Void) {
        captureManager.checkScreenRecordingPermission(completion: completion)
    }
    
    // 开始录制
    func startRecording(completion: @escaping (Error?) -> Void) {
        captureManager.startRecording { [weak self] error in
            if let error = error {
                self?.statusMessage = "Error: \(error.localizedDescription)"
                completion(error)
            } else {
                self?.isRecording = true
                self?.statusMessage = "Recording..."
                completion(nil)
            }
        }
    }
    
    // 停止录制
    func stopRecording(completion: @escaping (URL?, Error?) -> Void) {
        captureManager.stopRecording { [weak self] videoURL, error in
            if let error = error {
                self?.statusMessage = "Error: \(error.localizedDescription)"
                completion(nil, error)
            } else if let videoURL = videoURL {
                self?.isRecording = false
                self?.statusMessage = "Recording saved"
                completion(videoURL, nil)
            }
        }
    }
    
    // 取消录制
    func cancelRecording() {
        captureManager.cancelRecording()
        isRecording = false
        statusMessage = "Recording cancelled"
    }
}
