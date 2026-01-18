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
    
    // 仅用于评估重合度，返回差异值和重合度比例
    // ratio = 重合区域高度 / 待比较图(bottomImage)的高度
    static func evaluateOverlapRatio(topImage: UIImage, bottomImage: UIImage) -> (diff: Double, ratio: Double)? {
        guard let topCG = topImage.cgImage, let bottomCG = bottomImage.cgImage else { return nil }
        
        let scale: CGFloat = 0.1 // 评估时使用更小的缩放以提高性能
        let topSmall = resizeCGImage(topCG, scale: scale)
        let bottomSmall = resizeCGImage(bottomCG, scale: scale)
        
        guard let topData = getPixelData(topSmall), let bottomData = getPixelData(bottomSmall) else { return nil }
        
        let topWidth = topSmall.width
        let topHeight = topSmall.height
        let bottomWidth = bottomSmall.width
        let bottomHeight = bottomSmall.height
        
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
        var bestTopY = -1
        
        // 添加边界检查，避免Range错误
        let rangeEnd = topContentEnd - sampleHeight
        if rangeEnd < topContentStart {
            return nil
        }
        
        for yOffset in topContentStart...rangeEnd {
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
                bestTopY = yOffset
            }
        }
        
        if found && minDiff < 35.0 {
            // 计算重合比例：重合区域高度 / 待比较图高度
            // 修正计算逻辑：
            // bestTopY 是 topImage 中匹配点的 Y 坐标
            // sampleStart 是 bottomImage 中采样点的起始 Y 坐标
            // 它们代表同一个视觉位置，即 topImage 的第 bestTopY 行 == bottomImage 的第 sampleStart 行
            //
            // 所以，topImage 相对于 bottomImage 的垂直偏移量 shift = bestTopY - sampleStart
            // 如果 shift > 0，说明 topImage 偏下（bottomImage 需往下接）
            //
            // 重合区域高度 overlapHeight = topHeight - (bestTopY - sampleStart)
            // 推导：bottomImage 的第 0 行对应 topImage 的 (bestTopY - sampleStart) 行
            // 所以 topImage 从 (bestTopY - sampleStart) 开始到 topHeight 都是重合的
            
            // 注意：这里使用的是缩略图坐标，需要先算好，最后再转回原图比例？
            // 不，evaluateOverlapRatio 的返回值 ratio 是比例，与 scale 无关。
            // 只要分子分母都是缩略图尺寸即可。
            
            let topShift = bestTopY - sampleStart
            let overlapHeight = CGFloat(topHeight - topShift)
            
            // 保护一下，overlapHeight 不应超过 min(topHeight, bottomHeight)
            let safeOverlapHeight = min(overlapHeight, CGFloat(bottomHeight))
            
            let ratio = safeOverlapHeight / CGFloat(bottomHeight)
            
            // 打印调试信息，验证计算是否合理
            // print("Overlap Calc: bestTopY=\(bestTopY), sampleStart=\(sampleStart), topH=\(topHeight), bottomH=\(bottomHeight), overlap=\(safeOverlapHeight), ratio=\(ratio)")
            
            // 修正比例计算：基于原图尺寸重新计算
            // 缩略图计算可能有精度损失，虽然 ratio 应该一致，但为了保险，我们使用 safeOverlapHeight 在原图上的投影
            // safeOverlapHeight 是缩略图尺寸
            let overlapInOriginal = safeOverlapHeight / scale
            let bottomHeightInOriginal = CGFloat(bottomCG.height)
            let accurateRatio = overlapInOriginal / bottomHeightInOriginal
            
            return (minDiff, Double(accurateRatio))
        }
        
        return nil
    }
    
    // 快速拼接两张图片，仅保留拼接后的结果（用于生成新的参考图）
    // 采用中间切割策略：在重叠区域的中间进行切割，上半部分用 TopImage，下半部分用 BottomImage
    // 这样可以有效消除 TopImage 的 Footer 和 BottomImage 的 Header
    static func mergeImages(topImage: UIImage, bottomImage: UIImage, overlapRatio: Double) -> UIImage? {
        guard let topCG = topImage.cgImage, let bottomCG = bottomImage.cgImage else { return nil }
        
        let overlapHeight = CGFloat(bottomImage.size.height) * CGFloat(overlapRatio)
        let newHeight = topImage.size.height + bottomImage.size.height - overlapHeight
        let width = topImage.size.width
        
        // 限制最大高度，避免内存溢出
        // 如果拼接后高度超过阈值（如 3000），则只取底部 3000
        let maxHeight: CGFloat = 3000
        let finalHeight = min(newHeight, maxHeight)
        let drawOffsetY = finalHeight - newHeight // 如果被裁剪，这是负值，用于调整绘制坐标
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: finalHeight), false, topImage.scale)
        defer { UIGraphicsEndImageContext() }
        
        // 1. 绘制 TopImage
        // TopImage 负责提供切割线以上的内容
        topImage.draw(in: CGRect(x: 0, y: drawOffsetY, width: width, height: topImage.size.height))
        
        // 2. 绘制 BottomImage，但在中间切割
        // 计算切割位置：重叠区域的中点
        // TopImage 坐标系下的切割线：topHeight - overlapHeight/2
        let midOverlap = overlapHeight / 2.0
        // 在当前画布（考虑了 drawOffsetY）上的切割线 Y 坐标
        let cutY = drawOffsetY + topImage.size.height - midOverlap
        
        // 设置裁剪区域：只允许绘制 cutY 以下的部分
        // 这样 BottomImage 绘制时，cutY 以上的部分（即 Header）会被裁剪掉，显示出 TopImage 的内容
        // 而 cutY 以下的部分，BottomImage 会覆盖掉 TopImage（即 Footer）
        let clipRect = CGRect(x: 0, y: cutY, width: width, height: finalHeight - cutY)
        UIRectClip(clipRect)
        
        // 绘制 BottomImage
        // 计算 BottomImage 的绘制位置：
        // 它的 midOverlap 行应该对齐到 cutY
        // 所以 bottomImage 的 originY 应该是 cutY - midOverlap
        // = (drawOffsetY + topHeight - midOverlap) - midOverlap
        // = drawOffsetY + topHeight - overlapHeight
        // 这与标准叠加位置一致
        let bottomY = topImage.size.height - overlapHeight + drawOffsetY
        bottomImage.draw(in: CGRect(x: 0, y: bottomY, width: width, height: bottomImage.size.height))
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    // 仅用于评估重合度，返回差异值
    static func evaluateOverlap(topImage: UIImage, bottomImage: UIImage) -> Double? {
        return evaluateOverlapRatio(topImage: topImage, bottomImage: bottomImage)?.diff
    }
    
    static func findVideoOverlapDetailed(topImage: UIImage, bottomImage: UIImage) -> (result: OverlapResult, diff: Double)? {
        guard let topCG = topImage.cgImage, let bottomCG = bottomImage.cgImage else { return nil }
        
        let scale: CGFloat = 0.2
        let topSmall = resizeCGImage(topCG, scale: scale)
        let bottomSmall = resizeCGImage(bottomCG, scale: scale)
        
        guard let topData = getPixelData(topSmall), let bottomData = getPixelData(bottomSmall) else { return nil }
        
        let topWidth = topSmall.width
        let topHeight = topSmall.height
        let bottomWidth = bottomSmall.width
        let bottomHeight = bottomSmall.height
        
        // 视频帧通常不会有 header/footer 干扰，但仍保留小比例忽略
        let ignoreHeaderRatio = 0.1
        let ignoreFooterRatio = 0.05
        
        let topIgnoreHeader = Int(Double(topHeight) * ignoreHeaderRatio)
        let topIgnoreFooter = Int(Double(topHeight) * ignoreFooterRatio)
        let bottomIgnoreHeader = Int(Double(bottomHeight) * ignoreHeaderRatio)
        
        let topContentStart = topIgnoreHeader
        let topContentEnd = topHeight - topIgnoreFooter
        let bottomContentStart = bottomIgnoreHeader
        let bottomContentEnd = bottomHeight - Int(Double(bottomHeight) * ignoreFooterRatio)
        
        // 显著增加搜索高度，以包含更多特征
        let searchHeight = 150 // 原图约 750px
        let minOverlap = 30
        
        var bestTopY = -1
        var bestBottomY = -1
        var minDiff = Double.greatestFiniteMagnitude
        
        // 取 bottomImage 的头部作为样本，去 topImage 寻找匹配
        let sampleStart = bottomContentStart
        let sampleHeight = min(searchHeight, bottomContentEnd - sampleStart)
        
        if sampleHeight < minOverlap { return nil }
        
        // 视频帧通常是向下滚动的，所以 bottomImage 的头部应该匹配 topImage 的下半部分
        // 限制搜索范围在 topImage 的下半部分，提高效率并减少误判
        let searchStart = topContentStart + (topContentEnd - topContentStart) / 2
        
        // 添加边界检查，避免Range错误
        let rangeEnd = topContentEnd - sampleHeight
        if rangeEnd < searchStart {
            return nil
        }
        
        for yOffset in searchStart...rangeEnd {
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
        
        // 视频压缩可能带来噪声，放宽 diff 阈值
        if bestTopY != -1 && minDiff < 50.0 {
            let topYInOriginal = CGFloat(bestTopY) / scale
            let bottomYInOriginal = CGFloat(bestBottomY) / scale
            
            // 计算重合区域的总高度
            let remainingTopHeight = CGFloat(topCG.height) - topYInOriginal
            let remainingBottomHeight = CGFloat(bottomCG.height) - bottomYInOriginal
            let totalOverlapHeight = min(remainingTopHeight, remainingBottomHeight)
            
            // 取中点作为拼接线
            let midOverlapHeight = totalOverlapHeight / 2.0
            
            let finalTopY = topYInOriginal + midOverlapHeight
            let finalBottomY = bottomYInOriginal + midOverlapHeight
            
            let safeTopY = max(0, min(CGFloat(topCG.height), finalTopY))
            let safeBottomY = max(0, min(CGFloat(bottomCG.height), finalBottomY))
                        
            return (OverlapResult(topY: safeTopY, bottomY: safeBottomY), minDiff)
        }
        
        return nil
    }

    // 寻找两张图片的重合点（针对视频帧优化）
    static func findVideoOverlap(topImage: UIImage, bottomImage: UIImage) -> OverlapResult? {
        return findVideoOverlapDetailed(topImage: topImage, bottomImage: bottomImage)?.result
    }
    
    // 寻找两张图片的重合点（通用版，供截图拼接使用）
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
        let ignoreFooterRatio = 0.05
        
        let topIgnoreHeader = Int(Double(topHeight) * ignoreHeaderRatio)
        let topIgnoreFooter = Int(Double(topHeight) * ignoreFooterRatio)
        let bottomIgnoreHeader = Int(Double(bottomHeight) * ignoreHeaderRatio)
        let bottomIgnoreFooter = Int(Double(bottomHeight) * ignoreFooterRatio)
        
        let topContentStart = topIgnoreHeader
        let topContentEnd = topHeight - topIgnoreFooter
        let bottomContentStart = bottomIgnoreHeader
        let bottomContentEnd = bottomHeight - bottomIgnoreFooter
        
        let searchHeight = 60
        let minOverlap = 20
        
        var bestTopY = -1
        var bestBottomY = -1
        var minDiff = Double.greatestFiniteMagnitude
        
        // 策略：在 bottomImage 的内容区域取一段，在 topImage 的内容区域寻找匹配
        let sampleStart = bottomContentStart
        let sampleHeight = min(searchHeight, bottomContentEnd - sampleStart)
        
        if sampleHeight < minOverlap { return nil }
        
        // 添加边界检查，避免Range错误
        let rangeEnd = topContentEnd - sampleHeight
        if rangeEnd < topContentStart {
            return nil
        }
        
        for yOffset in topContentStart...rangeEnd {
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
            let remainingTopHeight = CGFloat(topCG.height) - topYInOriginal
            let remainingBottomHeight = CGFloat(bottomCG.height) - bottomYInOriginal
            let totalOverlapHeight = min(remainingTopHeight, remainingBottomHeight)
            
            // 把裁剪位置定义为重叠区域的一半
            let midOverlapHeight = totalOverlapHeight / 2.0
            
            let finalTopY = topYInOriginal + midOverlapHeight
            let finalBottomY = bottomYInOriginal + midOverlapHeight
            
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
