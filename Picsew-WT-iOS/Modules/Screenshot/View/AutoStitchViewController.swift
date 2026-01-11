import UIKit
import PhotosUI

class AutoStitchViewController: UIViewController {
    
    private let viewModel = AutoStitchViewModel()
    private var imageViews: [UIImageView] = []
    private var adjustmentViews: [StitchAdjustmentView] = []
    private var currentOffsets: [CGFloat] = []
    private var topCrop: CGFloat = 0 // 第一张图片的顶部裁剪 (显示坐标)
    private var bottomCrop: CGFloat = 0 // 最后一张图片的底部裁剪 (显示坐标)
    
    // MARK: - UI Components
    
    private lazy var topNavigationBar: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var backButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "chevron.left"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var segmentControl: UISegmentedControl = {
        let items = ["裁剪", "工具"]
        let sc = UISegmentedControl(items: items)
        sc.selectedSegmentIndex = 0
        sc.translatesAutoresizingMaskIntoConstraints = false
        return sc
    }()
    
    private lazy var shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var contentStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.distribution = .fill
        stack.alignment = .fill
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var bottomToolbar: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        // 添加底部工具图标 (占位)
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .equalSpacing
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        let icons = ["line.3.horizontal", "crop", "aspectratio", "slider.horizontal.3"]
        for icon in icons {
            let btn = UIButton(type: .system)
            btn.setImage(UIImage(systemName: icon), for: .normal)
            btn.tintColor = .systemBlue
            stackView.addArrangedSubview(btn)
        }
        
        view.addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),
            stackView.topAnchor.constraint(equalTo: view.topAnchor, constant: 10),
            stackView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        ])
        
        return view
    }()
    
    private let loadingIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .large)
        indicator.hidesWhenStopped = true
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    // MARK: - Lifecycle
    
    init() {
        super.init(nibName: nil, bundle: nil)
        self.hidesBottomBarWhenPushed = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        startAutoStitch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    func setInputImages(_ images: [UIImage]) {
        viewModel.setImages(images)
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(topNavigationBar)
        topNavigationBar.addSubview(backButton)
        topNavigationBar.addSubview(segmentControl)
        topNavigationBar.addSubview(shareButton)
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        view.addSubview(bottomToolbar)
        view.addSubview(loadingIndicator)
        
        NSLayoutConstraint.activate([
            topNavigationBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            topNavigationBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topNavigationBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topNavigationBar.heightAnchor.constraint(equalToConstant: 44),
            
            backButton.leadingAnchor.constraint(equalTo: topNavigationBar.leadingAnchor, constant: 16),
            backButton.centerYAnchor.constraint(equalTo: topNavigationBar.centerYAnchor),
            
            segmentControl.centerXAnchor.constraint(equalTo: topNavigationBar.centerXAnchor),
            segmentControl.centerYAnchor.constraint(equalTo: topNavigationBar.centerYAnchor),
            
            shareButton.trailingAnchor.constraint(equalTo: topNavigationBar.trailingAnchor, constant: -16),
            shareButton.centerYAnchor.constraint(equalTo: topNavigationBar.centerYAnchor),
            
            scrollView.topAnchor.constraint(equalTo: topNavigationBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            bottomToolbar.heightAnchor.constraint(equalToConstant: 60),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    private func startAutoStitch() {
        loadingIndicator.startAnimating()
        viewModel.autoStitch { [weak self] stitchedImage, offsets, error in
            self?.loadingIndicator.stopAnimating()
            if let error = error {
                let nsError = error as NSError
                if nsError.domain == "StitchWarning" {
                    // 警告：找不到重合点，但仍然显示结果
                    print("AutoStitch: Warning - No overlap found for some images")
                    if let offsets = offsets {
                        self?.currentOffsets = offsets
                        self?.setupImageDisplay()
                        // 可选：提示用户部分图片未找到重合点
                        self?.showWarningTip(nsError.localizedDescription)
                    }
                } else {
                    // 真正的错误
                    self?.showError(error.localizedDescription)
                }
            } else if let _ = stitchedImage, let offsets = offsets {
                self?.currentOffsets = offsets
                self?.setupImageDisplay()
            }
        }
    }
    
    private var imageViewTopConstraints: [NSLayoutConstraint] = []
    private var imageViewHeightConstraints: [NSLayoutConstraint] = []
    private var firstImageTopConstraint: NSLayoutConstraint? // 第一个容器相对于 contentView 的 top
    private var firstImageViewTopConstraint: NSLayoutConstraint? // 第一张图片相对于第一个容器的 top
    private var firstImageHeightConstraint: NSLayoutConstraint? // 第一个容器的高度
    private var lastImageHeightConstraint: NSLayoutConstraint? // 最后一个容器的高度

    private func setupImageDisplay() {
        let images = viewModel.images
        guard !images.isEmpty else {
            print("AutoStitch: No images to display")
            return
        }
        
        guard currentOffsets.count == images.count else {
            print("AutoStitch: Offsets count (\(currentOffsets.count)) does not match images count (\(images.count))")
            return
        }
        
        // 确保视图已布局以获取正确的宽度
        view.layoutIfNeeded()
        
        // 清除旧视图
        contentView.subviews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        adjustmentViews.removeAll()
        imageViewTopConstraints.removeAll()
        imageViewHeightConstraints.removeAll()
        
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        contentView.backgroundColor = .white
        
        print("AutoStitch: Setup display with width: \(containerWidth), images: \(images.count)")
        
        for (index, image) in images.enumerated() {
            // 容器视图，负责裁剪
            let container = UIView()
            container.clipsToBounds = true
            container.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(container)
            
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFill
            imageView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(imageView)
            imageViews.append(imageView)
            
            let aspectRatio = image.size.height / image.size.width
            let displayHeight = containerWidth * aspectRatio
            
            // 将图片坐标转换为显示坐标
            let displayScale = containerWidth / image.size.width
            let yPosition = currentOffsets[index] * displayScale
            
            // 容器的约束
            let topOffset = (index == 0) ? topCrop : 0
            let bottomOffset = (index == images.count - 1) ? bottomCrop : 0
            
            let topConstraint = container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: yPosition + topOffset)
            let heightConstraint = container.heightAnchor.constraint(equalToConstant: displayHeight - topOffset - bottomOffset)
            
            imageViewTopConstraints.append(topConstraint)
            imageViewHeightConstraints.append(heightConstraint)
            
            let imgTopConstraint = imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: -topOffset)
            
            if index == 0 {
                firstImageTopConstraint = topConstraint
                firstImageViewTopConstraint = imgTopConstraint
                firstImageHeightConstraint = heightConstraint
            }
            if index == images.count - 1 {
                lastImageHeightConstraint = heightConstraint
            }
            
            NSLayoutConstraint.activate([
                topConstraint,
                container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                heightConstraint,
                
                // 图片在容器内的约束
                imgTopConstraint,
                imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                imageView.heightAnchor.constraint(equalToConstant: displayHeight)
            ])
            
            // 添加调整气泡
            if index > 0 {
                let adjustmentView = StitchAdjustmentView(type: .middle)
                adjustmentView.onAdjust = { [weak self] deltaY in
                    self?.adjustOffset(at: index, deltaY: deltaY)
                }
                contentView.addSubview(adjustmentView)
                adjustmentViews.append(adjustmentView)
                
                NSLayoutConstraint.activate([
                    adjustmentView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                    adjustmentView.centerYAnchor.constraint(equalTo: container.topAnchor),
                    adjustmentView.widthAnchor.constraint(equalToConstant: 60),
                    adjustmentView.heightAnchor.constraint(equalToConstant: 30)
                ])
            } else {
                // 第一张图顶部的裁剪气泡
                let topAdjustment = StitchAdjustmentView(type: .top)
                topAdjustment.onAdjust = { [weak self] deltaY in
                    self?.adjustTopCrop(deltaY: deltaY)
                }
                contentView.addSubview(topAdjustment)
                adjustmentViews.append(topAdjustment)
                NSLayoutConstraint.activate([
                    topAdjustment.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                    topAdjustment.bottomAnchor.constraint(equalTo: container.topAnchor, constant: 15),
                    topAdjustment.widthAnchor.constraint(equalToConstant: 60),
                    topAdjustment.heightAnchor.constraint(equalToConstant: 30)
                ])
            }
        }
        
        // 最后一张图底部的裁剪气泡
        if let lastContainer = contentView.subviews.filter({ $0.clipsToBounds }).last {
            let bottomAdjustment = StitchAdjustmentView(type: .bottom)
            bottomAdjustment.onAdjust = { [weak self] deltaY in
                self?.adjustBottomCrop(deltaY: deltaY)
            }
            contentView.addSubview(bottomAdjustment)
            adjustmentViews.append(bottomAdjustment)
            NSLayoutConstraint.activate([
                bottomAdjustment.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                bottomAdjustment.topAnchor.constraint(equalTo: lastContainer.bottomAnchor, constant: -15),
                bottomAdjustment.widthAnchor.constraint(equalToConstant: 60),
                bottomAdjustment.heightAnchor.constraint(equalToConstant: 30),
                bottomAdjustment.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
            ])
        }
        
        // 强制布局更新以确保 ScrollView 内容大小正确
        contentView.layoutIfNeeded()
        print("AutoStitch: ContentView height: \(contentView.frame.height)")
    }
    
    private func adjustOffset(at index: Int, deltaY: CGFloat) {
        guard index > 0 && index < imageViewTopConstraints.count else { return }
        
        // 更新约束 (现在是 container 的 top 约束)
        imageViewTopConstraints[index].constant += deltaY
        
        // 更新 currentOffsets 数据 (用于最终合成)
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let image = viewModel.images[index]
        let displayScale = containerWidth / image.size.width
        let imageDeltaY = deltaY / displayScale
        
        for i in index..<currentOffsets.count {
            currentOffsets[i] += imageDeltaY
        }
        
        view.layoutIfNeeded()
    }
    
    private func adjustTopCrop(deltaY: CGFloat) {
        let newTopCrop = max(0, topCrop + deltaY)
        
        // 限制不能裁剪超过第一张图片的高度 (留至少10像素)
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let firstImage = viewModel.images.first
        let firstImageDisplayHeight = (firstImage?.size.height ?? 0) * (containerWidth / (firstImage?.size.width ?? 1))
        
        if firstImageDisplayHeight > 0 && newTopCrop >= firstImageDisplayHeight - 10 {
            return
        }
        
        let diff = newTopCrop - topCrop
        topCrop = newTopCrop
        
        // 更新第一个容器的 top 和 height，以及图片的 top
        firstImageTopConstraint?.constant += diff
        firstImageViewTopConstraint?.constant -= diff
        firstImageHeightConstraint?.constant -= diff
        
        view.layoutIfNeeded()
    }
    
    private func adjustBottomCrop(deltaY: CGFloat) {
        // 向上拖拽 (deltaY < 0) 增加裁剪量
        let newBottomCrop = max(0, bottomCrop - deltaY)
        
        // 限制不能裁剪超过最后一张图片的高度
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let lastImage = viewModel.images.last
        let lastImageDisplayHeight = (lastImage?.size.height ?? 0) * (containerWidth / (lastImage?.size.width ?? 1))
        
        if lastImageDisplayHeight > 0 && newBottomCrop >= lastImageDisplayHeight - 10 {
            return
        }
        
        let diff = newBottomCrop - bottomCrop
        bottomCrop = newBottomCrop
        
        // 更新最后一个容器的高度
        lastImageHeightConstraint?.constant -= diff
        
        view.layoutIfNeeded()
    }
    
    private func showWarningTip(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 14)
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor, constant: -20),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, multiplier: 0.8),
            label.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        UIView.animate(withDuration: 0.3, delay: 2.0, options: .curveEaseOut, animations: {
            label.alpha = 0
        }) { _ in
            label.removeFromSuperview()
        }
    }
    
    private func showError(_ message: String) {
        // 使用Toast代替AlertController，不返回上一页
        showToast(message: message, duration: 2.0)
    }
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func shareTapped() {
        // 生成拼接后的完整图片 (包含裁剪)
        // 隐藏调整气泡进行截图
        adjustmentViews.forEach { $0.isHidden = true }
        
        let renderer = UIGraphicsImageRenderer(bounds: contentView.bounds)
        let stitchedImage = renderer.image { ctx in
            contentView.drawHierarchy(in: contentView.bounds, afterScreenUpdates: true)
        }
        
        adjustmentViews.forEach { $0.isHidden = false }
        
        // 保存到相册
        UIImageWriteToSavedPhotosAlbum(stitchedImage, self, #selector(imageSaved(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func imageSaved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            showToast(message: "保存失败: \(error.localizedDescription)")
        } else {
            showToast(message: "已保存到相册")
        }
    }
}

// MARK: - StitchAdjustmentView

enum AdjustmentType {
    case top, middle, bottom
}

class StitchAdjustmentView: UIView {
    private let type: AdjustmentType
    var onAdjust: ((CGFloat) -> Void)?
    private var lastLocation: CGPoint = .zero
    
    init(type: AdjustmentType) {
        self.type = type
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.systemYellow
        layer.cornerRadius = 15
        translatesAutoresizingMaskIntoConstraints = false
        
        let icon = UIImageView()
        icon.tintColor = .black
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false
        addSubview(icon)
        
        switch type {
        case .top:
            icon.image = UIImage(systemName: "arrow.up")
        case .middle:
            icon.image = UIImage(systemName: "arrow.up.arrow.down")
        case .bottom:
            icon.image = UIImage(systemName: "arrow.down")
        }
        
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        // 添加点击效果或勾选图标 (如截图中所示，有时是勾选)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        addGestureRecognizer(tap)
        
        // 添加拖拽手势用于微调
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.translation(in: superview)
        if gesture.state == .changed {
            let deltaY = location.y - lastLocation.y
            onAdjust?(deltaY)
            lastLocation = location
        } else if gesture.state == .began {
            lastLocation = .zero
        }
    }
    
    @objc private func tapped() {
        // 切换图标为勾选 (演示用)
        if let icon = subviews.first as? UIImageView {
            icon.image = UIImage(systemName: "checkmark")
            backgroundColor = UIColor.systemYellow.withAlphaComponent(0.8)
        }
    }
}

// MARK: - ToastView

class ToastView: UIView {
    
    private let messageLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.systemFont(ofSize: 14)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    init(message: String) {
        super.init(frame: .zero)
        messageLabel.text = message
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = UIColor.black.withAlphaComponent(0.7)
        layer.cornerRadius = 8
        clipsToBounds = true
        
        addSubview(messageLabel)
        
        NSLayoutConstraint.activate([
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            messageLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            messageLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
    }
}

// MARK: - Toast Extension

extension UIViewController {
    func showToast(message: String, duration: TimeInterval = 2.0) {
        // 创建ToastView
        let toastView = ToastView(message: message)
        toastView.translatesAutoresizingMaskIntoConstraints = false
        
        // 添加到当前视图
        view.addSubview(toastView)
        
        // 设置约束
        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            toastView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            toastView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        
        // 初始透明度为0
        toastView.alpha = 0
        
        // 显示动画
        UIView.animate(withDuration: 0.3) {
            toastView.alpha = 1
        } completion: { _ in
            // 延迟后隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                UIView.animate(withDuration: 0.3) {
                    toastView.alpha = 0
                } completion: { _ in
                    toastView.removeFromSuperview()
                }
            }
        }
    }
}
