import ReplayKit
import AVFoundation

class SampleHandler: RPBroadcastSampleHandler {
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var isRecording = false
    private let appGroupId = "group.com.beverg.picsewai"
    private let recordingFileName = "broadcast_recording.mp4"
    
    // 自动停止相关变量
    private var userActivityTimer: Timer?
    private var lastFrameChangeTime: TimeInterval = 0
    private var autoStopDuration: TimeInterval = 5.0 // 默认5秒
    private var frameChangeThreshold: UInt8 = 10 // 像素变化阈值，用于判断用户是否有操作
    private var previousFrameBuffer: CVImageBuffer?
    
    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        // 获取共享容器路径
        guard let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            finishBroadcastWithError(NSError(domain: "BroadcastError", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法访问共享容器"]))
            return
        }
        
        // 从App Group的UserDefaults中读取自动停止时长
        if let appGroupUserDefaults = UserDefaults(suiteName: appGroupId) {
            if let savedDuration = appGroupUserDefaults.object(forKey: "scrollDuration") as? Int {
                autoStopDuration = TimeInterval(savedDuration)
            }
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
            
            // 初始化用户活动检测
            setupUserActivityDetection()
        } catch {
            finishBroadcastWithError(error)
        }
    }
    
    // 初始化用户活动检测
    private func setupUserActivityDetection() {
        lastFrameChangeTime = Date().timeIntervalSince1970
        
        // 启动定时器，每1秒检查一次
        userActivityTimer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.checkUserActivity()
        }
        
        // 添加定时器到RunLoop
        RunLoop.main.add(userActivityTimer!, forMode: .common)
    }
    
    // 检查用户活动
    private func checkUserActivity() {
        let currentTime = Date().timeIntervalSince1970
        let timeSinceLastActivity = currentTime - lastFrameChangeTime
        
        if timeSinceLastActivity >= autoStopDuration {
            // 停止录屏
            stopRecordingDueToInactivity()
        }
    }
    
    // 由于用户不活动停止录屏
    private func stopRecordingDueToInactivity() {
        // 停止定时器
        userActivityTimer?.invalidate()
        userActivityTimer = nil
        
        // 停止录屏
        finishBroadcastWithError(NSError(domain: "BroadcastError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Auto stopped due to inactivity"]))
    }
    
    // 检测视频帧变化
    private func detectFrameChange(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return false
        }
        
        // 简单的帧变化检测：比较当前帧与前一帧的像素差异
        let hasChanged = compareFrame(pixelBuffer)
        
        if hasChanged {
            lastFrameChangeTime = Date().timeIntervalSince1970
        }
        
        // 更新前一帧
        previousFrameBuffer = pixelBuffer
        
        return hasChanged
    }
    
    // 比较当前帧与前一帧
    private func compareFrame(_ currentPixelBuffer: CVImageBuffer) -> Bool {
        guard let previousPixelBuffer = previousFrameBuffer else {
            return true // 第一帧，认为有变化
        }
        
        // 获取帧的尺寸
        let width = CVPixelBufferGetWidth(currentPixelBuffer)
        let height = CVPixelBufferGetHeight(currentPixelBuffer)
        
        // 只比较每隔几个像素点，提高性能
        let step = 10
        let totalPixelsToCheck = (width / step) * (height / step)
        var differentPixels = 0
        
        // 锁定像素缓冲区
        CVPixelBufferLockBaseAddress(currentPixelBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(previousPixelBuffer, .readOnly)
        
        defer {
            CVPixelBufferUnlockBaseAddress(currentPixelBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(previousPixelBuffer, .readOnly)
        }
        
        // 获取像素数据
        guard let currentBaseAddress = CVPixelBufferGetBaseAddress(currentPixelBuffer),
              let previousBaseAddress = CVPixelBufferGetBaseAddress(previousPixelBuffer) else {
            return false
        }
        
        // 假设是RGBA格式，每个像素4字节
        let bytesPerPixel = 4
        let bytesPerRow = CVPixelBufferGetBytesPerRow(currentPixelBuffer)
        
        // 比较像素
        for y in stride(from: 0, to: height, by: step) {
            for x in stride(from: 0, to: width, by: step) {
                let currentOffset = y * bytesPerRow + x * bytesPerPixel
                let previousOffset = y * bytesPerRow + x * bytesPerPixel
                
                let currentPixel = currentBaseAddress.advanced(by: currentOffset).assumingMemoryBound(to: UInt8.self)
                let previousPixel = previousBaseAddress.advanced(by: previousOffset).assumingMemoryBound(to: UInt8.self)
                
                // 比较RGB值的差异
                let rDiff = abs(Int(currentPixel[0]) - Int(previousPixel[0]))
                let gDiff = abs(Int(currentPixel[1]) - Int(previousPixel[1]))
                let bDiff = abs(Int(currentPixel[2]) - Int(previousPixel[2]))
                
                if rDiff + gDiff + bDiff > Int(frameChangeThreshold) {
                    differentPixels += 1
                    
                    // 如果差异像素超过10%，直接返回有变化
                    if differentPixels > totalPixelsToCheck / 10 {
                        return true
                    }
                }
            }
        }
        
        return differentPixels > totalPixelsToCheck / 20 // 差异像素超过5%，认为有变化
    }
    
    override func broadcastPaused() {
        // 暂停逻辑
        userActivityTimer?.invalidate()
        userActivityTimer = nil
    }
    
    override func broadcastResumed() {
        // 恢复逻辑
        setupUserActivityDetection()
    }
    
    override func broadcastFinished() {
        // 停止定时器
        userActivityTimer?.invalidate()
        userActivityTimer = nil
        
        isRecording = false
        videoInput?.markAsFinished()
        assetWriter?.finishWriting { [weak self] in
            // 发送 Darwin 通知告知主应用录屏完成
            let notificationName = "com.beverg.picsewai.broadcast.finished" as CFString
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
                
                // 检测帧变化
                _ = detectFrameChange(sampleBuffer)
                
                if videoInput?.isReadyForMoreMediaData == true {
                    videoInput?.append(sampleBuffer)
                }
            }
        default:
            break
        }
    }
}
