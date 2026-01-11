import Foundation
import UIKit

class ManualStitchViewModel {
    var images: [UIImage] = []
    var statusMessage: String = "Import images to manually stitch"
    
    // 添加图片
    func addImages(_ newImages: [UIImage]) {
        images.append(contentsOf: newImages)
        statusMessage = "Imported \(images.count) images"
    }
    
    // 清空图片
    func clearImages() {
        images.removeAll()
        statusMessage = "Import images to manually stitch"
    }
    
    // 检查是否可以开始拼接
    func canStartStitching() -> Bool {
        return !images.isEmpty
    }
}
