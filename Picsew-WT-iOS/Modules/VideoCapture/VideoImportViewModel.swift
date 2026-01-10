import Foundation
import UIKit

class VideoImportViewModel {
    private let importer = VideoImporter.shared
    
    var statusMessage: String = "Tap to import video"
    var isPermissionGranted: Bool = false
    var extractedFrames: [UIImage] = []
    
    // 检查相册权限
    func checkPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        importer.checkPhotoLibraryPermission { [weak self] granted in
            self?.isPermissionGranted = granted
            completion(granted)
        }
    }
    
    // 提取视频帧
    func extractFrames(from videoURL: URL, completion: @escaping ([UIImage], Error?) -> Void) {
        importer.extractFrames(from: videoURL) { [weak self] frames, error in
            if let error = error {
                self?.statusMessage = "Error: \(error.localizedDescription)"
                completion([], error)
            } else {
                self?.extractedFrames = frames
                self?.statusMessage = "Extracted \(frames.count) frames"
                completion(frames, nil)
            }
        }
    }
}
