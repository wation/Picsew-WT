import UIKit
import Photos
import AVFoundation
import UniformTypeIdentifiers

class VideoImporter: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    static let shared = VideoImporter()
    
    private var completion: ((URL?, Error?) -> Void)?
    
    // 检查相册访问权限
    func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    completion(true)
                case .denied, .restricted, .notDetermined:
                    completion(false)
                @unknown default:
                    completion(false)
                }
            }
        }
    }
    
    // 打开视频选择器
    func openVideoPicker(from viewController: UIViewController, completion: @escaping (URL?, Error?) -> Void) {
        self.completion = completion
        
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.mediaTypes = [UTType.movie.identifier]
        imagePicker.delegate = self
        
        viewController.present(imagePicker, animated: true, completion: nil)
    }
    
    // 从视频URL提取帧
    func extractFrames(from videoURL: URL, interval: TimeInterval = 1.0, completion: @escaping ([UIImage], Error?) -> Void) {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        
        let duration = asset.duration.seconds
        var frames: [UIImage] = []
        var times: [NSValue] = []
        
        // 生成提取时间点
        var currentTime: TimeInterval = 0
        while currentTime < duration {
            let time = CMTime(seconds: currentTime, preferredTimescale: 600)
            times.append(NSValue(time: time))
            currentTime += interval
        }
        
        // 提取帧
        generator.generateCGImagesAsynchronously(forTimes: times) { [weak self] time, image, _, result, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion([], error)
                }
                return
            }
            
            if let image = image {
                let uiImage = UIImage(cgImage: image)
                frames.append(uiImage)
            }
            
            // 检查是否完成所有提取
            if frames.count == times.count {
                DispatchQueue.main.async {
                    completion(frames, nil)
                }
            }
        }
    }
    
    // UIImagePickerControllerDelegate 方法
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        if let videoURL = info[.mediaURL] as? URL {
            completion?(videoURL, nil)
        } else {
            let error = NSError(domain: "VideoImportError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get video URL"])
            completion?(nil, error)
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
        let error = NSError(domain: "VideoImportError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Import cancelled"])
        completion?(nil, error)
    }
}
