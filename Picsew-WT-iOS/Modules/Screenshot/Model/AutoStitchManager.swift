import UIKit
import CoreImage

struct StitchResult {
    let stitchedImage: UIImage?
    let offsets: [CGFloat] // Each offset is the Y-coordinate where the next image starts relative to the current one's top
    let bottomStartOffsets: [CGFloat] // Each image starts from this Y-coordinate (to crop headers)
    let matchedIndices: [Int] // Indices that were successfully matched
    let error: Error?
}

class AutoStitchManager {
    static let shared = AutoStitchManager()
    
    // 自动寻找重合点并拼接
    func autoStitch(_ images: [UIImage], completion: @escaping (UIImage?, [CGFloat]?, [CGFloat]?, [Int]?, [UIImage]?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard images.count >= 2 else {
                let error = NSError(domain: "StitchError", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("stitch_need_2_images", comment: "")])
                completion(nil, nil, nil, nil, nil, error)
                return
            }
            
            // 尝试自动排序
            let reorderedImages = StitchAlgorithm.findBestSequence(images)
            let workingImages = reorderedImages
            
            var offsets: [CGFloat] = [0] // 每一张图在画布上的起始 Y 坐标
            var bottomStartOffsets: [CGFloat] = [0] // 每一张图自身开始显示的 Y 坐标（用于裁掉 header）
            var matchedIndices: [Int] = []
            
            for i in 0..<(workingImages.count - 1) {
                let topImage = workingImages[i]
                let bottomImage = workingImages[i+1]
                
                // 尝试寻找重合点
                if let result = StitchAlgorithm.findOverlap(topImage: topImage, bottomImage: bottomImage) {
                    let topImageCutY = result.topY
                    let bottomImageStartY = result.bottomY
                    
                    let nextImageCanvasY = offsets[i] + topImageCutY
                    
                    offsets.append(nextImageCanvasY)
                    bottomStartOffsets.append(bottomImageStartY)
                    matchedIndices.append(i + 1)
                } else {
                    let fallbackOffset = workingImages[i].size.height
                    let nextImageCanvasY = offsets[i] + fallbackOffset
                    
                    offsets.append(nextImageCanvasY)
                    bottomStartOffsets.append(0)
                }
            }
            
            // 计算总高度
            var totalHeight: CGFloat = 0
            for i in 0..<workingImages.count {
                let displayHeight = workingImages[i].size.height - bottomStartOffsets[i]
                if i == workingImages.count - 1 {
                    totalHeight = offsets[i] + displayHeight
                }
            }
            
            let maxWidth = workingImages.map { $0.size.width }.max() ?? 0
            
            UIGraphicsBeginImageContextWithOptions(CGSize(width: maxWidth, height: totalHeight), false, 1.0)
            
            for i in 0..<workingImages.count {
                let image = workingImages[i]
                let canvasY = offsets[i]
                let startY = bottomStartOffsets[i]
                
                let displayHeight: CGFloat
                if i < workingImages.count - 1 {
                    displayHeight = offsets[i+1] - offsets[i]
                } else {
                    displayHeight = image.size.height - startY
                }
                
                let cropHeight = (i < workingImages.count - 1) ? displayHeight + 1 : displayHeight
                
                if let cgImage = image.cgImage?.cropping(to: CGRect(x: 0, y: startY * image.scale, width: image.size.width * image.scale, height: cropHeight * image.scale)) {
                    let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
                    croppedImage.draw(at: CGPoint(x: (maxWidth - image.size.width) / 2, y: canvasY))
                } else {
                    image.draw(at: CGPoint(x: (maxWidth - image.size.width) / 2, y: canvasY))
                }
            }
            
            let finalImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let finalImage = finalImage {
                let hasOverlapWarning = matchedIndices.count < workingImages.count - 1
                let warning = hasOverlapWarning ? NSError(domain: "StitchWarning", code: 2, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("stitch_warning_auto_to_manual", comment: "")]) : nil
                completion(finalImage, offsets, bottomStartOffsets, matchedIndices, workingImages, warning)
            } else {
                let error = NSError(domain: "StitchError", code: 1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("stitch_failed", comment: "")])
                completion(nil, nil, nil, nil, nil, error)
            }
        }
    }
}
