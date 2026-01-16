import Foundation
import UIKit

/// 处理主应用与录屏插件（Broadcast Upload Extension）之间的通信与协调
class BroadcastManager {
    static let shared = BroadcastManager()
    
    // App Group ID，需要与插件保持一致
    private let appGroupId = "group.com.beverg.picsewai"
    private let recordingFileName = "broadcast_recording.mp4"
    
    private init() {}
    
    /// 获取 App Group 共享目录
    var sharedContainerURL: URL? {
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }
    
    /// 获取录屏文件路径
    var recordingFileURL: URL? {
        return sharedContainerURL?.appendingPathComponent(recordingFileName)
    }
    
    /// 检查是否有待处理的录屏文件
    func hasPendingRecording() -> Bool {
        guard let url = recordingFileURL else {
            print("[BroadcastManager] Error: Could not construct recording file URL.")
            return false
        }
        let exists = FileManager.default.fileExists(atPath: url.path)
        print("[BroadcastManager] Checking pending recording at: \(url.path), exists: \(exists)")
        if let defaults = UserDefaults(suiteName: appGroupId),
           let status = defaults.string(forKey: "broadcast_debug_status") {
            print("[BroadcastManager] Extension debug status: \(status)")
        }
        return exists
    }
    
    /// 清除处理完的录屏文件
    func clearPendingRecording() {
        guard let url = recordingFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
    
    private var observerCallback: (() -> Void)?
    
    /// 监听录屏完成的通知（通过 DarwinNotificationCenter）
    func startObserving(callback: @escaping () -> Void) {
        self.observerCallback = callback
        let name = "com.beverg.picsewai.broadcast.finished" as CFString
        
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { (_, observer, _, _, _) in
                guard let observer = observer else { return }
                let manager = Unmanaged<BroadcastManager>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.observerCallback?()
                }
            },
            name,
            nil,
            .deliverImmediately
        )
    }
}
