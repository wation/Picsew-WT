import UIKit
import Photos
import AVFoundation
import ReplayKit

// 移除错误的导入，ViewModel是同一个target中的本地类

class VideoCaptureViewController: UIViewController {

    private var selectedTabIndex: Int = 0 // 0: 视频拼图, 1: 视频导入
    

    

    
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
        button.setTitle(NSLocalizedString("video_capture_mode", comment: "Video capture mode"), for: .normal)
        button.setImage(UIImage(systemName: "video.badge.plus"), for: .normal)
        button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        button.tag = 0
        applyButtonStyle(button, position: .left)
        return button
    }()
    
    private lazy var importVideoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("video_import_mode", comment: "Video import mode"), for: .normal)
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
        let alert = UIAlertController(title: NSLocalizedString("broadcast_screen", comment: "Broadcast screen"), message: NSLocalizedString("broadcast_stopped_message", comment: "Broadcast stopped message"), preferredStyle: .alert)
        
        // 添加"好"按钮，灰色
        let okAction = UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default) { _ in
            // 清除待处理的录屏文件
            BroadcastManager.shared.clearPendingRecording()
        }
        okAction.setValue(UIColor.gray, forKey: "titleTextColor")
        alert.addAction(okAction)
        
        // 添加"前往应用程序"按钮，蓝色
        let goToAppAction = UIAlertAction(title: NSLocalizedString("go_to_app", comment: "Go to app"), style: .default) { [weak self] _ in
            // 处理录屏文件并跳转到长截图页面
            self?.processRecordingAndNavigate()
        }
        goToAppAction.setValue(UIColor.blue, forKey: "titleTextColor")
        alert.addAction(goToAppAction)
        
        present(alert, animated: true)
    }
    
    private func processRecordingAndNavigate() {
        guard let recordingURL = BroadcastManager.shared.recordingFileURL else {
            showAlert(title: NSLocalizedString("processing_failed", comment: "Processing failed"), message: NSLocalizedString("failed_to_get_recording_file", comment: "Failed to get recording file"))
            return
        }
        
        // 显示加载指示器
        let loadingAlert = UIAlertController(title: NSLocalizedString("generating_long_screenshot", comment: "Generating long screenshot"), message: "", preferredStyle: .alert)
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
                    self?.showAlert(title: NSLocalizedString("processing_failed", comment: "Processing failed"), message: error.localizedDescription)
                    return
                }
                
                if let images = images, !images.isEmpty {
                    // 跳转到长截图页面
                    let autoStitchVC = AutoStitchViewController()
                    autoStitchVC.setInputImagesFromVideo(images)
                    self?.navigationController?.pushViewController(autoStitchVC, animated: true)
                } else {
                    self?.showAlert(title: NSLocalizedString("processing_failed", comment: "Processing failed"), message: NSLocalizedString("failed_to_extract_images_from_video", comment: "Failed to extract images from video"))
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
            tutorialContentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -20),
            
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
        titleLabel.text = NSLocalizedString("must_read_tutorial", comment: "Must read tutorial")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 20)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(titleLabel)
        
        var lastAnchor = titleLabel.bottomAnchor
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: tutorialContentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20)
        ])
        
        // 第一步：打开需要滚动截图的界面
        let step1Label = UILabel()
        step1Label.text = NSLocalizedString("tutorial_step_1", comment: "Tutorial step 1")
        step1Label.font = UIFont.systemFont(ofSize: 16)
        step1Label.numberOfLines = 0
        step1Label.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(step1Label)
        
        NSLayoutConstraint.activate([
            step1Label.topAnchor.constraint(equalTo: lastAnchor, constant: 20),
            step1Label.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            step1Label.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20)
        ])
        
        // 第一步下面不需要放图片，适当留一些空隙
        lastAnchor = step1Label.bottomAnchor
        
        // 第二步：下拉状态栏，并长按录屏按钮
        let step2Label = UILabel()
        step2Label.text = NSLocalizedString("tutorial_step_2", comment: "Tutorial step 2")
        step2Label.font = UIFont.systemFont(ofSize: 16)
        step2Label.numberOfLines = 0
        step2Label.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(step2Label)
        
        NSLayoutConstraint.activate([
            step2Label.topAnchor.constraint(equalTo: lastAnchor, constant: 30),
            step2Label.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            step2Label.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20)
        ])
        
        // 第二步下面放r1.png
        let step2ImageView = UIImageView()
        if let imageUrl = Bundle.main.url(forResource: "r1", withExtension: "png"), let image = UIImage(contentsOfFile: imageUrl.path) {
            step2ImageView.image = image
        }
        step2ImageView.layer.cornerRadius = 8
        step2ImageView.contentMode = .scaleAspectFit
        step2ImageView.clipsToBounds = true
        step2ImageView.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(step2ImageView)
        
        NSLayoutConstraint.activate([
            step2ImageView.topAnchor.constraint(equalTo: step2Label.bottomAnchor, constant: 10),
            step2ImageView.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            step2ImageView.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20),
            step2ImageView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        lastAnchor = step2ImageView.bottomAnchor
        
        // 第三步：选中本应用，并点击"开始直播"
        let step3Label = UILabel()
        step3Label.text = NSLocalizedString("tutorial_step_3", comment: "Tutorial step 3")
        step3Label.font = UIFont.systemFont(ofSize: 16)
        step3Label.numberOfLines = 0
        step3Label.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(step3Label)
        
        NSLayoutConstraint.activate([
            step3Label.topAnchor.constraint(equalTo: lastAnchor, constant: 30),
            step3Label.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            step3Label.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20)
        ])
        
        // 第三步下面放r2.png
        let step3ImageView = UIImageView()
        if let imageUrl = Bundle.main.url(forResource: "r2", withExtension: "png"), let image = UIImage(contentsOfFile: imageUrl.path) {
            step3ImageView.image = image
        }
        step3ImageView.layer.cornerRadius = 8
        step3ImageView.contentMode = .scaleAspectFit
        step3ImageView.clipsToBounds = true
        step3ImageView.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(step3ImageView)
        
        NSLayoutConstraint.activate([
            step3ImageView.topAnchor.constraint(equalTo: step3Label.bottomAnchor, constant: 10),
            step3ImageView.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            step3ImageView.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20),
            step3ImageView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        lastAnchor = step3ImageView.bottomAnchor
        
        // 第四步：关闭状态栏。。。
        let step4Label = UILabel()
        let step4Text = NSLocalizedString("tutorial_step_4", comment: "Tutorial step 4")
        
        // 将"单次滑动。。。"文字改为红色
        let attributedString = NSMutableAttributedString(string: step4Text)
        if let range = step4Text.range(of: "单次滑动请维持在3秒以上！连续滚动无需停顿！") {
            let nsRange = NSRange(range, in: step4Text)
            attributedString.addAttribute(.foregroundColor, value: UIColor.red, range: nsRange)
        }
        
        step4Label.attributedText = attributedString
        step4Label.font = UIFont.systemFont(ofSize: 16)
        step4Label.numberOfLines = 0
        step4Label.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(step4Label)
        
        NSLayoutConstraint.activate([
            step4Label.topAnchor.constraint(equalTo: lastAnchor, constant: 30),
            step4Label.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            step4Label.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20)
        ])
        
        // 第四步下面放r3.png
        let step4ImageView = UIImageView()
        if let imageUrl = Bundle.main.url(forResource: "r3", withExtension: "png"), let image = UIImage(contentsOfFile: imageUrl.path) {
            step4ImageView.image = image
        }
        step4ImageView.layer.cornerRadius = 8
        step4ImageView.contentMode = .scaleAspectFit
        step4ImageView.clipsToBounds = true
        step4ImageView.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(step4ImageView)
        
        NSLayoutConstraint.activate([
            step4ImageView.topAnchor.constraint(equalTo: step4Label.bottomAnchor, constant: 10),
            step4ImageView.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            step4ImageView.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20),
            step4ImageView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        lastAnchor = step4ImageView.bottomAnchor
        
        // 第五步：再次点击左上角。。。
        let step5Label = UILabel()
        step5Label.text = NSLocalizedString("tutorial_step_5", comment: "Tutorial step 5")
        step5Label.font = UIFont.systemFont(ofSize: 16)
        step5Label.numberOfLines = 0
        step5Label.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(step5Label)
        
        NSLayoutConstraint.activate([
            step5Label.topAnchor.constraint(equalTo: lastAnchor, constant: 30),
            step5Label.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            step5Label.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20)
        ])
        
        // 第五步下面放r4.png
        let step5ImageView = UIImageView()
        if let imageUrl = Bundle.main.url(forResource: "r4", withExtension: "png"), let image = UIImage(contentsOfFile: imageUrl.path) {
            step5ImageView.image = image
        }
        step5ImageView.layer.cornerRadius = 8
        step5ImageView.contentMode = .scaleAspectFit
        step5ImageView.clipsToBounds = true
        step5ImageView.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(step5ImageView)
        
        NSLayoutConstraint.activate([
            step5ImageView.topAnchor.constraint(equalTo: step5Label.bottomAnchor, constant: 10),
            step5ImageView.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            step5ImageView.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20),
            step5ImageView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        lastAnchor = step5ImageView.bottomAnchor
        
        // 第六步：新增步骤
        let step6Label = UILabel()
        // 读取设置页面中自动停止时长的值
        let stopDurationStr = UserDefaults.standard.string(forKey: "stopDuration") ?? "two_seconds"
        let stopDuration = StopDuration(rawValue: stopDurationStr) ?? .twoSeconds
        let localizedDuration = stopDuration.localizedString
        let step6Text = String(format: "6. 如果%@后未操作，录屏会自动结束，请点击'前往应用程序'按钮，将可以看到自动拼接好的长截图", localizedDuration)
        step6Label.text = step6Text
        step6Label.font = UIFont.systemFont(ofSize: 16)
        step6Label.numberOfLines = 0
        step6Label.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(step6Label)
        
        NSLayoutConstraint.activate([
            step6Label.topAnchor.constraint(equalTo: lastAnchor, constant: 30),
            step6Label.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            step6Label.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20)
        ])
        
        // 第六步下面放r5.png
        let step6ImageView = UIImageView()
        if let imageUrl = Bundle.main.url(forResource: "r5", withExtension: "png"), let image = UIImage(contentsOfFile: imageUrl.path) {
            step6ImageView.image = image
        }
        step6ImageView.layer.cornerRadius = 8
        step6ImageView.contentMode = .scaleAspectFit
        step6ImageView.clipsToBounds = true
        step6ImageView.translatesAutoresizingMaskIntoConstraints = false
        tutorialContentView.addSubview(step6ImageView)
        
        NSLayoutConstraint.activate([
            step6ImageView.topAnchor.constraint(equalTo: step6Label.bottomAnchor, constant: 10),
            step6ImageView.leadingAnchor.constraint(equalTo: tutorialContentView.leadingAnchor, constant: 20),
            step6ImageView.trailingAnchor.constraint(equalTo: tutorialContentView.trailingAnchor, constant: -20),
            step6ImageView.heightAnchor.constraint(equalToConstant: 200)
        ])
        
        lastAnchor = step6ImageView.bottomAnchor
        
        // 设置底部约束
        NSLayoutConstraint.activate([
            lastAnchor.constraint(equalTo: tutorialContentView.bottomAnchor, constant: 20)
        ])
    }
    
    @objc private func tabTapped(_ sender: UIButton) {
        selectedTabIndex = sender.tag
        updateTabUI()
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
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default))
        present(alert, animated: true)
    }

    private func handleVideoSelection(_ asset: PHAsset) {
        let loadingAlert = UIAlertController(title: NSLocalizedString("analyzing_video", comment: "Analyzing video"), message: "\n\n", preferredStyle: .alert)
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
                    self?.showAlert(title: NSLocalizedString("processing_failed", comment: "Processing failed"), message: error.localizedDescription)
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
        
        let alert = UIAlertController(title: NSLocalizedString("import_confirmation", comment: "Import confirmation"), message: NSLocalizedString("confirm_import_video", comment: "Confirm import video"), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("cancel", comment: "Cancel"), style: .cancel))
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default, handler: { [weak self] _ in
            self?.handleVideoSelection(asset)
        }))
        present(alert, animated: true)
    }
}
