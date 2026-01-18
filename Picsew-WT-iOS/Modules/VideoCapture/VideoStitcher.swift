import UIKit
import AVFoundation
import Photos

class VideoStitcher {
    static let shared = VideoStitcher()
    
    /// 视频处理回调
    /// - images: 提取出的关键帧图片
    /// - error: 错误信息
    typealias VideoProcessCompletion = ([UIImage]?, Error?) -> Void
    
    private init() {}
    
    /// 从视频中自动识别并提取用于拼接的关键帧
    func processVideo(asset: PHAsset, completion: @escaping ([UIImage]?, Error?) -> Void) {
        let options = PHVideoRequestOptions()
        options.version = .original
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
            guard let urlAsset = avAsset as? AVURLAsset else {
                completion(nil, NSError(domain: "VideoStitcher", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("failed_to_get_video_resource", comment: "Failed to get video resource")]))
                return
            }
            
            self?.extractKeyFrames(from: urlAsset.url, completion: completion)
        }
    }
    
    /// 从本地视频 URL 处理视频，提取关键帧
    func processVideo(url: URL, completion: @escaping VideoProcessCompletion) {
        extractKeyFrames(from: url, completion: completion)
    }
    
    /// 从本地视频 URL 提取关键帧
    func extractKeyFrames(from url: URL, completion: @escaping VideoProcessCompletion) {
        print("[VideoStitcher] Start processing video at URL: \(url.path)")
        
        let asset = AVAsset(url: url)
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
            print("[VideoStitcher] Created AVAssetReader successfully")
        } catch {
            print("[VideoStitcher] Failed to create AVAssetReader: \(error.localizedDescription)")
            completion(nil, error)
            return
        }
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            print("[VideoStitcher] No video track found in asset")
            completion(nil, NSError(domain: "VideoStitcher", code: -2, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("no_video_track_found", comment: "No video track found")]))
            return
        }
        
        print("[VideoStitcher] Found video track: \(videoTrack.nominalFrameRate) FPS, duration: \(asset.duration.seconds) seconds")
        
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        reader.add(readerOutput)
        
        if reader.startReading() {
            print("[VideoStitcher] Started reading video frames")
        } else {
            print("[VideoStitcher] Failed to start reading video frames")
            completion(nil, NSError(domain: "VideoStitcher", code: -4, userInfo: [NSLocalizedDescriptionKey: "Failed to start reading video frames"]))
            return
        }
        
        var segments: [[UIImage]] = []
        var currentSegment: [UIImage] = []
        var lastImage: UIImage?
        var lastSampleBuffer: CMSampleBuffer?

        let fps = videoTrack.nominalFrameRate
        // 缓存2秒的帧数据用于快速搜索
        let bufferSize = Int(fps * 2) 
        var frameBuffer: [UIImage] = []
        print("[VideoStitcher] Video FPS: \(fps), buffer size: \(bufferSize)")
        
        var frameCount = 0
        var extractedFrameCount = 0
        var addedFrameCount = 0
        
        // 快速搜索参数
        let minOverlapRatio: Double = 0.25
        let maxOverlapRatio: Double = 0.75
        
        // --- 核心流式处理逻辑 ---
        
        // 1. 读取第1帧，加入currentSegment
        if let sampleBuffer = readerOutput.copyNextSampleBuffer(),
           let firstImage = imageFromSampleBuffer(sampleBuffer) {
            
            frameCount += 1
            extractedFrameCount += 1
            
            currentSegment.append(firstImage)
            lastImage = firstImage
            print("[VideoStitcher-Algo] Added first video frame as reference.")
        } else {
            // 空视频处理
            print("[VideoStitcher] Video is empty or failed to read first frame")
            completion(nil, NSError(domain: "VideoStitcher", code: -5, userInfo: [NSLocalizedDescriptionKey: "Failed to read first frame"]))
            return
        }
        
        // 2. 循环读取 bufferSize 大小的帧
        while true {
            // 填充 buffer
            var hasMoreFrames = true
            while frameBuffer.count < bufferSize {
                if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                    frameCount += 1
                    if let image = imageFromSampleBuffer(sampleBuffer) {
                        frameBuffer.append(image)
                    }
                } else {
                    hasMoreFrames = false
                    break
                }
            }
            
            if frameBuffer.isEmpty {
                break
            }
            
            print("[VideoStitcher-Algo] Processing buffer window. Size: \(frameBuffer.count), Reference Frame Set: \(lastImage != nil)")
            
            // 3. 在 buffer 中寻找匹配帧（二分查找）
            if let refImage = lastImage {
                if let matchIndex = findBestMatch(referenceImage: refImage, buffer: frameBuffer, start: 0, end: frameBuffer.count - 1, minOverlap: minOverlapRatio, maxOverlap: maxOverlapRatio) {
                    // 找到了匹配帧
                    let matchedImage = frameBuffer[matchIndex]
                    currentSegment.append(matchedImage)
                    addedFrameCount += 1
                    
                    print("[VideoStitcher-Algo] Match found at index \(matchIndex). Moving window.")
                    
                    // 动态更新参考帧：将原参考帧与新匹配帧拼接
                    // 为了获取 overlapRatio，需要再次计算（或者优化 findBestMatch 让它返回 ratio）
                    // 这里为了简单，再次调用 evaluateOverlapRatio
                    if let (_, ratio) = StitchAlgorithm.evaluateOverlapRatio(topImage: refImage, bottomImage: matchedImage) {
                        // 拼接并更新 lastImage
                        if let mergedImage = StitchAlgorithm.mergeImages(topImage: refImage, bottomImage: matchedImage, overlapRatio: ratio) {
                            lastImage = mergedImage
                            print("[VideoStitcher-Algo] Updated reference frame with merged image (height: \(mergedImage.size.height))")
                        } else {
                            // 拼接失败（理论上不应发生），回退到使用单帧作为参考
                            lastImage = matchedImage
                            print("[VideoStitcher-Algo] Merge failed, used single frame as reference")
                        }
                    } else {
                        lastImage = matchedImage
                    }
                    
                    // 4. 滑动窗口：移除 [0...matchIndex]
                    // 注意：数组移除操作开销较大，但这能保持 buffer 逻辑简单
                    frameBuffer.removeFirst(matchIndex + 1)
                } else {
                    // 没找到匹配帧
                    print("[VideoStitcher-Algo] No match found in current buffer. Discarding all \(frameBuffer.count) frames.")
                    // 策略：丢弃整个 buffer，继续读下一批
                    // 参考帧不变
                    frameBuffer.removeAll()
                }
            }
            
            // 如果视频读完了且 buffer 也处理空了（或被清空了），退出循环
            if !hasMoreFrames && frameBuffer.isEmpty {
                break
            }
        }
        
        print("[VideoStitcher] Finished reading video frames, total frames: \(frameCount)")
        
        // 添加最后一个片段
        if !currentSegment.isEmpty {
            segments.append(currentSegment)
            print("[VideoStitcher] Added final segment to segments array, total segments: \(segments.count)")
        }
        
        // 合并片段并返回结果
        var frames: [UIImage] = []
        for segment in segments {
            frames.append(contentsOf: segment)
        }
        
        print("[VideoStitcher] Total frames after processing: \(frames.count)")
        
        DispatchQueue.main.async {
            if frames.count < 2 {
                print("[VideoStitcher] Insufficient frames for stitching: \(frames.count) < 2")
                completion(nil, NSError(domain: "VideoStitcher", code: -3, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("insufficient_video_content", comment: "Insufficient video content")]))
            } else {
                print("[VideoStitcher] Successfully extracted \(frames.count) frames for stitching")
                completion(frames, nil)
            }
        }
    }
    
    // 递归二分查找最佳匹配帧
    // 优先找离 end 最近的匹配帧
    private func findBestMatch(referenceImage: UIImage, buffer: [UIImage], start: Int, end: Int, minOverlap: Double, maxOverlap: Double) -> Int? {
        if start > end { return nil }
        
        let targetImage = buffer[end]
        
        // 1. 检查 end 是否匹配
        if let (_, ratio) = StitchAlgorithm.evaluateOverlapRatio(topImage: referenceImage, bottomImage: targetImage) {
            if ratio >= minOverlap && ratio <= maxOverlap {
                // 找到了一个匹配，且因为我们是从后往前（通过递归结构），这通常是该区间内较远的匹配
                // 但为了严谨，我们应该确保它是“最远”的吗？
                // 用户的逻辑是：先看最远，如果匹配就选它。
                // 所以这里直接返回 end 是符合“贪心”策略的（步子跨得越大越好）
                return end
            }
        }
        
        // 2. 没匹配，二分
        let mid = (start + end) / 2
        
        if mid == end { // 区间只剩 1 个且不匹配
            return nil
        }
        
        // 优先搜右半边 (mid+1, end) -> 其实上面已经检查了 end，所以区间是 (mid, end-1)
        // 修正：我们按照二分切割逻辑
        // 先看右半边 [mid+1, end] 里的最佳匹配
        if let rightMatch = findBestMatch(referenceImage: referenceImage, buffer: buffer, start: mid + 1, end: end, minOverlap: minOverlap, maxOverlap: maxOverlap) {
            return rightMatch
        }
        
        // 右边没找到，搜左半边 [start, mid]
        return findBestMatch(referenceImage: referenceImage, buffer: buffer, start: start, end: mid, minOverlap: minOverlap, maxOverlap: maxOverlap)
    }
    
    // 删除旧的 processFrameBuffer 函数
    private func unused_processFrameBuffer(_ buffer: inout [UIImage], 
                                   currentSegment: inout [UIImage], 
                                   segments: inout [[UIImage]], 
                                   lastImage: inout UIImage?,
                                   minOverlap: Double,
                                   maxOverlap: Double) {
         // ... existing code ...
    }
    
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
