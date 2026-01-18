import UIKit
import AVFoundation
import Photos
import Metal

class VideoStitcher {
    static let shared = VideoStitcher()
    private let ciContext: CIContext = {
        if let device = MTLCreateSystemDefaultDevice() {
            return CIContext(mtlDevice: device)
        } else {
            return CIContext(options: [CIContextOption.useSoftwareRenderer: false])
        }
    }()
    
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
        let targetFPS: Float = 3.0
        let sampleInterval = max(1, Int(fps / targetFPS))
        let bufferSize = 10 // 抽帧后的缓冲区大小，约可容纳 3 秒的视频内容
        var frameBuffer: [UIImage] = []
        print("[VideoStitcher] Video FPS: \(fps), sample interval: \(sampleInterval), buffer size: \(bufferSize)")
        
        var frameCount = 0
        var extractedFrameCount = 0
        var addedFrameCount = 0
        
        // 快速搜索参数
        let minOverlapRatio: Double = 0.15 // 降低最小重合率要求，适应快速滚动
        let maxOverlapRatio: Double = 0.90 // 扩大最大重合率要求，适应慢速滚动
        
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
        
        let startTime = CFAbsoluteTimeGetCurrent()
        while true {
            // 填充 buffer
            var hasMoreFrames = true
            while frameBuffer.count < bufferSize {
                if let sampleBuffer = readerOutput.copyNextSampleBuffer() {
                    frameCount += 1
                    // 1秒内抽3帧：仅在符合采样间隔时提取图像
                    if frameCount % sampleInterval == 0 {
                        if let image = imageFromSampleBuffer(sampleBuffer) {
                            frameBuffer.append(image)
                            extractedFrameCount += 1
                        }
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
                    
                    // 使用当前匹配到的帧作为下一次对比的参考帧，而不是使用合并后的长图
                    // 这样可以避免参考帧高度不断增加导致百分比裁剪逻辑失效
                    lastImage = matchedImage
                    
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
            
            if CFAbsoluteTimeGetCurrent() - startTime > 9.5 {
                frameBuffer.removeAll()
                break
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
        guard let precomputed = StitchAlgorithm.prepareTopOverlapData(referenceImage) else {
            return legacyFindBestMatch(referenceImage: referenceImage, buffer: buffer, start: start, end: end, minOverlap: minOverlap, maxOverlap: maxOverlap)
        }
        
        func search(_ start: Int, _ end: Int) -> Int? {
            if start > end { return nil }
            let targetImage = buffer[end]
            if let (_, ratio) = StitchAlgorithm.evaluateOverlapRatioPrecomputed(topSmall: precomputed.cgImage, topData: precomputed.data, bottomImage: targetImage) {
                if ratio >= minOverlap && ratio <= maxOverlap {
                    return end
                }
            }
            let mid = (start + end) / 2
            if mid == end {
                return nil
            }
            if let rightMatch = search(mid + 1, end) {
                return rightMatch
            }
            return search(start, mid)
        }
        
        return search(start, end)
    }
    
    private func legacyFindBestMatch(referenceImage: UIImage, buffer: [UIImage], start: Int, end: Int, minOverlap: Double, maxOverlap: Double) -> Int? {
        if start > end { return nil }
        let targetImage = buffer[end]
        if let (_, ratio) = StitchAlgorithm.evaluateOverlapRatio(topImage: referenceImage, bottomImage: targetImage) {
            if ratio >= minOverlap && ratio <= maxOverlap {
                return end
            }
        }
        let mid = (start + end) / 2
        if mid == end {
            return nil
        }
        if let rightMatch = legacyFindBestMatch(referenceImage: referenceImage, buffer: buffer, start: mid + 1, end: end, minOverlap: minOverlap, maxOverlap: maxOverlap) {
            return rightMatch
        }
        return legacyFindBestMatch(referenceImage: referenceImage, buffer: buffer, start: start, end: mid, minOverlap: minOverlap, maxOverlap: maxOverlap)
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
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
