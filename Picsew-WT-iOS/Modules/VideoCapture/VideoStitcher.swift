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
    func processVideo(asset: PHAsset, completion: @escaping VideoProcessCompletion) {
        let options = PHVideoRequestOptions()
        options.version = .original
        options.isNetworkAccessAllowed = true
        
        PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { [weak self] avAsset, _, _ in
            guard let urlAsset = avAsset as? AVURLAsset else {
                completion(nil, NSError(domain: "VideoStitcher", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法获取视频资源"]))
                return
            }
            
            self?.extractKeyFrames(from: urlAsset.url, completion: completion)
        }
    }
    
    /// 从本地视频 URL 提取关键帧
    func extractKeyFrames(from url: URL, completion: @escaping VideoProcessCompletion) {
        let asset = AVAsset(url: url)
        let reader: AVAssetReader
        do {
            reader = try AVAssetReader(asset: asset)
        } catch {
            completion(nil, error)
            return
        }
        
        guard let videoTrack = asset.tracks(withMediaType: .video).first else {
            completion(nil, NSError(domain: "VideoStitcher", code: -2, userInfo: [NSLocalizedDescriptionKey: "找不到视频轨道"]))
            return
        }
        
        let outputSettings: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        let readerOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: outputSettings)
        reader.add(readerOutput)
        reader.startReading()
        
        var segments: [[UIImage]] = []
        var currentSegment: [UIImage] = []
        var lastImage: UIImage?

        let fps = videoTrack.nominalFrameRate
        let sampleInterval = Int(fps / 2) // 每秒取 2 帧
        var frameCount = 0
        
        while let sampleBuffer = readerOutput.copyNextSampleBuffer() {
            frameCount += 1
            if frameCount % sampleInterval != 0 {
                continue
            }
            
            if let image = imageFromSampleBuffer(sampleBuffer) {
                if let last = lastImage {
                    if let diff = StitchAlgorithm.evaluateOverlap(topImage: last, bottomImage: image) {
                        if diff < 5.0 {
                            continue
                        }
                        currentSegment.append(image)
                    } else {
                        if !currentSegment.isEmpty {
                            segments.append(currentSegment)
                        }
                        currentSegment = [image]
                    }
                } else {
                    currentSegment = [image]
                }
                lastImage = image
            }
        }
        if !currentSegment.isEmpty {
            segments.append(currentSegment)
        }
        let minSegmentLength = 3
        let filteredSegments = segments.filter { $0.count >= minSegmentLength }
        let frames: [UIImage]
        if filteredSegments.isEmpty {
            frames = segments.flatMap { $0 }
        } else {
            frames = filteredSegments.flatMap { $0 }
        }
        
        DispatchQueue.main.async {
            if frames.count < 2 {
                completion(nil, NSError(domain: "VideoStitcher", code: -3, userInfo: [NSLocalizedDescriptionKey: "视频内容不足以生成长截图，请确保有滑动操作"]))
            } else {
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
