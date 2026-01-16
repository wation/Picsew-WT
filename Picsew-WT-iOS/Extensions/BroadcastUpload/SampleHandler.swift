import ReplayKit
import AVFoundation
import Foundation

class SampleHandler: RPBroadcastSampleHandler {
    
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var isRecording = false
    private var hasStartedSession = false
    private let appGroupId = "group.com.beverg.picsewai"
    private let recordingFileName = "broadcast_recording.mp4"
    private var hasCompletedRecording = false
    
    // 自动停止相关变量
    private var userActivityTimer: Timer?
    private var lastFrameChangeTime: TimeInterval = 0
    private var autoStopDuration: TimeInterval = 5.0 // 默认5秒
    private var frameChangeThreshold: UInt8 = 10 // 像素变化阈值，用于判断用户是否有操作
    private var previousFrameBuffer: CVImageBuffer?
    
    // -----------------------
    private func updateSharedDebugStatus(_ message: String) {
        if let defaults = UserDefaults(suiteName: appGroupId) {
            defaults.set(message, forKey: "broadcast_debug_status")
        }
    }

    override func broadcastStarted(withSetupInfo setupInfo: [String : NSObject]?) {
        print("[SampleHandler] broadcastStarted")
        // 获取共享容器路径，用于后续移动文件和读取配置
        guard let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
            updateSharedDebugStatus("cannot_access_shared_container")
            finishBroadcastWithError(NSError(domain: "BroadcastError", code: -1, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("cannot_access_shared_container", comment: "Cannot access shared container")]))
            return
        }
        
        // 从App Group的UserDefaults中读取自动停止时长
        if let appGroupUserDefaults = UserDefaults(suiteName: appGroupId) {
            if let savedDuration = appGroupUserDefaults.object(forKey: "stopDuration") as? Int {
                autoStopDuration = TimeInterval(savedDuration)
            }
        }
        
        // 先清理 App Group 中可能残留的旧文件，避免主应用误判
        let finalURL = sharedURL.appendingPathComponent(recordingFileName)
        if FileManager.default.fileExists(atPath: finalURL.path) {
            try? FileManager.default.removeItem(at: finalURL)
        }
        
        // 实际写入使用扩展自身的临时目录，避免直接写 App Group 失败
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent(recordingFileName)
        if FileManager.default.fileExists(atPath: tempURL.path) {
            try? FileManager.default.removeItem(at: tempURL)
        }
        
        do {
            assetWriter = try AVAssetWriter(url: tempURL, fileType: .mp4)
            print("[SampleHandler] AVAssetWriter initialized at temp path: \(tempURL.path)")
            
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
            } else {
                print("[SampleHandler] Failed to add video input")
                updateSharedDebugStatus("failed_add_video_input")
                finishBroadcastWithError(NSError(domain: "BroadcastError", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to add video input"]))
                return
            }
            
            if assetWriter?.startWriting() == true {
                isRecording = true
                hasStartedSession = false
                print("[SampleHandler] startWriting succeeded")
                updateSharedDebugStatus("start_writing_success:\(finalURL.path)")
                // 初始化用户活动检测
                setupUserActivityDetection()
            } else {
                print("[SampleHandler] startWriting failed: \(assetWriter?.error?.localizedDescription ?? "unknown")")
                updateSharedDebugStatus("start_writing_failed:\(assetWriter?.error?.localizedDescription ?? "unknown")")
                finishBroadcastWithError(assetWriter?.error ?? NSError(domain: "BroadcastError", code: -2, userInfo: nil))
            }
        } catch {
            print("[SampleHandler] AVAssetWriter init error: \(error.localizedDescription)")
            updateSharedDebugStatus("asset_writer_init_error:\(error.localizedDescription)")
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
    
    private func completeRecordingIfNeeded(completion: (() -> Void)? = nil) {
        if hasCompletedRecording {
            print("[SampleHandler] completeRecordingIfNeeded called but already completed")
            completion?()
            return
        }
        print("[SampleHandler] completeRecordingIfNeeded start")
        hasCompletedRecording = true
        userActivityTimer?.invalidate()
        userActivityTimer = nil
        isRecording = false
        hasStartedSession = false
        videoInput?.markAsFinished()
        
        let finishGroup = DispatchGroup()
        finishGroup.enter()
        
        if let writer = assetWriter, writer.status == .writing {
            writer.finishWriting {
                let tempURL = writer.outputURL
                let tempExists = FileManager.default.fileExists(atPath: tempURL.path)
                var finalExists = false
                
                if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.appGroupId) {
                    let finalURL = sharedURL.appendingPathComponent(self.recordingFileName)
                    if FileManager.default.fileExists(atPath: finalURL.path) {
                        try? FileManager.default.removeItem(at: finalURL)
                    }
                    do {
                        try FileManager.default.moveItem(at: tempURL, to: finalURL)
                    } catch {
                        print("[SampleHandler] move temp file to App Group failed: \(error.localizedDescription)")
                        self.updateSharedDebugStatus("move_failed:\(error.localizedDescription), temp_exists:\(tempExists), temp_url:\(tempURL.path)")
                    }
                    finalExists = FileManager.default.fileExists(atPath: finalURL.path)
                    print("[SampleHandler] finishWriting completed, tempExists: \(tempExists), finalExists: \(finalExists), finalURL: \(finalURL.path)")
                    self.updateSharedDebugStatus("finish_writing_status:\(writer.status.rawValue), temp_exists:\(tempExists), final_exists:\(finalExists), final_url:\(finalURL.path)")
                } else {
                    print("[SampleHandler] cannot_access_shared_container when moving file")
                    self.updateSharedDebugStatus("cannot_access_shared_container_on_finish")
                }
                
                let notificationName = "com.beverg.picsewai.broadcast.finished" as CFString
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFNotificationName(notificationName), nil, nil, true)
                
                finishGroup.leave()
            }
        } else {
            finishGroup.leave()
        }
        
        finishGroup.notify(queue: .main) {
            completion?()
        }
    }

    private func stopRecordingDueToInactivity() {
        print("[SampleHandler] stopRecordingDueToInactivity")
        let error = NSError(domain: "BroadcastError", code: 0, userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("auto_stopped_inactivity", comment: "Auto stopped due to inactivity")])
        completeRecordingIfNeeded { [weak self] in
            // 确保文件写入完成且通知已发送后再结束广播
            self?.finishBroadcastWithError(error)
        }
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
        print("[SampleHandler] broadcastPaused")
        userActivityTimer?.invalidate()
        userActivityTimer = nil
    }
    
    override func broadcastResumed() {
        // 恢复逻辑
        print("[SampleHandler] broadcastResumed")
        setupUserActivityDetection()
    }
    
    override func broadcastFinished() {
        print("[SampleHandler] broadcastFinished")
        completeRecordingIfNeeded()
    }
    
    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        switch sampleBufferType {
        case .video:
            if !isRecording {
                print("[SampleHandler] Received video sample while not recording")
            }
            guard isRecording,
                  let writer = assetWriter,
                  writer.status == .writing,
                  let videoInput = videoInput else {
                return
            }
            
            if !hasStartedSession {
                let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                print("[SampleHandler] startSession at time: \(time)")
                writer.startSession(atSourceTime: time)
                hasStartedSession = true
            }
            
            _ = detectFrameChange(sampleBuffer)
            
            if videoInput.isReadyForMoreMediaData {
                videoInput.append(sampleBuffer)
            }
        default:
            break
        }
    }
}
