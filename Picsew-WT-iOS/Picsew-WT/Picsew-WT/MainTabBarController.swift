import UIKit

class MainTabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // 使用自定义 TabBar 以统一高度
        setValue(CustomTabBar(), forKey: "tabBar")
        setupTabBar()
    }
    
    private func setupTabBar() {
        // 创建图片拼接控制器 (HomeViewController 是新的图片选择入口)
        let homeVC = HomeViewController()
        let homeNav = UINavigationController(rootViewController: homeVC)
        homeNav.tabBarItem = UITabBarItem(title: NSLocalizedString("image_stitch", comment: "图片拼图"), image: UIImage(systemName: "photo"), selectedImage: UIImage(systemName: "photo.fill"))
        
        // 创建视频截图控制器
        let videoCaptureVC = VideoCaptureViewController()
        let videoCaptureNav = UINavigationController(rootViewController: videoCaptureVC)
        videoCaptureNav.tabBarItem = UITabBarItem(title: NSLocalizedString("video_capture", comment: "视频拼图"), image: UIImage(systemName: "video"), selectedImage: UIImage(systemName: "video.fill"))
        
        // 创建设置控制器
        let settingsVC = SettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(title: NSLocalizedString("settings", comment: "设置"), image: UIImage(systemName: "gear"), selectedImage: UIImage(systemName: "gear.fill"))
        
        // 设置标签栏
        viewControllers = [homeNav, videoCaptureNav, settingsNav]
        
        // 设置标签栏外观
        tabBar.tintColor = .systemBlue
        tabBar.unselectedItemTintColor = .systemGray
        tabBar.backgroundColor = .white
        
        // 设置选中指示器
        if #available(iOS 15.0, *) {
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            tabBar.standardAppearance = appearance
            tabBar.scrollEdgeAppearance = appearance
        }
    }
}

class CustomTabBar: UITabBar {
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        var sizeThatFits = super.sizeThatFits(size)
        let bottomPadding: CGFloat = {
            if #available(iOS 11.0, *) {
                // 优先从窗口获取安全区域，如果获取不到则使用默认值
                let window = UIApplication.shared.windows.first { $0.isKeyWindow } ?? UIApplication.shared.windows.first
                return window?.safeAreaInsets.bottom ?? 0
            }
            return 0
        }()
        // 统一高度为 60pt (安全区域上方) + 安全区域高度
        sizeThatFits.height = 60 + bottomPadding
        return sizeThatFits
    }
}
