import Foundation
import UIKit

class AutoStitchViewModel {
    private let stitchManager = AutoStitchManager.shared
    
    var images: [UIImage] = []
    var statusMessage: String = "Import images to stitch"
    var stitchedImage: UIImage?
    
    // 自动拼接图片
    func autoStitch(completion: @escaping (UIImage?, Error?) -> Void) {
        stitchManager.autoStitch(images) { [weak self] stitchedImage, error in
            if let error = error {
                self?.statusMessage = "Error: \(error.localizedDescription)"
                completion(nil, error)
            } else if let stitchedImage = stitchedImage {
                self?.statusMessage = "Stitching completed"
                self?.stitchedImage = stitchedImage
                completion(stitchedImage, nil)
            }
        }
    }
    
    // 添加图片
    func addImages(_ newImages: [UIImage]) {
        images.append(contentsOf: newImages)
        statusMessage = "Imported \(images.count) images"
    }
    
    // 清空图片
    func clearImages() {
        images.removeAll()
        stitchedImage = nil
        statusMessage = "Import images to stitch"
    }
}
