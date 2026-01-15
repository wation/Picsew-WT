import UIKit

class ScrollSettingsViewController: UIViewController {
    
    private var scrollDuration: Int = 5 // 默认5秒
    
    private lazy var durationLabel: UILabel = {
        let label = UILabel()
        label.text = String(format: NSLocalizedString("auto_scroll_duration", comment: "Auto scroll duration label"), scrollDuration)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var stepper: UIStepper = {
        let stepper = UIStepper()
        stepper.minimumValue = 1
        stepper.maximumValue = 30
        stepper.stepValue = 1
        stepper.value = Double(scrollDuration)
        stepper.translatesAutoresizingMaskIntoConstraints = false
        stepper.addTarget(self, action: #selector(stepperValueChanged(_:)), for: .valueChanged)
        return stepper
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = NSLocalizedString("scroll_settings", comment: "Scroll settings title")
        
        view.addSubview(durationLabel)
        view.addSubview(stepper)
        
        NSLayoutConstraint.activate([
            durationLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            durationLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            
            stepper.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stepper.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 30)
        ])
    }
    
    private func loadSettings() {
        if let appGroupUserDefaults = UserDefaults(suiteName: "group.com.beverg.picsewai") {
            if let savedDuration = appGroupUserDefaults.object(forKey: "scrollDuration") as? Int {
                scrollDuration = savedDuration
                stepper.value = Double(scrollDuration)
                durationLabel.text = String(format: NSLocalizedString("auto_scroll_duration", comment: "Auto scroll duration label"), scrollDuration)
            }
        } else if let savedDuration = UserDefaults.standard.object(forKey: "scrollDuration") as? Int {
            // 兼容旧版设置
            scrollDuration = savedDuration
            stepper.value = Double(scrollDuration)
            durationLabel.text = String(format: NSLocalizedString("auto_scroll_duration", comment: "Auto scroll duration label"), scrollDuration)
            // 迁移到App Group
            saveSettings()
        }
    }
    
    @objc private func stepperValueChanged(_ stepper: UIStepper) {
        scrollDuration = Int(stepper.value)
        durationLabel.text = String(format: NSLocalizedString("auto_scroll_duration", comment: "Auto scroll duration label"), scrollDuration)
        
        // 保存设置
        saveSettings()
    }
    
    private func saveSettings() {
        // 保存到App Group的UserDefaults
        if let appGroupUserDefaults = UserDefaults(suiteName: "group.com.beverg.picsewai") {
            appGroupUserDefaults.set(scrollDuration, forKey: "scrollDuration")
        }
        // 同时保存到标准UserDefaults，确保兼容性
        UserDefaults.standard.set(scrollDuration, forKey: "scrollDuration")
    }
}
