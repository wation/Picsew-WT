import UIKit
import ReplayKit

class VideoCaptureManager: NSObject, RPPreviewViewControllerDelegate {
    static let shared = VideoCaptureManager()
    
    private var screenRecorder: RPScreenRecorder {
        return RPScreenRecorder.shared()
    }
    
    private var isRecording = false
    private var videoURL: URL?
    
    // 检查屏幕录制权限
    func checkScreenRecordingPermission(completion: @escaping (Bool) -> Void) {
        let hasPermission = screenRecorder.isAvailable
        completion(hasPermission)
    }
    
    // 开始屏幕录制
    func startRecording(completion: @escaping (Error?) -> Void) {
        guard screenRecorder.isAvailable else {
            let error = NSError(domain: "VideoCaptureError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Screen recording is not available"])
            completion(error)
            return
        }
        
        screenRecorder.startRecording(handler: completion)
        isRecording = true
    }
    
    // 停止屏幕录制
    func stopRecording(completion: @escaping (URL?, Error?) -> Void) {
        guard isRecording else {
            let error = NSError(domain: "VideoCaptureError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not recording"])
            completion(nil, error)
            return
        }
        
        screenRecorder.stopRecording { [weak self] (previewViewController, error) in
            guard let self = self else { return }
            
            if let error = error {
                completion(nil, error)
                return
            }
            
            if let previewViewController = previewViewController {
                previewViewController.previewControllerDelegate = self
                self.isRecording = false
                
                // 获取视频URL
                // 注意：在实际应用中，需要通过保存预览视图控制器中的视频来获取URL
                // 这里简化处理，返回一个临时URL
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("recording.mp4")
                self.videoURL = tempURL
                completion(tempURL, nil)
            } else {
                let error = NSError(domain: "VideoCaptureError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to stop recording"])
                completion(nil, error)
            }
        }
    }
    
    // 取消屏幕录制
    func cancelRecording() {
        screenRecorder.discardRecording { [weak self] in
            self?.isRecording = false
            self?.videoURL = nil
        }
    }
    
    // RPPreviewViewControllerDelegate 方法
    func previewControllerDidFinish(_ previewController: RPPreviewViewController) {
        previewController.dismiss(animated: true, completion: nil)
    }
}
