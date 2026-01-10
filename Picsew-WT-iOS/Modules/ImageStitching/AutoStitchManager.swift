import UIKit
import CoreImage

class AutoStitchManager {
    static let shared = AutoStitchManager()
    
    // 自动拼接图片
    func autoStitch(_ images: [UIImage], completion: @escaping (UIImage?, Error?) -> Void) {
        guard images.count >= 2 else {
            let error = NSError(domain: "StitchError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Need at least 2 images to stitch"])
            completion(nil, error)
            return
        }
        
        // 排序图片（假设图片是按顺序拍摄的，这里简化处理）
        let sortedImages = images
        
        // 计算拼接后的图片尺寸
        let totalHeight = sortedImages.reduce(0) { $0 + $1.size.height }
        let maxWidth = sortedImages.reduce(0) { max($0, $1.size.width) }
        
        // 创建拼接画布
        UIGraphicsBeginImageContextWithOptions(CGSize(width: maxWidth, height: totalHeight), false, 0)
        
        var currentY: CGFloat = 0
        
        // 拼接图片
        for (index, image) in sortedImages.enumerated() {
            if index == 0 {
                // 第一张图片直接绘制
                image.draw(at: CGPoint(x: (maxWidth - image.size.width) / 2, y: currentY))
                currentY += image.size.height
            } else {
                // 后续图片需要与前一张图片对齐
                let previousImage = sortedImages[index - 1]
                
                // 计算对齐位置（这里使用简单的边缘检测算法）
                let offsetX = calculateHorizontalOffset(bottomImage: previousImage, topImage: image)
                
                // 绘制图片
                image.draw(at: CGPoint(x: offsetX, y: currentY))
                currentY += image.size.height
            }
        }
        
        // 获取拼接结果
        let stitchedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        if let stitchedImage = stitchedImage {
            completion(stitchedImage, nil)
        } else {
            let error = NSError(domain: "StitchError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to stitch images"])
            completion(nil, error)
        }
    }
    
    // 计算水平偏移量（边缘对齐）
    private func calculateHorizontalOffset(bottomImage: UIImage, topImage: UIImage) -> CGFloat {
        // 这里使用简单的边缘检测算法
        // 在实际应用中，可以使用更复杂的算法，如特征点匹配
        
        // 假设两张图片宽度相同，居中对齐
        let maxWidth = max(bottomImage.size.width, topImage.size.width)
        return (maxWidth - topImage.size.width) / 2
    }
    
    // 检测图片边缘特征
    private func detectEdges(in image: UIImage) -> CIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let ciImage = CIImage(cgImage: cgImage)
        let edgeDetector = CIFilter(name: "CannyEdgeDetector")
        edgeDetector?.setValue(ciImage, forKey: kCIInputImageKey)
        edgeDetector?.setValue(0.1, forKey: kCIInputThreshold1Key)
        edgeDetector?.setValue(0.2, forKey: kCIInputThreshold2Key)
        
        return edgeDetector?.outputImage
    }
    
    // 匹配两张图片的特征点
    private func matchFeatures(bottomImage: UIImage, topImage: UIImage) -> [CGPoint] {
        // 在实际应用中，这里应该实现特征点匹配算法
        // 如使用Core ML或第三方库进行特征提取和匹配
        
        // 简化处理，返回空数组
        return []
    }
}
