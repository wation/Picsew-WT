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
    
    func autoStitch(_ images: [UIImage], forceManual: Bool = false, keepOrder: Bool = false, isFromVideo: Bool = false, customOverlap: (topY: CGFloat, bottomY: CGFloat, height: CGFloat)? = nil, completion: @escaping (UIImage?, [CGFloat]?, [CGFloat]?, [Int]?, [UIImage]?, Error?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard images.count >= 2 else {
                let error = NSError(domain: "StitchError", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("stitch_need_2_images", comment: "")])
                completion(nil, nil, nil, nil, nil, error)
                return
            }
            
            let workingImages: [UIImage]
            if keepOrder {
                workingImages = images
            } else {
                let reorderedImages = forceManual ? images : StitchAlgorithm.findBestSequence(images)
                workingImages = reorderedImages
            }

            var offsets: [CGFloat]
            var bottomStartOffsets: [CGFloat]
            var matchedIndices: [Int] = []
            var matchedPairCount = 0
            var totalHeight: CGFloat = 0

            // 如果提供了自定义重叠参数，直接使用
            if let custom = customOverlap {
                // 使用用户提供的实际重叠数据
                // 3.png 重叠起始: custom.topY (1200)
                // 4.png 重叠起始: custom.bottomY (300)
                // 重叠高度: custom.height (900)
                
                // 计算拼接线位置（中点切割策略）
                let midOverlap = custom.height / 2.0  // 900 / 2 = 450
                
                let topCut = custom.topY + midOverlap  // 1200 + 450 = 1650
                let bottomStart = custom.bottomY + midOverlap  // 300 + 450 = 750
                
                // 计算显示高度
                let firstImageHeight = topCut  // 1650
                let secondImageHeight = CGFloat(workingImages[1].size.height) - bottomStart  // 2688 - 750 = 1938
                
                offsets = [0, firstImageHeight]  // [0, 1650]
                bottomStartOffsets = [0, bottomStart]  // [0, 750]
                totalHeight = firstImageHeight + secondImageHeight  // 1650 + 1938 = 3588
                matchedPairCount = 1
                matchedIndices = [1]
                
                // 直接生成拼接图片
                let maxWidth = workingImages.map { $0.size.width }.max() ?? 0
                
                UIGraphicsBeginImageContextWithOptions(CGSize(width: maxWidth, height: totalHeight), false, 1.0)
                
                // 绘制第一张图片
                let image0 = workingImages[0]
                let cropHeight0 = firstImageHeight + 1
                let destRect0 = CGRect(x: 0, y: 0, width: image0.size.width, height: cropHeight0)
                UIGraphicsGetCurrentContext()?.saveGState()
                UIGraphicsGetCurrentContext()?.clip(to: destRect0)
                image0.draw(at: CGPoint(x: 0, y: 0))
                UIGraphicsGetCurrentContext()?.restoreGState()
                
                // 绘制第二张图片
                let image1 = workingImages[1]
                let cropHeight1 = secondImageHeight
                let destRect1 = CGRect(x: 0, y: firstImageHeight, width: image1.size.width, height: cropHeight1)
                UIGraphicsGetCurrentContext()?.saveGState()
                UIGraphicsGetCurrentContext()?.clip(to: destRect1)
                image1.draw(at: CGPoint(x: 0, y: firstImageHeight - bottomStart))
                UIGraphicsGetCurrentContext()?.restoreGState()
                
                let finalImage = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                if let finalImage = finalImage {
                    completion(finalImage, offsets, bottomStartOffsets, matchedIndices, workingImages, nil)
                } else {
                    let error = NSError(domain: "StitchError", code: 1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("stitch_failed", comment: "")])
                    completion(nil, nil, nil, nil, nil, error)
                }
                return
            }

            if keepOrder {
                // 保持顺序的处理逻辑（视频截图或静态图片）
                let count = workingImages.count
                // 默认重叠比例（兜底用）
                let defaultOverlapRatio: CGFloat = 0.1 // 减小默认重叠比例，避免内容丢失
                // 移动平均步长，初始化为默认步长（假设每帧移动 90% 高度）
                var runningAverageStep: CGFloat = 0
                if count > 0 {
                    runningAverageStep = workingImages[0].size.height * (1 - defaultOverlapRatio)
                }
                
                var overlaps: [OverlapResult?] = Array(repeating: nil, count: max(count - 1, 0))
                var isPairMatched = [Bool](repeating: false, count: max(count - 1, 0))

                if !forceManual && count >= 2 {
                    for i in 0..<(count - 1) {
                        // 对于静态图片，使用findImageOverlap方法
                        // 对于视频截图，使用findVideoOverlapDetailed方法
                        let topImage = workingImages[i]
                        let bottomImage = workingImages[i+1]
                        
                        // 使用传入的isFromVideo参数来区分视频截图和静态图片
                        if isFromVideo {
                            // 视频截图使用视频重叠检测
                            if let detailed = StitchAlgorithm.findVideoOverlapDetailed(topImage: topImage, bottomImage: bottomImage) {
                                let height = topImage.size.height
                                let minCut = height * 0.1
                                let maxCut = height * 0.9
                                if detailed.diff < 45.0, detailed.result.topY >= minCut, detailed.result.topY <= maxCut {
                                    overlaps[i] = detailed.result
                                    isPairMatched[i] = true
                                    let currentStep = detailed.result.topY
                                    runningAverageStep = runningAverageStep * 0.7 + currentStep * 0.3
                                }
                            }
                        } else {
                            // 静态图片使用静态重叠检测
                            if let result = StitchAlgorithm.findImageOverlap(topImage: topImage, bottomImage: bottomImage) {
                                overlaps[i] = result
                                isPairMatched[i] = true
                            }
                        }
                    }
                }

                var startYs = [CGFloat](repeating: 0, count: count)
                var endYs = [CGFloat](repeating: 0, count: count)
                var segmentHeights = [CGFloat](repeating: 0, count: count)

                // 第 0 帧处理
                if count > 0 {
                    let height = workingImages[0].size.height
                    let minVisible = max(1, height * 0.12)
                    var end: CGFloat
                    
                    if let firstOverlap = (overlaps.first ?? nil) {
                        end = firstOverlap.topY
                    } else {
                        // 兜底：使用平均步长
                        end = min(height, runningAverageStep)
                    }
                    
                    startYs[0] = 0
                    endYs[0] = max(minVisible, min(height, end))
                    segmentHeights[0] = endYs[0] - startYs[0]
                }

                // 中间帧处理
                if count >= 3 {
                    for i in 1..<(count - 1) {
                        let height = workingImages[i].size.height
                        let prevOverlap = overlaps[i-1]
                        let nextOverlap = overlaps[i]
                        
                        let minVisible = max(1, height * 0.12)

                        // 计算 startY (上边缘)
                        var start: CGFloat = 0
                        if let prev = prevOverlap {
                            // 如果和上一帧有重合，从重合点开始
                            start = prev.bottomY
                        } else {
                            // 如果没重合，推断 startY
                            // 逻辑：上一帧如果用了兜底步长，那么这一帧应该接着上一帧的“虚拟”结束点
                            // 但这里我们用一种简化的方式：
                            // 假设当前帧的高度里，头部有一部分是和上一帧重复的
                            // 重复的高度 = height - runningAverageStep
                            let overlapHeight = max(0, height - runningAverageStep)
                            start = overlapHeight
                        }
                        
                        // 计算 endY (下边缘)
                        var end: CGFloat
                        if let next = nextOverlap {
                            end = next.topY
                        } else {
                            // 兜底：保留平均步长的高度
                            // end - start = runningAverageStep
                            end = min(height, start + runningAverageStep)
                        }
                        
                        start = max(0, min(height, start))
                        end = max(0, min(height, end))

                        if end - start < minVisible {
                            end = min(height, start + max(minVisible, runningAverageStep))
                            if end - start < minVisible {
                                start = max(0, end - minVisible)
                            }
                        }

                        startYs[i] = start
                        endYs[i] = end
                        segmentHeights[i] = end - start
                    }
                }

                // 最后一帧处理
                if count >= 2 {
                    let lastIndex = count - 1
                    let height = workingImages[lastIndex].size.height
                    let minVisible = max(1, height * 0.12)
                    var start: CGFloat = 0
                    
                    if let lastOverlap = overlaps[lastIndex - 1] {
                        start = lastOverlap.bottomY
                    } else {
                        let overlapHeight = max(0, height - runningAverageStep)
                        start = overlapHeight
                    }
                    
                    start = max(0, min(height, start))
                    var end = height
                    if end - start < minVisible {
                        start = max(0, end - minVisible)
                    }

                    startYs[lastIndex] = start
                    endYs[lastIndex] = end
                    segmentHeights[lastIndex] = end - start
                }

                offsets = [CGFloat](repeating: 0, count: workingImages.count)
                bottomStartOffsets = startYs
                for i in 1..<workingImages.count {
                    // 下一张图的 offset = 上一张图的 offset + 上一张图的实际显示高度
                    let prevDisplayHeight = max(1, segmentHeights[i-1])
                    offsets[i] = offsets[i-1] + prevDisplayHeight
                }

                matchedPairCount = isPairMatched.filter { $0 }.count
                for i in 0..<isPairMatched.count where isPairMatched[i] {
                    matchedIndices.append(i + 1)
                }
                totalHeight = segmentHeights.reduce(0, +)
            } else {
                // 静态图片处理逻辑（不保持顺序，自动排序）
                offsets = [0]
                bottomStartOffsets = [0]

                for i in 0..<(workingImages.count - 1) {
                    let topImage = workingImages[i]
                    let bottomImage = workingImages[i+1]

                    if !forceManual, let result = StitchAlgorithm.findImageOverlap(topImage: topImage, bottomImage: bottomImage) {
                        let topImageCutY = result.topY
                        let bottomImageStartY = result.bottomY

                        let nextImageCanvasY = offsets[i] + topImageCutY
                        offsets.append(nextImageCanvasY)
                        bottomStartOffsets.append(bottomImageStartY)
                        matchedIndices.append(i + 1)
                        matchedPairCount += 1
                    } else {
                        // 静态图片兜底逻辑：不裁剪，直接拼接
                        let nextImageCanvasY = offsets[i] + topImage.size.height
                        offsets.append(nextImageCanvasY)
                        bottomStartOffsets.append(0)
                    }
                }

                if let lastOffset = offsets.last, let lastImage = workingImages.last {
                    totalHeight = lastOffset + (lastImage.size.height - bottomStartOffsets.last!)
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
                
                var cropHeight = (i < workingImages.count - 1) ? displayHeight + 1 : displayHeight
                let maxCropHeight = max(0, image.size.height - startY)
                cropHeight = max(0, min(cropHeight, maxCropHeight))
                if cropHeight <= 0 { continue }

                let x = (maxWidth - image.size.width) / 2
                let destRect = CGRect(x: x, y: canvasY, width: image.size.width, height: cropHeight)
                UIGraphicsGetCurrentContext()?.saveGState()
                UIGraphicsGetCurrentContext()?.clip(to: destRect)
                image.draw(at: CGPoint(x: x, y: canvasY - startY))
                UIGraphicsGetCurrentContext()?.restoreGState()
            }
            
            let finalImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            if let finalImage = finalImage {
                let hasOverlapWarning = matchedPairCount < workingImages.count - 1
                let warning = hasOverlapWarning ? NSError(domain: "StitchWarning", code: 2, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("stitch_warning_auto_to_manual", comment: "")]) : nil
                completion(finalImage, offsets, bottomStartOffsets, matchedIndices, workingImages, warning)
            } else {
                let error = NSError(domain: "StitchError", code: 1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("stitch_failed", comment: "")])
                completion(nil, nil, nil, nil, nil, error)
            }
        }
    }
}
