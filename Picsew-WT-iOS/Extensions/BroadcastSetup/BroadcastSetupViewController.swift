import UIKit
import ReplayKit

/// 控制中心录屏设置界面控制器
@objc(BroadcastSetupViewController)
internal class BroadcastSetupViewController: UIViewController {
    
    // 开始录屏按钮
    @IBOutlet private weak var startButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // 设置背景色
        view.backgroundColor = UIColor(white: 0.1, alpha: 1.0)
    }
    
    @IBAction private func startBroadcast() {
        // 告知系统设置已完成，准备开始广播
        self.extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }
}
