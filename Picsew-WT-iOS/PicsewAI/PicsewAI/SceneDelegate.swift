import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // 创建主标签栏控制器
        let tabBarController = MainTabBarController()
        
        // 创建窗口并设置根控制器
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = tabBarController
        window?.makeKeyAndVisible()
        
        // 开始监听录屏插件的通知
        setupBroadcastObserver()
    }

    private func setupBroadcastObserver() {
        BroadcastManager.shared.startObserving { [weak self] in
            self?.checkAndProcessBroadcast()
        }
    }

    private func checkAndProcessBroadcast() {
        guard BroadcastManager.shared.hasPendingRecording(),
              let videoURL = BroadcastManager.shared.recordingFileURL else {
            return
        }
        
        // 获取当前最顶层的导航控制器
        guard let tabBar = window?.rootViewController as? UITabBarController,
              let nav = tabBar.selectedViewController as? UINavigationController else {
            return
        }
        
        // 弹出加载提示
        let loadingAlert = UIAlertController(title: NSLocalizedString("auto_recognizing_recording", comment: "Auto recognizing recording"), message: NSLocalizedString("please_wait", comment: "Please wait"), preferredStyle: .alert)
        nav.present(loadingAlert, animated: true)
        
        // 调用 VideoStitcher 处理视频
        VideoStitcher.shared.extractKeyFrames(from: videoURL) { images, error in
            loadingAlert.dismiss(animated: true) {
                if let error = error {
                    let errorAlert = UIAlertController(title: NSLocalizedString("recognition_failed", comment: "Recognition failed"), message: error.localizedDescription, preferredStyle: .alert)
                    errorAlert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default))
                    nav.present(errorAlert, animated: true)
                } else if let images = images, !images.isEmpty {
                    let autoStitchVC = AutoStitchViewController()
                    autoStitchVC.setInputImagesFromVideo(images)
                    nav.pushViewController(autoStitchVC, animated: true)
                }
                
                // 处理完成后清除文件，防止重复触发
                BroadcastManager.shared.clearPendingRecording()
            }
        }
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // App 激活时也检查一次是否有待处理的录屏（例如用户结束录屏后手动回到 App）
        checkAndProcessBroadcast()
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }
}
