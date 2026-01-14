import ReplayKit
import AVFoundation

class SampleHandler: RPBroadcastSampleHandler {
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var isRecording = false
    private let appGroupId = "group.com.magixun.picsewwt"
    private let recordingFileName = "broadcast_recording.mp4"
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // 获取共享容器路径
        guard let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            finishBroadcastWithError(NSError(domain: "BroadcastError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法访问共享容器"]))
            return
        }
        
        let fileURL = sharedURL.appendingPathComponent(recordingFileName)
        
        // 如果文件已存在则删除
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        do {
            assetWriter = try AVAssetWriter(url: fileURL, fileType: .mp4)
            
            // 视频配置
            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: UIScreen.main.bounds.width * UIScreen.main.scale,
                AVVideoHeightKey: UIScreen.main.bounds.height * UIScreen.main.scale,
                AVVideoCompressionPropertiesKey: [
                    AVVideoAverageBitRateKey: 4000000,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
                ]
            ]
            
            videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            videoInput?.expectsMediaDataInRealTime = true
            
            if let videoInput = videoInput, assetWriter?.canAdd(videoInput) == true {
                assetWriter?.add(videoInput)
            }
            
            assetWriter?.startWriting()
            isRecording = true
        } catch {
            finishBroadcastWithError(error)
        }
    }
    
    override func broadcastPaused() {
        // 暂停逻辑
    }
    
    override func broadcastResumed() {
        // 恢复逻辑
    }
    
    override func broadcastFinished() {
        isRecording = false
        videoInput?.markAsFinished()
        assetWriter?.finishWriting { [weak self] in
            // 发送 Darwin 通知告知主应用录屏完成
            let notificationName = "com.magixun.picsewwt.broadcast.finished" as CFString
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(notificationName), nil, nil, true)
        }
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            if isRecording, assetWriter?.status == .writing {
                if assetWriter?.overallDurationHint == .zero {
                    assetWriter?.startSession(atSourceTime: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                }
                
                if videoInput?.isReadyForMoreMediaData == true {
                    videoInput?.append(sampleBuffer)
                }
            }
        default:
            break
        }
    }
}
