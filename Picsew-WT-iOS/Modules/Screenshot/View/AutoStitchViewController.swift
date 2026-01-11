import UIKit
import PhotosUI

class AutoStitchViewController: UIViewController {
    
    private let viewModel = AutoStitchViewModel()
    private var imageViews: [UIImageView] = []
    private var adjustmentViews: [StitchAdjustmentView] = []
    private var currentOffsets: [CGFloat] = []
    private var currentBottomStarts: [CGFloat] = [] // 每一张图自身显示的起始 Y
    private var topCrop: CGFloat = 0 // 第一张图片的顶部裁剪 (显示坐标)
    private var bottomCrop: CGFloat = 0 // 最后一张图片的底部裁剪 (显示坐标)
    
    // MARK: - UI Components
    
    private lazy var topNavigationBar: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0, alpha: 0.1)
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)
        
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
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
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "自动拼图"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .black
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var shareButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        button.tintColor = .black
        button.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()
    
    private lazy var bottomToolbar: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.translatesAutoresizingMaskIntoConstraints = false
        
        let separator = UIView()
        separator.backgroundColor = UIColor(white: 0, alpha: 0.1)
        separator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(separator)
        
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
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.topAnchor.constraint(equalTo: view.topAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5),
            
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
    
    private lazy var scrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
        topNavigationBar.addSubview(titleLabel)
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
            
            titleLabel.centerXAnchor.constraint(equalTo: topNavigationBar.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: topNavigationBar.centerYAnchor),
            
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
    
    private var matchedIndices: Set<Int> = [] // 记录哪些索引是自动匹配成功的

    private func startAutoStitch() {
        loadingIndicator.startAnimating()
        viewModel.autoStitch { [weak self] stitchedImage, offsets, bottomStarts, matched, error in
            self?.loadingIndicator.stopAnimating()
            
            self?.matchedIndices.removeAll()
            if let matched = matched {
                self?.matchedIndices = Set(matched)
            }

            if let error = error {
                let nsError = error as NSError
                if nsError.domain == "StitchWarning" {
                    if let offsets = offsets, let bottomStarts = bottomStarts {
                        self?.currentOffsets = offsets
                        self?.currentBottomStarts = bottomStarts
                        self?.setupImageDisplay()
                        self?.showWarningTip(nsError.localizedDescription)
                    }
                } else {
                    self?.showError(error.localizedDescription)
                }
            } else if let _ = stitchedImage, let offsets = offsets, let bottomStarts = bottomStarts {
                self?.currentOffsets = offsets
                self?.currentBottomStarts = bottomStarts
                self?.setupImageDisplay()
            }
        }
    }
    
    private var imageViewTopConstraints: [NSLayoutConstraint] = []
    private var imageViewHeightConstraints: [NSLayoutConstraint] = []
    private var imageViewInternalTopConstraints: [NSLayoutConstraint] = []
    private var firstImageTopConstraint: NSLayoutConstraint?
    private var firstImageViewTopConstraint: NSLayoutConstraint?
    private var firstImageHeightConstraint: NSLayoutConstraint?
    private var lastImageHeightConstraint: NSLayoutConstraint?

    private func setupImageDisplay() {
        let images = viewModel.images
        guard !images.isEmpty, currentOffsets.count == images.count, currentBottomStarts.count == images.count else { return }
        
        view.layoutIfNeeded()
        contentView.subviews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        adjustmentViews.removeAll()
        imageViewTopConstraints.removeAll()
        imageViewHeightConstraints.removeAll()
        imageViewInternalTopConstraints.removeAll()
        
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        contentView.backgroundColor = .white
        
        let edgePadding: CGFloat = 25 // 气泡边缘到容器边缘的距离
        let bubbleHalfHeight: CGFloat = 15
        let paddingTop = edgePadding + bubbleHalfHeight // 40
        
        var lastContainer: UIView?
        
        for (index, image) in images.enumerated() {
            let displayScale = containerWidth / image.size.width
            let displayHeight = image.size.height * displayScale
            let canvasY = currentOffsets[index] * displayScale
            let selfStartY = currentBottomStarts[index] * displayScale
            
            // 容器在画布上的位置
            var finalStartY = canvasY + paddingTop
            if index == 0 {
                finalStartY += topCrop
            }
            
            // 容器的高度
            let containerHeight: CGFloat
            if index == images.count - 1 {
                // 最后一张图：(原始高度 - 自身起始位置) - 底部裁剪
                containerHeight = max(0, displayHeight - selfStartY - bottomCrop)
            } else {
                // 中间图：下一张图的起始位置 - 当前图的起始位置
                let nextCanvasY = currentOffsets[index+1] * displayScale
                containerHeight = max(0, nextCanvasY - canvasY)
            }
            
            let container = UIView()
            container.clipsToBounds = true
            container.backgroundColor = .clear
            container.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(container)
            // 关键修改：为了让上层图盖住下层图的阴影，我们需要上层图在层级上更靠前。
            // addSubview 默认把新视图放在最前面，所以我们要反向操作：
            // 将后添加的图片（下层图）放到最底层，这样先添加的图片（上层图）就在其之上。
            contentView.sendSubviewToBack(container)
            
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleToFill
            imageView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(imageView)
            imageViews.append(imageView)
            
            let topConstraint = container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: finalStartY)
            let heightConstraint = container.heightAnchor.constraint(equalToConstant: containerHeight)
            
            // 内部偏移：不仅要考虑自身的 header 裁剪，如果是第一张图还要考虑 topCrop
            let internalTopOffset = -selfStartY + (index == 0 ? -topCrop : 0)
            let imgInternalTopConstraint = imageView.topAnchor.constraint(equalTo: container.topAnchor, constant: internalTopOffset)
            
            imageViewTopConstraints.append(topConstraint)
            imageViewHeightConstraints.append(heightConstraint)
            imageViewInternalTopConstraints.append(imgInternalTopConstraint)
            
            if index == 0 {
                firstImageTopConstraint = topConstraint
                firstImageViewTopConstraint = imgInternalTopConstraint
                firstImageHeightConstraint = heightConstraint
            }
            if index == images.count - 1 {
                lastImageHeightConstraint = heightConstraint
                lastContainer = container
            }
            
            NSLayoutConstraint.activate([
                topConstraint,
                container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                heightConstraint,
                imgInternalTopConstraint,
                imageView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                imageView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                imageView.heightAnchor.constraint(equalToConstant: displayHeight)
            ])

            // 添加中间调整气泡
            if index > 0 {
                let isMatched = matchedIndices.contains(index)
                let adjustmentView = StitchAdjustmentView(type: .middle)
                adjustmentView.onAdjust = { [weak self] deltaY in
                    self?.adjustOffset(at: index, deltaY: deltaY)
                }
                adjustmentView.isHidden = isMatched
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
        if let lastContainer = lastContainer {
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
                bottomAdjustment.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -edgePadding)
            ])
        }
        
        // 确保气泡在最上层，图片在最下层
         contentView.subviews.forEach { subview in
             if subview is StitchAdjustmentView {
                 contentView.bringSubviewToFront(subview)
             } else {
                 contentView.sendSubviewToBack(subview)
             }
         }
         
         contentView.layoutIfNeeded()
     }
    
    private func adjustOffset(at index: Int, deltaY: CGFloat) {
        guard index > 0 && index < imageViewTopConstraints.count else { return }
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let displayScale = containerWidth / viewModel.images[index].size.width
        let imageDeltaY = deltaY / displayScale
        
        // 调整偏移量时，我们需要移除“自动匹配”标记，因为用户开始手动调整了
        matchedIndices.remove(index)
        
        for i in index..<currentOffsets.count {
            currentOffsets[i] += imageDeltaY
        }
        
        // 重新布局
        setupImageDisplay()
    }
    
    private func adjustTopCrop(deltaY: CGFloat) {
        let newTopCrop = max(0, topCrop + deltaY)
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let firstImage = viewModel.images.first
        let firstImageDisplayHeight = (firstImage?.size.height ?? 0) * (containerWidth / (firstImage?.size.width ?? 1))
        
        if firstImageDisplayHeight > 0 && newTopCrop >= firstImageDisplayHeight - 10 { return }
        
        let diff = newTopCrop - topCrop
        topCrop = newTopCrop
        firstImageTopConstraint?.constant += diff
        firstImageViewTopConstraint?.constant -= diff
        firstImageHeightConstraint?.constant -= diff
        view.layoutIfNeeded()
    }
    
    private func adjustBottomCrop(deltaY: CGFloat) {
        let newBottomCrop = max(0, bottomCrop - deltaY)
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let lastImage = viewModel.images.last
        let lastImageDisplayHeight = (lastImage?.size.height ?? 0) * (containerWidth / (lastImage?.size.width ?? 1))
        
        if lastImageDisplayHeight > 0 && newBottomCrop >= lastImageDisplayHeight - 10 { return }
        
        let diff = newBottomCrop - bottomCrop
        bottomCrop = newBottomCrop
        lastImageHeightConstraint?.constant -= diff
        view.layoutIfNeeded()
    }

    private func showWarningTip(_ message: String) {
        showToast(message: message)
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "错误", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func backTapped() {
        navigationController?.popViewController(animated: true)
    }
    
    @objc private func shareTapped() {
        guard let stitchedImage = generateFullResolutionImage() else {
            showError("生成图片失败")
            return
        }
        
        loadingIndicator.startAnimating()
        UIImageWriteToSavedPhotosAlbum(stitchedImage, self, #selector(imageSaved(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    private func generateFullResolutionImage() -> UIImage? {
        let images = viewModel.images
        guard !images.isEmpty, currentOffsets.count == images.count, currentBottomStarts.count == images.count else { return nil }
        
        let firstImage = images[0]
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let displayScale = containerWidth / firstImage.size.width
        
        let origTopCrop = topCrop / displayScale
        let origBottomCrop = bottomCrop / displayScale
        
        // 计算原始总高度
        let lastIndex = images.count - 1
        let lastImage = images[lastIndex]
        let lastCanvasY = currentOffsets[lastIndex]
        let lastSelfStartY = currentBottomStarts[lastIndex]
        let lastImageHeight = lastImage.size.height
        
        let firstCanvasY = currentOffsets[0]
        
        // 总高度 = (最后一张图的底部在画布的位置 - 底部裁剪) - (第一张图的顶部在画布的位置 + 顶部裁剪)
        let totalFullHeight = (lastCanvasY + lastImageHeight - lastSelfStartY - origBottomCrop) - (firstCanvasY + origTopCrop)
        
        if totalFullHeight <= 0 { return nil }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0 // 使用原图像素
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: firstImage.size.width, height: totalFullHeight), format: format)
        
        return renderer.image { ctx in
            for (index, image) in images.enumerated() {
                let canvasY = currentOffsets[index]
                let selfStartY = currentBottomStarts[index]
                
                // 该图片在结果图中的起始 Y
                let drawY = canvasY - (firstCanvasY + origTopCrop)
                
                // 确定该段的裁剪高度
                let segmentHeight: CGFloat
                if index == lastIndex {
                    segmentHeight = image.size.height - selfStartY - origBottomCrop
                } else {
                    segmentHeight = currentOffsets[index+1] - canvasY
                }
                
                let drawRect = CGRect(x: 0, y: drawY, width: image.size.width, height: segmentHeight)
                
                ctx.cgContext.saveGState()
                ctx.cgContext.clip(to: drawRect)
                
                // 绘制图片，需要考虑 selfStartY 和如果是第一张图的 origTopCrop
                let imageDrawY = drawY - selfStartY - (index == 0 ? origTopCrop : 0)
                let imageDrawRect = CGRect(x: 0, y: imageDrawY, width: image.size.width, height: image.size.height)
                image.draw(in: imageDrawRect)
                
                ctx.cgContext.restoreGState()
            }
        }
    }
    
    @objc private func imageSaved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        loadingIndicator.stopAnimating()
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
        case .top: icon.image = UIImage(systemName: "arrow.up")
        case .middle: icon.image = UIImage(systemName: "arrow.up.arrow.down")
        case .bottom: icon.image = UIImage(systemName: "arrow.down")
        }
        
        NSLayoutConstraint.activate([
            icon.centerXAnchor.constraint(equalTo: centerXAnchor),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            icon.heightAnchor.constraint(equalToConstant: 20)
        ])
        
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
        let toastView = ToastView(message: message)
        toastView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toastView)
        NSLayoutConstraint.activate([
            toastView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60),
            toastView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            toastView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20)
        ])
        toastView.alpha = 0
        UIView.animate(withDuration: 0.3) {
            toastView.alpha = 1
        } completion: { _ in
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
