import UIKit
import CoreImage

struct StitchResult {
    let stitchedImage: UIImage?
    let offsets: [CGFloat] // Each offset is the Y-coordinate where the next image starts relative to the current one's top
    let error: Error?
}

class AutoStitchManager {
    static let shared = AutoStitchManager()
    
    // 自动寻找重合点并拼接
    func autoStitch(_ images: [UIImage], completion: @escaping (UIImage?, [CGFloat]?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard images.count >= 2 else {
                let error = NSError(domain: "StitchError", code: 0, userInfo: [NSLocalizedDescriptionKey: "需要至少2张图片进行拼接"])
                completion(nil, nil, error)
                return
            }
            
            var offsets: [CGFloat] = [0] // 第一张图片的起始位置（相对于画布顶部）
            var currentY: CGFloat = 0
            var hasOverlapWarning = false
            
            for i in 0..<(images.count - 1) {
                let topImage = images[i]
                let bottomImage = images[i+1]
                
                // 尝试寻找重合点
                if let overlapY = self.findOverlap(topImage: topImage, bottomImage: bottomImage) {
                    // overlapY 是 bottomImage 相对于 topImage 顶部的偏移量
                    currentY += overlapY
                    offsets.append(currentY)
                    print("AutoStitch: Image \(i) and \(i+1) - Found overlap, offset: \(overlapY), total Y: \(currentY)")
                } else {
                    // 找不到重合点，使用兜底逻辑：将 bottomImage 接在 topImage 的底部
                    // 所以偏移量就是 topImage 的完整高度
                    let fallbackOffset = topImage.size.height
                    currentY += fallbackOffset
                    offsets.append(currentY)
                    hasOverlapWarning = true
                    print("AutoStitch: Image \(i) and \(i+1) - No overlap found, fallback offset: \(fallbackOffset), total Y: \(currentY)")
                }
            }
            
            // 最后一张图片的完整高度也需要算上
            let totalHeight = offsets.last! + images.last!.size.height
            let maxWidth = images.map { $0.size.width }.max() ?? 0
            
            UIGraphicsBeginImageContextWithOptions(CGSize(width: maxWidth, height: totalHeight), false, 1.0) // 使用 1.0 scale 减少内存占用
            
            for (index, image) in images.enumerated() {
                let y = offsets[index]
                image.draw(at: CGPoint(x: (maxWidth - image.size.width) / 2, y: y))
            }
            
            let finalImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let finalImage = finalImage {
                if hasOverlapWarning {
                    // 返回警告信息，不影响拼接结果
                    let warning = NSError(domain: "StitchWarning", code: 2, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("no_overlap_found", comment: "没有找到重合点")])
                    completion(finalImage, offsets, warning)
                } else {
                    completion(finalImage, offsets, nil)
                }
            } else {
                let error = NSError(domain: "StitchError", code: 1, userInfo: [NSLocalizedDescriptionKey: "拼接失败"])
                completion(nil, nil, error)
            }
        }
    }
    
    // 寻找两张图片的重合点 (简单像素匹配)
    // 返回 bottomImage 相对于 topImage 顶部的 Y 偏移量
    private func findOverlap(topImage: UIImage, bottomImage: UIImage) -> CGFloat? {
        guard let topCG = topImage.cgImage, let bottomCG = bottomImage.cgImage else { return nil }
        
        // 为了性能，缩小图片进行匹配
        let scale: CGFloat = 0.1
        let topSmall = resizeCGImage(topCG, scale: scale)
        let bottomSmall = resizeCGImage(bottomCG, scale: scale)
        
        guard let topData = getPixelData(topSmall), let bottomData = getPixelData(bottomSmall) else { return nil }
        
        let topWidth = topSmall.width
        let topHeight = topSmall.height
        let bottomWidth = bottomSmall.width
        let bottomHeight = bottomSmall.height
        
        // 寻找重合区域
        // 我们假设 bottomImage 的顶部与 topImage 的底部有重叠
        // 搜索范围：topImage 的后 80% 区域与 bottomImage 的前 80% 区域
        let minOverlapHeight = Int(Double(min(topHeight, bottomHeight)) * 0.1)
        let maxSearchHeight = topHeight
        
        var bestY = -1
        var minDiff = Int.max
        var bestOverlapHeight = 0
        var bestRowStep = 1
        
        for yOffset in (topHeight - bottomHeight)...(topHeight - minOverlapHeight) {
            let currentY = max(0, yOffset)
            let overlapHeight = min(topHeight - currentY, bottomHeight)
            
            if overlapHeight < minOverlapHeight { continue }
            
            var diff = 0
            let sampleRows = 10 // 只采样部分行以提高性能
            let rowStep = max(1, overlapHeight / sampleRows)
            
            for row in stride(from: 0, to: overlapHeight, by: rowStep) {
                let topRow = currentY + row
                let bottomRow = row
                
                for col in stride(from: 0, to: min(topWidth, bottomWidth), by: 10) {
                    let topIdx = (topRow * topWidth + col) * 4
                    let bottomIdx = (bottomRow * bottomWidth + col) * 4
                    
                    if topIdx + 2 < topData.count && bottomIdx + 2 < bottomData.count {
                        diff += abs(Int(topData[topIdx]) - Int(bottomData[bottomIdx]))
                        diff += abs(Int(topData[topIdx+1]) - Int(bottomData[bottomIdx+1]))
                        diff += abs(Int(topData[topIdx+2]) - Int(bottomData[bottomIdx+2]))
                    }
                }
            }
            
            if diff < minDiff {
                minDiff = diff
                bestY = yOffset
                bestOverlapHeight = overlapHeight
                bestRowStep = rowStep
            }
        }
        
        // 阈值判断，如果差异太大则认为没找到
        if bestY != -1 {
            // 增加采样点数量以提高准确性
            let totalSamples = (bestOverlapHeight / bestRowStep) * (min(topWidth, bottomWidth) / 10)
            let averageDiff = Double(minDiff) / Double(totalSamples)
            
            // 如果平均每个采样像素的 RGB 差异小于 40，则认为匹配
            if averageDiff < 40.0 {
                return CGFloat(bestY) / scale
            }
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
