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
    func autoStitch(_ images: [UIImage], completion: @escaping (UIImage?, [CGFloat]?, [CGFloat]?, [Int]?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard images.count >= 2 else {
                let error = NSError(domain: "StitchError", code: 0, userInfo: [NSLocalizedDescriptionKey: "需要至少2张图片进行拼接"])
                completion(nil, nil, nil, nil, error)
                return
            }
            
            var offsets: [CGFloat] = [0] // 每一张图在画布上的起始 Y 坐标
            var bottomStartOffsets: [CGFloat] = [0] // 每一张图自身开始显示的 Y 坐标（用于裁掉 header）
            var matchedIndices: [Int] = []
            
            var currentCanvasY: CGFloat = 0
            var hasOverlapWarning = false
            
            // 第一张图
            currentCanvasY = images[0].size.height
            
            for i in 0..<(images.count - 1) {
                let topImage = images[i]
                let bottomImage = images[i+1]
                
                // 尝试寻找重合点
                if let result = self.findOverlap(topImage: topImage, bottomImage: bottomImage) {
                    // result.topY: topImage 中匹配到的位置
                    // result.bottomY: bottomImage 中匹配到的位置
                    
                    // 我们将 topImage 在 result.topY 处切断
                    // 然后从 bottomImage 的 result.bottomY 处开始接上
                    
                    // 更新前一张图的 offset（实际上是调整画布位置）
                    // 之前的图已经摆好了，我们要确定下一张图的位置
                    let topImageCutY = result.topY
                    let bottomImageStartY = result.bottomY
                    
                    // 下一张图在画布上的位置 = 上一张图在画布上的起始位置 + 上一张图被裁切的位置
                    let nextImageCanvasY = offsets[i] + topImageCutY
                    
                    offsets.append(nextImageCanvasY)
                    bottomStartOffsets.append(bottomImageStartY)
                    matchedIndices.append(i + 1)
                    
                    print("AutoStitch: Image \(i) and \(i+1) - Matched! TopCut: \(topImageCutY), BottomStart: \(bottomImageStartY)")
                } else {
                    // 找不到重合点，直接接在后面
                    let fallbackOffset = images[i].size.height
                    let nextImageCanvasY = offsets[i] + fallbackOffset
                    
                    offsets.append(nextImageCanvasY)
                    bottomStartOffsets.append(0)
                    hasOverlapWarning = true
                    print("AutoStitch: Image \(i) and \(i+1) - No overlap found, fallback.")
                }
            }
            
            // 计算总高度
            var totalHeight: CGFloat = 0
            for i in 0..<images.count {
                let displayHeight = images[i].size.height - bottomStartOffsets[i]
                // 注意：中间的图还会被下一张图裁切，但最后一张图会显示到最后
                if i == images.count - 1 {
                    totalHeight = offsets[i] + displayHeight
                }
            }
            
            let maxWidth = images.map { $0.size.width }.max() ?? 0
            
            UIGraphicsBeginImageContextWithOptions(CGSize(width: maxWidth, height: totalHeight), false, 1.0)
            
            for i in 0..<images.count {
                let image = images[i]
                let canvasY = offsets[i]
                let startY = bottomStartOffsets[i]
                
                // 计算该张图片在画布上占据的高度
                let displayHeight: CGFloat
                if i < images.count - 1 {
                    // 每一张图显示的高度等于下一张图的起始位置减去当前图的起始位置
                    displayHeight = offsets[i+1] - offsets[i]
                } else {
                    // 最后一张图显示剩余所有部分
                    displayHeight = image.size.height - startY
                }
                
                // 裁切并绘制。为了防止由于浮点数舍入导致的 1 像素缝隙，我们在非最后一张图的高度上多加 1 像素重叠
                let cropHeight = (i < images.count - 1) ? displayHeight + 1 : displayHeight
                
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
                let warning = hasOverlapWarning ? NSError(domain: "StitchWarning", code: 2, userInfo: [NSLocalizedDescriptionKey: "部分图片未找到重合点"]) : nil
                completion(finalImage, offsets, bottomStartOffsets, matchedIndices, warning)
            } else {
                let error = NSError(domain: "StitchError", code: 1, userInfo: [NSLocalizedDescriptionKey: "拼接失败"])
                completion(nil, nil, nil, nil, error)
            }
        }
    }
    
    struct OverlapResult {
        let topY: CGFloat
        let bottomY: CGFloat
    }
    
    // 寻找两张图片的重合点
    private func findOverlap(topImage: UIImage, bottomImage: UIImage) -> OverlapResult? {
        guard let topCG = topImage.cgImage, let bottomCG = bottomImage.cgImage else { return nil }
        
        let scale: CGFloat = 0.2
        let topSmall = resizeCGImage(topCG, scale: scale)
        let bottomSmall = resizeCGImage(bottomCG, scale: scale)
        
        guard let topData = getPixelData(topSmall), let bottomData = getPixelData(bottomSmall) else { return nil }
        
        let topWidth = topSmall.width
        let topHeight = topSmall.height
        let bottomWidth = bottomSmall.width
        let bottomHeight = bottomSmall.height
        
        // 进一步减小忽略区域，以便识别到图片边缘（如阴影）
        let ignoreHeaderRatio = 0.15 
        let ignoreFooterRatio = 0.05 // 减小底部忽略，识别阴影
        
        let topIgnoreHeader = Int(Double(topHeight) * ignoreHeaderRatio)
        let topIgnoreFooter = Int(Double(topHeight) * ignoreFooterRatio)
        let bottomIgnoreHeader = Int(Double(bottomHeight) * ignoreHeaderRatio)
        let bottomIgnoreFooter = Int(Double(bottomHeight) * ignoreFooterRatio)
        
        let topContentStart = topIgnoreHeader
        let topContentEnd = topHeight - topIgnoreFooter
        let bottomContentStart = bottomIgnoreHeader
        let bottomContentEnd = bottomHeight - bottomIgnoreFooter
        
        let searchHeight = 60 // 增加搜索高度
        let minOverlap = 20  // 降低最小重合要求
        
        var bestTopY = -1
        var bestBottomY = -1
        var minDiff = Double.greatestFiniteMagnitude
        
        // 策略：在 bottomImage 的内容区域取一段，在 topImage 的内容区域寻找匹配
        // 我们取 bottomImage 的 [bottomContentStart, bottomContentStart + searchHeight] 这一段
        let sampleStart = bottomContentStart
        let sampleHeight = min(searchHeight, bottomContentEnd - sampleStart)
        
        if sampleHeight < minOverlap { return nil }
        
        for yOffset in topContentStart...(topContentEnd - sampleHeight) {
            var totalDiff: Double = 0
            var pixelCount: Double = 0
            
            for row in 0..<sampleHeight {
                let topRow = yOffset + row
                let bottomRow = sampleStart + row
                
                for col in stride(from: 0, to: min(topWidth, bottomWidth), by: 4) {
                    let topIdx = (topRow * topWidth + col) * 4
                    let bottomIdx = (bottomRow * bottomWidth + col) * 4
                    
                    if topIdx + 2 < topData.count && bottomIdx + 2 < bottomData.count {
                        let dr = abs(Int(topData[topIdx]) - Int(bottomData[bottomIdx]))
                        let dg = abs(Int(topData[topIdx+1]) - Int(bottomData[bottomIdx+1]))
                        let db = abs(Int(topData[topIdx+2]) - Int(bottomData[bottomIdx+2]))
                        totalDiff += Double(dr + dg + db)
                        pixelCount += 1
                    }
                }
            }
            
            let averageDiff = totalDiff / (pixelCount * 3.0)
            if averageDiff < minDiff {
                minDiff = averageDiff
                bestTopY = yOffset
                bestBottomY = sampleStart
            }
        }
        
        // 校验：阈值稍微放宽一点点
        if bestTopY != -1 && minDiff < 35.0 {
            let topYInOriginal = CGFloat(bestTopY) / scale
            let bottomYInOriginal = CGFloat(bestBottomY) / scale
            
            // 计算重合区域的总高度
            // 重合区域是从 topYInOriginal (第一张图) 和 bottomYInOriginal (第二张图) 开始的
            let remainingTopHeight = CGFloat(topCG.height) - topYInOriginal
            let remainingBottomHeight = CGFloat(bottomCG.height) - bottomYInOriginal
            let totalOverlapHeight = min(remainingTopHeight, remainingBottomHeight)
            
            // 用户反馈：把裁剪位置定义为重叠区域的一半
            let midOverlapHeight = totalOverlapHeight / 2.0
            
            let finalTopY = topYInOriginal + midOverlapHeight
            let finalBottomY = bottomYInOriginal + midOverlapHeight
            
            // 确保不会超出图片边界
            let safeTopY = max(0, min(CGFloat(topCG.height), finalTopY))
            let safeBottomY = max(0, min(CGFloat(bottomCG.height), finalBottomY))
            
            print("AutoStitch: Midpoint overlap cut. TotalOverlap: \(totalOverlapHeight), TopCut: \(safeTopY), BottomStart: \(safeBottomY)")
            
            return OverlapResult(
                topY: safeTopY,
                bottomY: safeBottomY
            )
        }
        
        return nil
    }
    
    private func resizeCGImage(_ image: CGImage, scale: CGFloat) -> CGImage {
        let width = Int(CGFloat(image.width) * scale)
        let height = Int(CGFloat(image.height) * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context?.makeImage() ?? image
    }
    
    private func getPixelData(_ image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }
}
