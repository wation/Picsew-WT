import UIKit

class VideoCaptureViewController: UIViewController {

    private var selectedTabIndex: Int = 0 // 0: 实时录屏, 1: 导入视频
    private var isRecording: Bool = false
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("app_name", comment: "应用名称")
        label.font = UIFont.boldSystemFont(ofSize: 18)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var tabStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private lazy var liveRecordTab: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("video_capture", comment: "实时录屏"), for: .normal)
        button.setImage(UIImage(systemName: "camera"), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        button.contentHorizontalAlignment = .center
        button.backgroundColor = .white
        button.setTitleColor(.black, for: .normal)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        button.tag = 0
        return button
    }()
    
    private lazy var importVideoTab: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("import_video", comment: "导入视频"), for: .normal)
        button.setImage(UIImage(systemName: "arrow.up.to.line"), for: .normal)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: -8)
        button.contentHorizontalAlignment = .center
        button.backgroundColor = .lightGray
        button.setTitleColor(.gray, for: .normal)
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        button.tag = 1
        return button
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 12
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor.lightGray.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var cameraIconView: UIImageView = {
        let imageView = UIImageView(image: UIImage(systemName: "camera"))
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    private lazy var startRecordLabel: UILabel = {
        let label = UILabel()
        label.text = "开始录屏"
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .gray
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var startRecordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("开始录屏", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(startRecordTapped), for: .touchUpInside)
        // 添加点击反馈动画
        button.addTarget(self, action: #selector(buttonTapped(_:)), for: .touchDown)
        button.addTarget(self, action: #selector(buttonReleased(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray6
        setupUI()
        checkPermission()
    }
    
    private func setupUI() {
        // 添加子视图
        view.addSubview(titleLabel)
        view.addSubview(tabStackView)
        view.addSubview(contentView)
        
        tabStackView.addArrangedSubview(liveRecordTab)
        tabStackView.addArrangedSubview(importVideoTab)
        
        contentView.addSubview(cameraIconView)
        contentView.addSubview(startRecordLabel)
        contentView.addSubview(startRecordButton)
        
        // 设置约束
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            
            // 标签栏
            tabStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 20),
            tabStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            tabStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            tabStackView.heightAnchor.constraint(equalToConstant: 44),
            
            // 内容视图
            contentView.topAnchor.constraint(equalTo: tabStackView.bottomAnchor, constant: 20),
            contentView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            contentView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            contentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            // 相机图标
            cameraIconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            cameraIconView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor, constant: -60),
            cameraIconView.widthAnchor.constraint(equalToConstant: 80),
            cameraIconView.heightAnchor.constraint(equalToConstant: 80),
            
            // 开始录屏文字
            startRecordLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            startRecordLabel.topAnchor.constraint(equalTo: cameraIconView.bottomAnchor, constant: 16),
            
            // 开始录屏按钮
            startRecordButton.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            startRecordButton.topAnchor.constraint(equalTo: startRecordLabel.bottomAnchor, constant: 32),
            startRecordButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 40),
            startRecordButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -40),
            startRecordButton.heightAnchor.constraint(equalToConstant: 48)
        ])
    }
    
    private func checkPermission() {
        if selectedTabIndex == 0 {
            VideoCaptureManager.shared.checkScreenRecordingPermission { [weak self] hasPermission in
                DispatchQueue.main.async {
                    if !hasPermission {
                        self?.startRecordButton.isEnabled = false
                        self?.startRecordLabel.text = "屏幕录制不可用"
                    }
                }
            }
        } else {
            VideoImporter.shared.checkPhotoLibraryPermission { [weak self] hasPermission in
                DispatchQueue.main.async {
                    if !hasPermission {
                        self?.startRecordButton.isEnabled = false
                        self?.startRecordLabel.text = "相册访问被拒绝"
                    }
                }
            }
        }
    }
    
    @objc private func tabTapped(_ sender: UIButton) {
        selectedTabIndex = sender.tag
        updateTabUI()
        checkPermission()
    }
    
    private func updateTabUI() {
        if selectedTabIndex == 0 {
            liveRecordTab.backgroundColor = .white
            liveRecordTab.setTitleColor(.black, for: .normal)
            importVideoTab.backgroundColor = .lightGray
            importVideoTab.setTitleColor(.gray, for: .normal)
            // 更新内容视图为实时录屏界面
            updateContentForLiveRecord()
        } else {
            liveRecordTab.backgroundColor = .lightGray
            liveRecordTab.setTitleColor(.gray, for: .normal)
            importVideoTab.backgroundColor = .white
            importVideoTab.setTitleColor(.black, for: .normal)
            // 更新内容视图为导入视频界面
            updateContentForImportVideo()
        }
    }
    
    private func updateContentForLiveRecord() {
        cameraIconView.image = UIImage(systemName: "camera")
        startRecordLabel.text = isRecording ? "录制中..." : "开始录屏"
        startRecordButton.setTitle(isRecording ? "停止录屏" : "开始录屏", for: .normal)
        startRecordButton.isEnabled = true
    }
    
    private func updateContentForImportVideo() {
        cameraIconView.image = UIImage(systemName: "arrow.up.to.line")
        startRecordLabel.text = "选择视频"
        startRecordButton.setTitle("导入视频", for: .normal)
        startRecordButton.isEnabled = true
    }
    
    @objc private func startRecordTapped() {
        if selectedTabIndex == 0 {
            if isRecording {
                stopRecording()
            } else {
                startRecording()
            }
        } else {
            importVideo()
        }
    }
    
    private func startRecording() {
        VideoCaptureManager.shared.startRecording { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "错误", message: error.localizedDescription)
                } else {
                    self?.isRecording = true
                    self?.updateContentForLiveRecord()
                }
            }
        }
    }
    
    private func stopRecording() {
        VideoCaptureManager.shared.stopRecording { [weak self] videoURL, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "错误", message: error.localizedDescription)
                } else if let videoURL = videoURL {
                    self?.isRecording = false
                    self?.updateContentForLiveRecord()
                    self?.showAlert(title: "成功", message: "视频已保存到: \(videoURL.lastPathComponent)")
                }
            }
        }
    }
    
    private func importVideo() {
        VideoImporter.shared.openVideoPicker(from: self) { [weak self] videoURL, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "错误", message: error.localizedDescription)
                } else if let videoURL = videoURL {
                    // 提取视频帧
                    self?.extractFrames(from: videoURL)
                }
            }
        }
    }
    
    private func extractFrames(from videoURL: URL) {
        startRecordLabel.text = "提取帧中..."
        startRecordButton.isEnabled = false
        
        VideoImporter.shared.extractFrames(from: videoURL) { [weak self] frames, error in
            DispatchQueue.main.async {
                self?.startRecordButton.isEnabled = true
                
                if let error = error {
                    self?.showAlert(title: "错误", message: error.localizedDescription)
                    self?.updateContentForImportVideo()
                } else {
                    self?.showAlert(title: "成功", message: "提取了 \(frames.count) 帧")
                    self?.updateContentForImportVideo()
                }
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
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
