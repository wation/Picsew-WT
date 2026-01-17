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
        let sampleInterval = Int(fps / 2) // 每秒取 2 帧
        print("[VideoStitcher] Video FPS: \(fps), sample interval: \(sampleInterval) frames")
        
        var frameCount = 0
        var extractedFrameCount = 0
        var addedFrameCount = 0
        
        // 原始帧收集逻辑，只保留变化足够大的帧
        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            frameCount += 1
            lastSampleBuffer = sampleBuffer
            
            if frameCount % sampleInterval != 0 {
                continue
            }
            
            extractedFrameCount += 1
            print("[VideoStitcher] Processing frame \(frameCount), extracted frame \(extractedFrameCount)")
            
            if let image = imageFromSampleBuffer(sampleBuffer) {
                if let last = lastImage {
                    if let diff = StitchAlgorithm.evaluateOverlap(topImage: last, bottomImage: image) {
                        print("[VideoStitcher] Frame difference: \(diff)")
                        if diff < 5.0 {
                            print("[VideoStitcher] Frame filtered out due to low difference (< 5.0)")
                            continue
                        }
                        currentSegment.append(image)
                        addedFrameCount += 1
                        print("[VideoStitcher] Frame added to current segment, current segment size: \(currentSegment.count)")
                    } else {
                        print("[VideoStitcher] Failed to evaluate overlap, creating new segment")
                        if !currentSegment.isEmpty {
                            segments.append(currentSegment)
                            print("[VideoStitcher] Added segment to segments array, total segments: \(segments.count)")
                        }
                        currentSegment = [image]
                        addedFrameCount += 1
                        print("[VideoStitcher] Created new segment with current frame")
                    }
                } else {
                    currentSegment = [image]
                    addedFrameCount += 1
                    print("[VideoStitcher] Created first segment with current frame")
                }
                lastImage = image
            } else {
                print("[VideoStitcher] Failed to convert sample buffer to UIImage")
            }
        }
        
        print("[VideoStitcher] Finished reading video frames, total frames: \(frameCount), extracted: \(extractedFrameCount), added: \(addedFrameCount)")
        
        // 确保处理最后一帧，即使它不符合采样间隔
        if let sampleBuffer = lastSampleBuffer,
           let image = imageFromSampleBuffer(sampleBuffer) {
            print("[VideoStitcher] Processing last sample buffer")
            // 检查最后一帧是否已经被添加
            let isLastFrameAdded = currentSegment.last.map { $0.isEqual(image) } ?? false
            if !isLastFrameAdded {
                currentSegment.append(image)
                addedFrameCount += 1
                print("[VideoStitcher] Added last frame to current segment, current segment size: \(currentSegment.count)")
            } else {
                print("[VideoStitcher] Last frame already in current segment")
            }
        }
        
        // 添加最后一个片段
        if !currentSegment.isEmpty {
            segments.append(currentSegment)
            print("[VideoStitcher] Added final segment to segments array, total segments: \(segments.count)")
        }
        
        print("[VideoStitcher] Segments before filtering: \(segments.count), total frames: \(segments.flatMap { $0 }.count)")
        
        // 片段过滤，只保留长度≥3的片段，但确保保留第一个和最后一个
        let minSegmentLength = 1 // 降低阈值，确保有足够的图片用于拼接
        var filteredSegments: [[UIImage]]
        
        if segments.count > 1 {
            // 如果有多个片段，过滤掉中间长度不足的片段，但保留第一个和最后一个
            filteredSegments = []
            for (index, segment) in segments.enumerated() {
                if index == 0 || index == segments.count - 1 || segment.count >= minSegmentLength {
                    filteredSegments.append(segment)
                    print("[VideoStitcher] Added segment \(index) to filtered segments, segment size: \(segment.count)")
                } else {
                    print("[VideoStitcher] Filtered out segment \(index), segment size: \(segment.count) < \(minSegmentLength)")
                }
            }
        } else {
            // 如果只有一个片段，直接使用
            filteredSegments = segments
            print("[VideoStitcher] Only one segment, using as-is")
        }
        
        let frames = filteredSegments.flatMap { $0 }
        print("[VideoStitcher] Filtered segments: \(filteredSegments.count), total frames after filtering: \(frames.count)")
        
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
    
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        let ciImage = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext()
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
