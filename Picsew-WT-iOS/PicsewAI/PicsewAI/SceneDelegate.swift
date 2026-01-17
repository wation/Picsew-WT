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
        
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // App 激活时检查是否有待处理的录屏（例如用户结束录屏后手动回到 App）
        // 但不再直接处理，而是由 VideoCaptureViewController 统一处理
        guard let tabBar = window?.rootViewController as? UITabBarController,
              let viewControllers = tabBar.viewControllers else {
            return
        }
        
        // 查找以 VideoCaptureViewController 作为根控制器的导航栈并选中它
        for (index, controller) in viewControllers.enumerated() {
            if let nav = controller as? UINavigationController,
               let root = nav.viewControllers.first,
               root is VideoCaptureViewController {
                tabBar.selectedIndex = index
                break
            }
        }
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
