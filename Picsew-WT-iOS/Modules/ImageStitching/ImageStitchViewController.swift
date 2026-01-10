import UIKit

class ImageStitchViewController: UIViewController {
    
    // MARK: - UI 组件
    private let titleLabel = UILabel()
    private let tabStackView = UIStackView()
    private let autoStitchButton = UIButton(type: .system)
    private let manualStitchButton = UIButton(type: .system)
    private let tabIndicatorView = UIView()
    private let mainContentStackView = UIStackView()
    private let imageIconView = UIImageView()
    private let descriptionLabel = UILabel()
    private let startButton = UIButton(type: .system)
    
    // MARK: - 状态
    private var selectedTabIndex: Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray6
        setupUI()
        setupConstraints()
    }
    
    // MARK: - UI 设置
    private func setupUI() {
        // 设置标题
        titleLabel.text = "图片拼接"
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // 设置标签栏
        setupTabBar()
        
        // 设置主体内容
        setupMainContent()
        
        // 设置底部按钮
        setupStartButton()
    }
    
    private func setupTabBar() {
        // 标签栈视图
        tabStackView.axis = .horizontal
        tabStackView.distribution = .fillEqually
        tabStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabStackView)
        
        // 自动拼接按钮
        autoStitchButton.setTitle(NSLocalizedString("auto_stitch", comment: "自动拼接"), for: .normal)
        autoStitchButton.setTitleColor(.label, for: .normal)
        autoStitchButton.setTitleColor(.systemBlue, for: .selected)
        autoStitchButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        autoStitchButton.isSelected = true
        autoStitchButton.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
        tabStackView.addArrangedSubview(autoStitchButton)
        
        // 手动拼接按钮
        manualStitchButton.setTitle(NSLocalizedString("manual_stitch", comment: "手动拼接"), for: .normal)
        manualStitchButton.setTitleColor(.label, for: .normal)
        manualStitchButton.setTitleColor(.systemBlue, for: .selected)
        manualStitchButton.titleLabel?.font = UIFont.systemFont(ofSize: 14)
        manualStitchButton.isSelected = false
        manualStitchButton.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
        tabStackView.addArrangedSubview(manualStitchButton)
        
        // 标签指示器
        tabIndicatorView.backgroundColor = .systemBlue
        tabIndicatorView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabIndicatorView)
    }
    
    private func setupMainContent() {
        mainContentStackView.axis = .vertical
        mainContentStackView.alignment = .center
        mainContentStackView.spacing = 16
        mainContentStackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mainContentStackView)
        
        // 图片图标
        imageIconView.image = UIImage(systemName: "photo.stack")
        imageIconView.tintColor = .systemGray
        imageIconView.contentMode = .scaleAspectFit
        imageIconView.translatesAutoresizingMaskIntoConstraints = false
        mainContentStackView.addArrangedSubview(imageIconView)
        
        // 描述标签
        descriptionLabel.text = "选择要拼接的图片"
        descriptionLabel.font = UIFont.systemFont(ofSize: 16)
        descriptionLabel.textColor = .label
        descriptionLabel.textAlignment = .center
        descriptionLabel.translatesAutoresizingMaskIntoConstraints = false
        mainContentStackView.addArrangedSubview(descriptionLabel)
    }
    
    private func setupStartButton() {
        startButton.setTitle("开始拼接", for: .normal)
        startButton.setTitleColor(.white, for: .normal)
        startButton.backgroundColor = .systemBlue
        startButton.layer.cornerRadius = 8
        startButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        startButton.translatesAutoresizingMaskIntoConstraints = false
        startButton.addTarget(self, action: #selector(startButtonTapped), for: .touchUpInside)
        // 添加点击反馈动画
        startButton.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchDown)
        startButton.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        view.addSubview(startButton)
    }
    
    // MARK: - 约束设置
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // 标签栏
            tabStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            tabStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            tabStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),
            tabStackView.heightAnchor.constraint(equalToConstant: 32),
            
            // 标签指示器
            tabIndicatorView.topAnchor.constraint(equalTo: tabStackView.bottomAnchor),
            tabIndicatorView.heightAnchor.constraint(equalToConstant: 2),
            tabIndicatorView.widthAnchor.constraint(equalTo: tabStackView.widthAnchor, multiplier: 0.5),
            tabIndicatorView.leadingAnchor.constraint(equalTo: tabStackView.leadingAnchor),
            
            // 主体内容
            mainContentStackView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            mainContentStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            
            // 图片图标
            imageIconView.widthAnchor.constraint(equalToConstant: 80),
            imageIconView.heightAnchor.constraint(equalToConstant: 80),
            
            // 底部按钮
            startButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            startButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            startButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            startButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - 按钮点击事件
    @objc private func tabButtonTapped(_ sender: UIButton) {
        // 更新选中状态
        autoStitchButton.isSelected = sender == autoStitchButton
        manualStitchButton.isSelected = sender == manualStitchButton
        
        // 更新指示器位置
        UIView.animate(withDuration: 0.2) {
            if sender == self.autoStitchButton {
                self.tabIndicatorView.leadingAnchor.constraint(equalTo: self.tabStackView.leadingAnchor).isActive = true
                self.tabIndicatorView.leadingAnchor.constraint(equalTo: self.tabStackView.trailingAnchor, constant: -self.tabStackView.frame.width / 2).isActive = false
                self.selectedTabIndex = 0
            } else {
                self.tabIndicatorView.leadingAnchor.constraint(equalTo: self.tabStackView.leadingAnchor).isActive = false
                self.tabIndicatorView.leadingAnchor.constraint(equalTo: self.tabStackView.trailingAnchor, constant: -self.tabStackView.frame.width / 2).isActive = true
                self.selectedTabIndex = 1
            }
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func startButtonTapped() {
        // 根据选中的标签执行不同的操作
        if selectedTabIndex == 0 {
            // 自动拼接
            let autoStitchVC = AutoStitchViewController()
            navigationController?.pushViewController(autoStitchVC, animated: true)
        } else {
            // 手动拼接
            let manualStitchVC = ManualStitchViewController()
            navigationController?.pushViewController(manualStitchVC, animated: true)
        }
    }
    
    // MARK: - 按钮点击反馈
    @objc private func buttonTapped(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            sender.backgroundColor = .systemBlue.withAlphaComponent(0.8)
        }
    }
    
    @objc private func buttonReleased(_ sender: UIButton) {
        UIView.animate(withDuration: 0.1) {
            sender.transform = .identity
            sender.backgroundColor = .systemBlue
        }
    }
}
