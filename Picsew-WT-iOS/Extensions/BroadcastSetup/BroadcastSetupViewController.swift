import UIKit
import ReplayKit

/// 控制中心录屏设置界面控制器
@objc(BroadcastSetupViewController)
internal class BroadcastSetupViewController: UIViewController {
    
    // 开始录屏按钮
    private let startButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        
        // 设置背景色
        view.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
    }
    
    private func setupUI() {
        startButton.setTitle("开始录屏", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = .systemBlue
        startButton.layer.cornerRadius = 12
        startButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        
        view.addSubview(startButton)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 200),
            startButton.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        startButton.addTarget(self, action: #selector(startBroadcast), for: .touchUpInside)
    }
    
    @objc private func startBroadcast() {
        // 告知系统设置已完成，准备开始广播
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
