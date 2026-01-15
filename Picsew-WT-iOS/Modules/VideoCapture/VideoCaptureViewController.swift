import UIKit
import Photos
import AVFoundation
import ReplayKit

// 移除错误的导入，ViewModel是同一个target中的本地类

class VideoCaptureViewController: UIViewController {

    private var selectedTabIndex: Int = 0 // 0: 视频拼图, 1: 视频导入
    
    // 添加ViewModel实例
    private let viewModel = VideoCaptureViewModel()
    
    // 录制状态显示
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = viewModel.statusMessage
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    // 开始录制按钮
    private lazy var startRecordingButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("开始录制", for: .normal)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(startRecordingTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    // 停止录制按钮
    private lazy var stopRecordingButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("停止录制", for: .normal)
        button.backgroundColor = .systemRed
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 10
        button.isEnabled = false
        button.addTarget(self, action: #selector(stopRecordingTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var topActionBar: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.layer.cornerRadius = 10
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var liveRecordButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("视频拼图", for: .normal)
        button.setImage(UIImage(systemName: "video.badge.plus"), for: .normal)
        button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        button.tag = 0
        applyButtonStyle(button, position: .left)
        return button
    }()
    
    private lazy var importVideoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("视频导入", for: .normal)
        button.setImage(UIImage(systemName: "arrow.up.to.line"), for: .normal)
        button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        button.tag = 1
        applyButtonStyle(button, position: .right)
        return button
    }()
    
    enum ButtonPosition {
        case left, right
    }
    
    private func applyButtonStyle(_ button: UIButton, position: ButtonPosition) {
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.tintColor = .systemBlue
        
        let cornerRadius: CGFloat = 10
        if #available(iOS 11.0, *) {
            button.layer.cornerRadius = cornerRadius
            switch position {
            case .left:
                button.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            case .right:
                button.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            }
        } else {
            button.layer.cornerRadius = cornerRadius
        }
        
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.imagePlacement = .top
            config.imagePadding = 5
            button.configuration = config
        } else {
            button.imageEdgeInsets = UIEdgeInsets(top: -10, left: 0, bottom: 0, right: 0)
            button.titleEdgeInsets = UIEdgeInsets(top: 30, left: -20, bottom: 0, right: 0)
        }
    }
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = .white
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var tutorialContentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var importContentView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var videoCollectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let margin: CGFloat = 16
        let spacing: CGFloat = 12
        let totalSpacing = (margin * 2) + (spacing * 2)
        let width = (UIScreen.main.bounds.width - totalSpacing) / 3
        
        layout.itemSize = CGSize(width: width, height: width)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: margin, left: margin, bottom: 20, right: margin)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .systemGray6
        cv.register(VideoCell.self, forCellWithReuseIdentifier: "VideoCell")
        cv.delegate = self
        cv.dataSource = self
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()
    
    private var videoAssets: [PHAsset] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        setupUI()
        setupNavigationBar()
        updateTabUI()
        loadVideos()
        
        // 设置BroadcastManager的观察者
        setupBroadcastObserver()
    }
    
    private func setupBroadcastObserver() {
        BroadcastManager.shared.startObserving { [weak self] in
            DispatchQueue.main.async {
                // 检查是否有待处理的录屏文件
                if BroadcastManager.shared.hasPendingRecording() {
                    self?.showRecordingFinishedAlert()
                }
            }
        }
    }
    
    private func showRecordingFinishedAlert() {
        let alert = UIAlertController(title: "直播屏幕", message: "PicsewAI的直播已停止，因为：滚动截图已生成，请打开 App 以继续。", preferredStyle: .alert)
        
        // 添加"好"按钮，灰色
        let okAction = UIAlertAction(title: "好", style: .default) { _ in
            // 清除待处理的录屏文件
            BroadcastManager.shared.clearPendingRecording()
        }
        okAction.setValue(UIColor.gray, forKey: "titleTextColor")
        alert.addAction(okAction)
        
        // 添加"前往应用程序"按钮，蓝色
        let goToAppAction = UIAlertAction(title: "前往应用程序", style: .default) { [weak self] _ in
            // 处理录屏文件并跳转到长截图页面
            self?.processRecordingAndNavigate()
        }
        goToAppAction.setValue(UIColor.blue, forKey: "titleTextColor")
        alert.addAction(goToAppAction)
        
        present(alert, animated: true)
    }
    
    private func processRecordingAndNavigate() {
        guard let recordingURL = BroadcastManager.shared.recordingFileURL else {
            showAlert(title: "处理失败", message: "无法获取录屏文件")
            return
        }
        
        // 显示加载指示器
        let loadingAlert = UIAlertController(title: "正在生成长截图", message: "", preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        loadingAlert.view.addSubview(indicator)
        
        // 设置对话框高度为屏幕高度的1/6，进一步减小高度
        let screenHeight = UIScreen.main.bounds.height
        let alertHeight = screenHeight / 6
        
        NSLayoutConstraint.activate([
            // 设置对话框高度
            loadingAlert.view.heightAnchor.constraint(equalToConstant: alertHeight),
            
            // 指示器居中
            indicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
            indicator.centerYAnchor.constraint(equalTo: loadingAlert.view.centerYAnchor),
            
            // 标题栏离顶部距离加大，增加顶部内边距到30
            loadingAlert.view.layoutMarginsGuide.topAnchor.constraint(greaterThanOrEqualTo: loadingAlert.view.topAnchor, constant: 30)
        ])
        indicator.startAnimating()
        
        present(loadingAlert, animated: true)
        
        // 处理录屏文件
        VideoStitcher.shared.processVideo(url: recordingURL) { [weak self] images, error in
            loadingAlert.dismiss(animated: true) { [weak self] in
                // 清除待处理的录屏文件
                BroadcastManager.shared.clearPendingRecording()
                
                if let error = error {
                    self?.showAlert(title: "处理失败", message: error.localizedDescription)
                    return
                }
                
                if let images = images, !images.isEmpty {
                    // 跳转到长截图页面
                    let autoStitchVC = AutoStitchViewController()
                    autoStitchVC.setInputImagesFromVideo(images)
                    self?.navigationController?.pushViewController(autoStitchVC, animated: true)
                } else {
                    self?.showAlert(title: "处理失败", message: "无法从视频中提取图像")
                }
            }
        }
    }
    
    private func setupNavigationBar() {
        title = NSLocalizedString("video_capture", comment: "")
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            appearance.shadowColor = UIColor(white: 0, alpha: 0.1)
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    private func setupUI() {
        view.addSubview(topActionBar)
        view.addSubview(scrollView)
        view.addSubview(importContentView)
        
        scrollView.addSubview(tutorialContentView)
        scrollView.addSubview(statusLabel)
        scrollView.addSubview(startRecordingButton)
        scrollView.addSubview(stopRecordingButton)
        
        importContentView.addSubview(videoCollectionView)
        
        let stackView = UIStackView(arrangedSubviews: [liveRecordButton, importVideoButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = -1.0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        topActionBar.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            topActionBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            topActionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            topActionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            topActionBar.heightAnchor.constraint(equalToConstant: 60),
            
            stackView.topAnchor.constraint(equalTo: topActionBar.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: topActionBar.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: topActionBar.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: topActionBar.bottomAnchor),
            
            scrollView.topAnchor.constraint(equalTo: topActionBar.bottomAnchor, constant: 10),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            tutorialContentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            tutorialContentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            tutorialContentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            tutorialContentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            statusLabel.topAnchor.constraint(equalTo: tutorialContentView.bottomAnchor, constant: 30),
            statusLabel.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -20),
            
            startRecordingButton.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 20),
            startRecordingButton.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            startRecordingButton.widthAnchor.constraint(equalToConstant: 200),
            startRecordingButton.heightAnchor.constraint(equalToConstant: 50),
            
            stopRecordingButton.topAnchor.constraint(equalTo: startRecordingButton.bottomAnchor, constant: 20),
            stopRecordingButton.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            stopRecordingButton.widthAnchor.constraint(equalToConstant: 200),
            stopRecordingButton.heightAnchor.constraint(equalToConstant: 50),
            stopRecordingButton.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            
            importContentView.topAnchor.constraint(equalTo: topActionBar.bottomAnchor, constant: 10),
            importContentView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            importContentView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            importContentView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            
            videoCollectionView.topAnchor.constraint(equalTo: importContentView.topAnchor),
            videoCollectionView.leadingAnchor.constraint(equalTo: importContentView.leadingAnchor),
            videoCollectionView.trailingAnchor.constraint(equalTo: importContentView.trailingAnchor),
            videoCollectionView.bottomAnchor.constraint(equalTo: importContentView.bottomAnchor)
        ])
        
        setupTutorialContent()
    }
    
    private func loadVideos() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            if status == .authorized {
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                let fetchResult = PHAsset.fetchAssets(with: .video, options: options)
                
                var assets: [PHAsset] = []
                fetchResult.enumerateObjects { (asset, _, _) in
                    assets.append(asset)
                }
                
                DispatchQueue.main.async {
                    self?.videoAssets = assets
                    self?.videoCollectionView.reloadData()
                }
            }
        }
    }
    
    private func setupTutorialContent() {
        let titleLabel = UILabel()
        titleLabel.text = "必看使用教程："
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(titleLabel)
        
        let steps = [
            "1. 打开需要滚动截图的界面",
            "2. 状态栏下拉，并长按录屏按钮",
            "3. 选中本应用，并点击“开始直播”",
            "4. 关闭状态栏并切回界面，待左上角出现录屏标记后，开始缓慢向下滑动\n\n单次滑动请维持在3秒以上！连续滚动无需停顿！",
            "5. 再次点击左上角，结束录屏，并回到本应用即可看到截好的长图"
        ]
        
        var lastAnchor = titleLabel.bottomAnchor
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: tutorialContentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20)
        ])
        
        for (index, stepText) in steps.enumerated() {
            let label = UILabel()
            label.text = stepText
            label.font = UIFont.systemFont(ofSize: 16)
            label.numberOfLines = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            tutorialContentView.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: lastAnchor, constant: 20),
                label.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20)
            ])
            
            // 添加一个占位图片视图，代表截图中的图片
            let imageView = UIImageView()
            imageView.backgroundColor = UIColor.systemGray6
            imageView.layer.cornerRadius = 8
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            tutorialContentView.addSubview(imageView)
            
            // 根据索引设置占位文字或图标，模拟截图内容
            let placeholderLabel = UILabel()
            placeholderLabel.text = "步骤 \(index + 1) 示意图"
            placeholderLabel.textColor = .lightGray
            placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
            imageView.addSubview(placeholderLabel)
            
            NSLayoutConstraint.activate([
                imageView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 10),
                imageView.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
                imageView.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20),
                imageView.heightAnchor.constraint(equalToConstant: 200),
                
                placeholderLabel.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
                placeholderLabel.centerYAnchor.constraint(equalTo: imageView.centerYAnchor)
            ])
            
            lastAnchor = imageView.bottomAnchor
        }
        
        NSLayoutConstraint.activate([
            lastAnchor.constraint(equalTo: tutorialContentView.bottomAnchor, constant: 20)
        ])
    }
    
    @objc private func tabTapped(_ sender: UIButton) {
        selectedTabIndex = sender.tag
        updateTabUI()
    }
    
    // MARK: - 录制控制方法
    
    @objc private func startRecordingTapped() {
        // 检查权限
        viewModel.checkPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    // 开始录制
                    self?.viewModel.startRecording { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self?.showAlert(title: "录制失败", message: error.localizedDescription)
                            } else {
                                self?.updateRecordingUI()
                            }
                        }
                    }
                } else {
                    self?.showAlert(title: "权限被拒绝", message: "请在设置中允许应用访问屏幕录制权限")
                }
            }
        }
    }
    
    @objc private func stopRecordingTapped() {
        // 停止录制
        viewModel.stopRecording { [weak self] videoURL, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.showAlert(title: "停止录制失败", message: error.localizedDescription)
                } else if let videoURL = videoURL {
                    self?.statusLabel.text = "录制已保存: \(videoURL.lastPathComponent)"
                    self?.updateRecordingUI()
                    
                    // 显示录制完成提示
                    self?.showAlert(title: "录制完成", message: "视频已保存到: \(videoURL)")
                }
            }
        }
    }
    
    private func updateRecordingUI() {
        statusLabel.text = viewModel.statusMessage
        startRecordingButton.isEnabled = !viewModel.isRecording
        stopRecordingButton.isEnabled = viewModel.isRecording
    }
    
    private func updateTabUI() {
        if selectedTabIndex == 0 {
            liveRecordButton.backgroundColor = .white
            liveRecordButton.alpha = 1.0
            importVideoButton.backgroundColor = .systemGray6
            importVideoButton.alpha = 0.5
            scrollView.isHidden = false
            importContentView.isHidden = true
        } else {
            liveRecordButton.backgroundColor = .systemGray6
            liveRecordButton.alpha = 0.5
            importVideoButton.backgroundColor = .white
            importVideoButton.alpha = 1.0
            scrollView.isHidden = true
            importContentView.isHidden = false
        }
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }

    private func handleVideoSelection(_ asset: PHAsset) {
        let loadingAlert = UIAlertController(title: "正在分析视频", message: "\n\n", preferredStyle: .alert)
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        loadingAlert.view.addSubview(indicator)
        
        // 设置对话框高度为屏幕高度的1/6，进一步减小高度
        let screenHeight = UIScreen.main.bounds.height
        let alertHeight = screenHeight / 6
        
        NSLayoutConstraint.activate([
            // 设置对话框高度
            loadingAlert.view.heightAnchor.constraint(equalToConstant: alertHeight),
            
            // 指示器居中
            indicator.centerXAnchor.constraint(equalTo: loadingAlert.view.centerXAnchor),
            //indicator.centerYAnchor.constraint(equalTo: loadingAlert.view.centerYAnchor),
            indicator.bottomAnchor.constraint(equalTo: loadingAlert.view.bottomAnchor, constant: -50),
            
            // 标题栏离顶部距离加大，增加顶部内边距到30
            loadingAlert.view.layoutMarginsGuide.topAnchor.constraint(greaterThanOrEqualTo: loadingAlert.view.topAnchor, constant: 30)
        ])
        indicator.startAnimating()
        
        present(loadingAlert, animated: true)
        
        VideoStitcher.shared.processVideo(asset: asset) { [weak self] images, error in
            loadingAlert.dismiss(animated: true) {
                if let error = error {
                    self?.showAlert(title: "处理失败", message: error.localizedDescription)
                    return
                }
                
                if let images = images, !images.isEmpty {
                    let autoStitchVC = AutoStitchViewController()
                    autoStitchVC.setInputImagesFromVideo(images)
                    self?.navigationController?.pushViewController(autoStitchVC, animated: true)
                }
            }
        }
    }
}

// MARK: - UICollectionViewDelegate, UICollectionViewDataSource
extension VideoCaptureViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return videoAssets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "VideoCell", for: indexPath) as! VideoCell
        let asset = videoAssets[indexPath.item]
        cell.configure(with: asset)
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let asset = videoAssets[indexPath.item]
        
        let alert = UIAlertController(title: "导入确认", message: "确定要导入选中的视频进行分析吗？", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        alert.addAction(UIAlertAction(title: "确定", style: .default, handler: { [weak self] _ in
            self?.handleVideoSelection(asset)
        }))
        present(alert, animated: true)
    }
}
