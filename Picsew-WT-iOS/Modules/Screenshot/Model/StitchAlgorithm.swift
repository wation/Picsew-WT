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
        
        let scale: CGFloat = 0.2
        let topSmall = resizeCGImage(topCG, scale: scale)
        let bottomSmall = resizeCGImage(bottomCG, scale: scale)
        
        guard let topData = getPixelData(topSmall), let bottomData = getPixelData(bottomSmall) else { return nil }
        
        let topWidth = topSmall.width
        let topHeight = topSmall.height
        let bottomWidth = bottomSmall.width
        let bottomHeight = bottomSmall.height
        
        // 采用与视频抽帧识别一致的动态忽略比例
        let topIgnoreHeader = Int(Double(topHeight) * 0.12)
        let topIgnoreFooter = Int(Double(topHeight) * 0.10)
        let bottomIgnoreHeader = Int(Double(bottomSmall.height) * 0.12)
        
        let topContentStart = topIgnoreHeader
        let topContentEnd = topHeight - topIgnoreFooter
        let bottomContentStart = bottomIgnoreHeader
        
        let sampleHeight = min(60, bottomHeight - bottomContentStart - 10)
        // 扩大搜索范围
        let searchStart = topContentStart + Int(Double(topContentEnd - topContentStart) * 0.3)
        let rangeEnd = topContentEnd - sampleHeight
        
        let samplePositions = [
            bottomContentStart + Int(Double(bottomHeight - bottomContentStart) * 0.05),
            bottomContentStart + Int(Double(bottomHeight - bottomContentStart) * 0.15),
            bottomContentStart + Int(Double(bottomHeight - bottomContentStart) * 0.25),
            bottomContentStart + Int(Double(bottomHeight - bottomContentStart) * 0.35)
        ].filter { $0 + sampleHeight <= bottomHeight }
        
        var minDiff = Double.greatestFiniteMagnitude
        var found = false
        var bestTopY = -1
        var bestBottomY = -1
        
        if rangeEnd < searchStart || sampleHeight <= 0 || samplePositions.isEmpty {
            return nil
        }
        
        for sampleStart in samplePositions {
            for yOffset in stride(from: rangeEnd, through: searchStart, by: -1) {
                var totalDiff: Double = 0
                var pixelCount: Double = 0
                
                for row in 0..<sampleHeight {
                    let topRow = yOffset + row
                    let bottomRow = sampleStart + row
                    
                    // 增加水平采样密度，提高对细微文本（尤其是视频抽帧产生的模糊文本）的识别度
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
                if averageDiff < minDiff || (abs(averageDiff - minDiff) < 0.3 && yOffset > bestTopY) {
                    minDiff = averageDiff
                    found = true
                    bestTopY = yOffset
                    bestBottomY = sampleStart
                }
            }
        }
        
        // 放宽阈值到 65.0，兼容视频抽帧产生的压缩伪影
        if found && minDiff < 65.0 {
            // 计算重合比例：重合区域高度 / 待比较图高度
            let topShift = bestTopY - bestBottomY
            let overlapHeight = CGFloat(topHeight - topShift)
            
            // 保护一下，overlapHeight 不应超过 min(topHeight, bottomHeight)
            let safeOverlapHeight = min(overlapHeight, CGFloat(bottomHeight))
            
            let overlapInOriginal = safeOverlapHeight / scale
            let bottomHeightInOriginal = CGFloat(bottomCG.height)
            let accurateRatio = overlapInOriginal / bottomHeightInOriginal
            
            return (minDiff, Double(accurateRatio))
        }
        
        return nil
    }
    
    static func prepareTopOverlapData(_ topImage: UIImage) -> (cgImage: CGImage, data: [UInt8])? {
        guard let topCG = topImage.cgImage else { return nil }
        let topSmall = resizeCGImage(topCG, scale: 0.2)
        guard let topData = getPixelData(topSmall) else { return nil }
        return (topSmall, topData)
    }
    
    static func evaluateOverlapRatioPrecomputed(topSmall: CGImage, topData: [UInt8], bottomImage: UIImage) -> (diff: Double, ratio: Double)? {
        guard let bottomCG = bottomImage.cgImage else { return nil }
        let scale: CGFloat = 0.2
        let bottomSmall = resizeCGImage(bottomCG, scale: scale)
        guard let bottomData = getPixelData(bottomSmall) else { return nil }
        
        let topWidth = topSmall.width
        let topHeight = topSmall.height
        let bottomWidth = bottomSmall.width
        let bottomHeight = bottomSmall.height
        
        // 增加动态忽略比例：根据图片高度自动调整
        // 对于列表页，顶部通常有导航栏/标题，底部可能有底部栏
        let topIgnoreHeader = Int(Double(topHeight) * 0.12)
        let topIgnoreFooter = Int(Double(topHeight) * 0.10)
        let bottomIgnoreHeader = Int(Double(bottomSmall.height) * 0.12)
        
        let topContentStart = topIgnoreHeader
        let topContentEnd = topHeight - topIgnoreFooter
        let bottomContentStart = bottomIgnoreHeader
        
        let sampleHeight = min(60, bottomHeight - bottomContentStart - 10)
        // 扩大搜索范围：从底部向上搜索至 30% 处
        let searchStart = topContentStart + Int(Double(topContentEnd - topContentStart) * 0.3)
        let rangeEnd = topContentEnd - sampleHeight
        
        // 增加样本位置：覆盖底部图片的不同高度
        let samplePositions = [
            bottomContentStart + Int(Double(bottomHeight - bottomContentStart) * 0.05),
            bottomContentStart + Int(Double(bottomHeight - bottomContentStart) * 0.15),
            bottomContentStart + Int(Double(bottomHeight - bottomContentStart) * 0.25),
            bottomContentStart + Int(Double(bottomHeight - bottomContentStart) * 0.35)
        ].filter { $0 + sampleHeight <= bottomHeight }
        
        var minDiff = Double.greatestFiniteMagnitude
        var found = false
        var bestTopY = -1
        var bestBottomY = -1
        
        if rangeEnd < searchStart || sampleHeight <= 0 || samplePositions.isEmpty {
            return nil
        }
        
        for sampleStart in samplePositions {
            for yOffset in stride(from: rangeEnd, through: searchStart, by: -1) {
                var totalDiff: Double = 0
                var pixelCount: Double = 0
                
                for row in 0..<sampleHeight {
                    let topRow = yOffset + row
                    let bottomRow = sampleStart + row
                    
                    // 增加水平采样密度（从 8 改为 4），提高对细微文本的识别度
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
                // 降低阈值要求，并增加对 Y 偏移的权重
                if averageDiff < minDiff || (abs(averageDiff - minDiff) < 0.3 && yOffset > bestTopY) {
                    minDiff = averageDiff
                    found = true
                    bestTopY = yOffset
                    bestBottomY = sampleStart
                }
            }
        }
        
        // 放宽 diff 阈值到 65.0（原 50.0），以应对视频抽帧带来的压缩伪影
        if found && minDiff < 65.0 {
            let topShift = bestTopY - bestBottomY
            let overlapHeight = CGFloat(topHeight - topShift)
            let safeOverlapHeight = min(overlapHeight, CGFloat(bottomHeight))
            let overlapInOriginal = safeOverlapHeight / scale
            let bottomHeightInOriginal = CGFloat(bottomCG.height)
            let accurateRatio = overlapInOriginal / bottomHeightInOriginal
            return (minDiff, Double(accurateRatio))
        }
        
        return nil
    }
    
    // 静态图片重叠检测，适合文本内容的拼接
    static func findImageOverlap(topImage: UIImage, bottomImage: UIImage) -> OverlapResult? {
        // 方法开始日志
        print("AutoStitch: 开始静态图片重叠检测")
        
        guard let topCG = topImage.cgImage, let bottomCG = bottomImage.cgImage else {
            print("AutoStitch: 无法获取图片CGImage，返回nil")
            return nil 
        }
        
        // 输入图片信息
        print("AutoStitch: 输入图片信息 - 顶部图片尺寸: \(topCG.width)x\(topCG.height), 底部图片尺寸: \(bottomCG.width)x\(bottomCG.height)")
        
        let scale: CGFloat = 0.2
        let topSmall = resizeCGImage(topCG, scale: scale)
        let bottomSmall = resizeCGImage(bottomCG, scale: scale)
        
        // 缩放后尺寸日志
        print("AutoStitch: 缩放后尺寸 - 顶部图片: \(topSmall.width)x\(topSmall.height), 底部图片: \(bottomSmall.width)x\(bottomSmall.height)")
        
        guard let topData = getPixelData(topSmall), let bottomData = getPixelData(bottomSmall) else {
            print("AutoStitch: 无法获取像素数据，返回nil")
            return nil 
        }
        
        let topWidth = topSmall.width
        let topHeight = topSmall.height
        let bottomWidth = bottomSmall.width
        let bottomHeight = bottomSmall.height
        
        // 调整忽略区域参数，提高识别准确度
        let ignoreHeaderRatio = 0.10  // 减小顶部忽略比例（从15%到10%）
        let ignoreFooterRatio = 0.05
        
        let topIgnoreHeader = Int(Double(topHeight) * ignoreHeaderRatio)
        let topIgnoreFooter = Int(Double(topHeight) * ignoreFooterRatio)
        let bottomIgnoreHeader = Int(Double(bottomHeight) * ignoreHeaderRatio)
        let bottomIgnoreFooter = Int(Double(bottomHeight) * ignoreFooterRatio)
        
        // 忽略区域计算日志
        print("AutoStitch: 忽略区域计算 - 顶部头部忽略: \(topIgnoreHeader), 顶部底部忽略: \(topIgnoreFooter), 底部头部忽略: \(bottomIgnoreHeader), 底部底部忽略: \(bottomIgnoreFooter)")
        
        let topContentStart = topIgnoreHeader
        let topContentEnd = topHeight - topIgnoreFooter
        let bottomContentStart = bottomIgnoreHeader
        let bottomContentEnd = bottomHeight - bottomIgnoreFooter
        
        // 内容区域日志
        print("AutoStitch: 内容区域 - 顶部: [\(topContentStart), \(topContentEnd)], 底部: [\(bottomContentStart), \(bottomContentEnd)]")
        
        let searchHeight = 60 // 增加搜索高度
        let minOverlap = 20  // 降低最小重合要求
        
        // 搜索参数日志
        print("AutoStitch: 搜索参数 - 搜索高度: \(searchHeight), 最小重叠: \(minOverlap)")
        
        var bestTopY = -1
        var bestBottomY = -1
        var minDiff = Double.greatestFiniteMagnitude
        
        // 优化样本选择：使用多个样本位置，提高匹配成功率
        let samplePositions = [
            bottomContentStart + Int(Double(bottomContentEnd - bottomContentStart) * 0.10),
            bottomContentStart + Int(Double(bottomContentEnd - bottomContentStart) * 0.15),
            bottomContentStart + Int(Double(bottomContentEnd - bottomContentStart) * 0.20),
            bottomContentStart + Int(Double(bottomContentEnd - bottomContentStart) * 0.25)
        ]
        let sampleHeight = min(50, bottomContentEnd - bottomContentStart) // 增加样本高度到50
        
        // 样本参数日志
        print("AutoStitch: 样本参数 - 样本起始位置: \(samplePositions), 样本高度: \(sampleHeight)")
        
        if sampleHeight < minOverlap { 
            print("AutoStitch: 样本高度小于最小重叠要求，返回nil")
            return nil 
        }
        
        // 开始搜索日志
        print("AutoStitch: 开始搜索重叠区域...")
        
        // 修复搜索循环：使用多个样本位置进行搜索
        let rangeEnd = topContentEnd - sampleHeight
        let searchStart = topContentStart + Int(Double(topContentEnd - topContentStart) * 0.5)
        
        // 对每个样本位置进行搜索
        for sampleStart in samplePositions {
            print("AutoStitch: 使用样本起始位置: \(sampleStart)")
            
            if rangeEnd < searchStart { 
                continue 
            }
            
            for yOffset in stride(from: rangeEnd, through: searchStart, by: -1) {
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
                
                if averageDiff < minDiff 
                    || (abs(averageDiff - minDiff) < 0.5 && yOffset > bestTopY) {
                    minDiff = averageDiff
                    bestTopY = yOffset
                    bestBottomY = sampleStart
                }
            }
        }
        
        print("AutoStitch: 搜索完成 - 最佳匹配位置: yOffset=\(bestTopY), 最小差异: \(String(format: "%.1f", minDiff))")
        
        // 改进匹配阈值策略：提高匹配阈值，避免过于宽松的匹配
        if bestTopY != -1 && minDiff < 50.0 { 
            var refinedTopY = bestTopY
            var refinedBottomY = bestBottomY
            
            func avgDiff(topRow: Int, bottomRow: Int, rows: Int) -> Double {
                var total: Double = 0
                var count: Double = 0
                let cols = min(topWidth, bottomWidth)
                for r in 0..<rows {
                    let tr = topRow + r
                    let br = bottomRow + r
                    if tr < 0 || br < 0 || tr >= topHeight || br >= bottomHeight { break }
                    for c in stride(from: 0, to: cols, by: 4) {
                        let ti = (tr * topWidth + c) * 4
                        let bi = (br * bottomWidth + c) * 4
                        if ti + 2 < topData.count && bi + 2 < bottomData.count {
                            let dr = abs(Int(topData[ti]) - Int(bottomData[bi]))
                            let dg = abs(Int(topData[ti+1]) - Int(bottomData[bi+1]))
                            let db = abs(Int(topData[ti+2]) - Int(bottomData[bi+2]))
                            total += Double(dr + dg + db)
                            count += 1
                        }
                    }
                }
                if count == 0 { return Double.greatestFiniteMagnitude }
                return total / (count * 3.0)
            }
            
            let maxUp = min(80, min(refinedTopY - topContentStart, refinedBottomY - bottomContentStart))
            var steps = 0
            while steps < maxUp {
                let d = avgDiff(topRow: refinedTopY - 8, bottomRow: refinedBottomY - 8, rows: 8)
                if d < 40.0 {
                    refinedTopY -= 1
                    refinedBottomY -= 1
                    steps += 1
                } else {
                    break
                }
            }
            
            let topYInOriginal = CGFloat(refinedTopY) / scale
            let bottomYInOriginal = CGFloat(refinedBottomY) / scale
            
            // 原始坐标日志
            print("AutoStitch: 重叠区域计算 - 原始坐标: 顶部Y=\(String(format: "%.0f", topYInOriginal)), 底部Y=\(String(format: "%.0f", bottomYInOriginal))")
            
            // 计算重合区域的总高度
            // 重合区域是从 topYInOriginal (第一张图) 和 bottomYInOriginal (第二张图) 开始的
            let remainingTopHeight = CGFloat(topCG.height) - topYInOriginal
            let remainingBottomHeight = CGFloat(bottomCG.height) - bottomYInOriginal
            var totalOverlapHeight = min(remainingTopHeight, remainingBottomHeight)
            
            // 增加顺序验证逻辑：检查重叠区域位置是否合理
            let topImageMidpoint = CGFloat(topCG.height) / 2.0
            if topYInOriginal < topImageMidpoint {
                print("AutoStitch: 顺序验证 - 重叠区域位于顶部图片的前半部分，可能是图片顺序错误")
                // 尝试反向匹配：交换样本起始位置和搜索位置
                print("AutoStitch: 尝试反向匹配")
                
                // 重置最佳匹配
                var bestReverseTopY = -1
                var bestReverseBottomY = -1
                var minReverseDiff = Double.greatestFiniteMagnitude
                
                // 使用底部图片的后半部分作为样本
                let reverseSampleStart = bottomContentStart + Int(Double(bottomContentEnd - bottomContentStart) * 0.7) // 从内容区域70%的位置开始
                let reverseSampleHeight = min(40, bottomContentEnd - reverseSampleStart)
                
                if reverseSampleHeight >= minOverlap {
                    for yOffset in topContentStart...rangeEnd {
                        var totalDiff: Double = 0
                        var pixelCount: Double = 0
                        
                        for row in 0..<reverseSampleHeight {
                            let topRow = yOffset + row
                            let bottomRow = reverseSampleStart + row
                            
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
                        
                        if averageDiff < minReverseDiff {
                            minReverseDiff = averageDiff
                            bestReverseTopY = yOffset
                            bestReverseBottomY = reverseSampleStart
                        }
                    }
                    
                    print("AutoStitch: 反向匹配结果 - 最佳差异: \(String(format: "%.1f", minReverseDiff))")
                    
                    // 如果反向匹配更好，使用反向匹配结果
                    if minReverseDiff < minDiff && minReverseDiff < 50.0 {
                        print("AutoStitch: 使用反向匹配结果")
                        bestTopY = bestReverseTopY
                        bestBottomY = bestReverseBottomY
                        minDiff = minReverseDiff
                    }
                }
            }
            
            // 增加重叠区域合理性检查：限制最大重叠比例为50%
            let maxAllowedOverlap = CGFloat(topCG.height) * 0.5 // 最大允许50%重叠
            if totalOverlapHeight > maxAllowedOverlap {
                print("AutoStitch: 重叠区域合理性检查 - 原始重叠: \(totalOverlapHeight), 调整为最大允许值: \(maxAllowedOverlap)")
                totalOverlapHeight = maxAllowedOverlap
            }
            
            // 重叠高度日志
            print("AutoStitch: 重叠区域高度计算 - 顶部剩余: \(String(format: "%.0f", remainingTopHeight)), 底部剩余: \(String(format: "%.0f", remainingBottomHeight)), 总重叠: \(String(format: "%.0f", totalOverlapHeight))")
            
            // 用户反馈：把裁剪位置定义为重叠区域的一半
            let midOverlapHeight = totalOverlapHeight / 2.0
            
            // 中点日志
            print("AutoStitch: 拼接线计算 - 中点位置: \(String(format: "%.0f", midOverlapHeight))")
            
            let finalTopY = topYInOriginal + midOverlapHeight
            let finalBottomY = bottomYInOriginal + midOverlapHeight
            
            // 最终坐标日志
            print("AutoStitch: 最终坐标计算 - 顶部裁剪Y: \(String(format: "%.0f", finalTopY)), 底部开始Y: \(String(format: "%.0f", finalBottomY))")
            
            // 确保不会超出图片边界
            let safeTopY = max(0, min(CGFloat(topCG.height), finalTopY))
            let safeBottomY = max(0, min(CGFloat(bottomCG.height), finalBottomY))
            
            // 安全检查日志
            print("AutoStitch: 安全检查 - 顶部安全Y: \(String(format: "%.0f", safeTopY)), 底部安全Y: \(String(format: "%.0f", safeBottomY))")
            
            // 最终结果日志
            print("AutoStitch: Midpoint overlap cut. TotalOverlap: \(totalOverlapHeight), TopCut: \(safeTopY), BottomStart: \(safeBottomY)")
            print("AutoStitch: 静态图片重叠检测完成，返回结果")
            
            return OverlapResult(
                topY: safeTopY,
                bottomY: safeBottomY
            )
        } else { 
            print("AutoStitch: 未找到匹配的重叠区域，返回nil - 最佳差异: \(String(format: "%.1f", minDiff))")
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
