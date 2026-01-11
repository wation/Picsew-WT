import UIKit
import CoreImage

struct OverlapResult {
    let topY: CGFloat
    let bottomY: CGFloat
}

class StitchAlgorithm {
    
    // 寻找最佳的图片序列（自动排序）
    static func findBestSequence(_ images: [UIImage]) -> [UIImage] {
        let n = images.count
        if n <= 1 { return images }
        
        // 1. 构建邻接矩阵，存储每对图片之间的重合可能性
        // matrix[i][j] 表示图片 i 在图片 j 之上的匹配度（diff 越小越好）
        var matrix = [[Double?]](repeating: [Double?](repeating: nil, count: n), count: n)
        
        for i in 0..<n {
            for j in 0..<n {
                if i == j { continue }
                // 仅用于评估匹配度，不存储具体的裁切点
                matrix[i][j] = self.evaluateOverlap(topImage: images[i], bottomImage: images[j])
            }
        }
        
        // 寻找最长的匹配链
        var bestPath: [Int] = []
        var minTotalDiff: Double = Double.greatestFiniteMagnitude
        
        func findLongestPath(current: Int, visited: Set<Int>, currentDiff: Double) -> ([Int], Double) {
            var longest: [Int] = [current]
            var bestDiff = currentDiff
            
            for next in 0..<n {
                if !visited.contains(next), let diff = matrix[current][next] {
                    var newVisited = visited
                    newVisited.insert(next)
                    let (path, pathDiff) = findLongestPath(current: next, visited: newVisited, currentDiff: currentDiff + diff)
                    let fullPath = [current] + path
                    
                    if fullPath.count > longest.count || (fullPath.count == longest.count && pathDiff < bestDiff) {
                        longest = fullPath
                        bestDiff = pathDiff
                    }
                }
            }
            return (longest, bestDiff)
        }
        
        for start in 0..<n {
            let (path, pathDiff) = findLongestPath(current: start, visited: [start], currentDiff: 0)
            if path.count > bestPath.count || (path.count == bestPath.count && pathDiff < minTotalDiff) {
                bestPath = path
                minTotalDiff = pathDiff
            }
        }
        
        // 3. 如果找到了更长的匹配链（至少匹配了一对），则按此排序
        if bestPath.count >= 2 {
            var resultImages: [UIImage] = []
            var usedIndices = Set<Int>()
            
            for idx in bestPath {
                resultImages.append(images[idx])
                usedIndices.insert(idx)
            }
            
            // 将未匹配进去的图片按原顺序接在后面（虽然这种情况通常意味着拼接会失败）
            for i in 0..<n {
                if !usedIndices.contains(i) {
                    resultImages.append(images[i])
                }
            }
            
            print("AutoStitch: Reordered sequence: \(bestPath)")
            return resultImages
        }
        
        return images
    }
    
    // 仅用于评估重合度，返回差异值
    static func evaluateOverlap(topImage: UIImage, bottomImage: UIImage) -> Double? {
        guard let topCG = topImage.cgImage, let bottomCG = bottomImage.cgImage else { return nil }
        
        let scale: CGFloat = 0.1 // 评估时使用更小的缩放以提高性能
        let topSmall = resizeCGImage(topCG, scale: scale)
        let bottomSmall = resizeCGImage(bottomCG, scale: scale)
        
        guard let topData = getPixelData(topSmall), let bottomData = getPixelData(bottomSmall) else { return nil }
        
        let topWidth = topSmall.width
        let topHeight = topSmall.height
        let bottomWidth = bottomSmall.width
        
        let topIgnoreHeader = Int(Double(topHeight) * 0.15)
        let topIgnoreFooter = Int(Double(topHeight) * 0.05)
        let bottomIgnoreHeader = Int(Double(bottomSmall.height) * 0.15)
        
        let topContentStart = topIgnoreHeader
        let topContentEnd = topHeight - topIgnoreFooter
        let bottomContentStart = bottomIgnoreHeader
        
        let sampleHeight = 40
        let sampleStart = bottomContentStart
        
        var minDiff = Double.greatestFiniteMagnitude
        var found = false
        
        for yOffset in topContentStart...(topContentEnd - sampleHeight) {
            var totalDiff: Double = 0
            var pixelCount: Double = 0
            
            for row in 0..<sampleHeight {
                let topRow = yOffset + row
                let bottomRow = sampleStart + row
                
                for col in stride(from: 0, to: min(topWidth, bottomWidth), by: 8) {
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
                found = true
            }
        }
        
        return (found && minDiff < 35.0) ? minDiff : nil
    }
    
    // 寻找两张图片的重合点
    static func findOverlap(topImage: UIImage, bottomImage: UIImage) -> OverlapResult? {
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
    
    private static func resizeCGImage(_ image: CGImage, scale: CGFloat) -> CGImage {
        let width = Int(CGFloat(image.width) * scale)
        let height = Int(CGFloat(image.height) * scale)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.interpolationQuality = .high
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context?.makeImage() ?? image
    }
    
    private static func getPixelData(_ image: CGImage) -> [UInt8]? {
        let width = image.width
        let height = image.height
        var pixelData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: &pixelData, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return pixelData
    }
}
