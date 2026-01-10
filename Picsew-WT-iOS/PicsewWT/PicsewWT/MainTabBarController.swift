import UIKit

class MainTabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabBar()
    }
    
    private func setupTabBar() {
        // 创建视频截图控制器
        let videoCaptureVC = VideoCaptureViewController()
        let videoCaptureNav = UINavigationController(rootViewController: videoCaptureVC)
        videoCaptureNav.tabBarItem = UITabBarItem(title: NSLocalizedString("video_capture", comment: "视频截图"), image: UIImage(systemName: "video"), selectedImage: UIImage(systemName: "video.fill"))
        
        // 创建图片拼接控制器
        let imageStitchVC = ImageStitchViewController()
        let imageStitchNav = UINavigationController(rootViewController: imageStitchVC)
        imageStitchNav.tabBarItem = UITabBarItem(title: NSLocalizedString("image_stitch", comment: "图片拼接"), image: UIImage(systemName: "photo"), selectedImage: UIImage(systemName: "photo.fill"))
        
        // 创建设置控制器
        let settingsVC = SettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(title: NSLocalizedString("settings", comment: "设置"), image: UIImage(systemName: "gear"), selectedImage: UIImage(systemName: "gear.fill"))
        
        // 设置标签栏
        viewControllers = [videoCaptureNav, imageStitchNav, settingsNav]
        
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
