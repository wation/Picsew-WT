import UIKit
import PhotosUI

class AutoStitchViewController: UIViewController, UIGestureRecognizerDelegate {
    
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
        label.text = NSLocalizedString("auto_stitch", comment: "")
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
        // 添加全局手势用于在“打勾”状态下平移图片
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleContentViewPan(_:)))
        pan.delegate = self // 设置代理
        view.addGestureRecognizer(pan)
        return view
    }()
    
    private var lastPanLocation: CGPoint = .zero
    private var activeAdjustmentView: StitchAdjustmentView?

    @objc private func handleContentViewPan(_ gesture: UIPanGestureRecognizer) {
        // 只有当有气泡被选中（打勾状态）时，才响应图片平移裁剪
        let location = gesture.location(in: contentView)
        let translation = gesture.translation(in: contentView)
        
        if gesture.state == .began {
            lastPanLocation = .zero
            // 寻找当前处于打勾状态且距离手势最近的控件
            activeAdjustmentView = adjustmentViews
                .filter { $0.isSelected }
                .min(by: { abs($0.center.y - location.y) < abs($1.center.y - location.y) })
        } else if gesture.state == .changed {
            guard let activeView = activeAdjustmentView else { return }
            // 方向修正：为了让“图片跟着手指走”，需要将手势位移取反
            // 因为在我们的 adjustOffset/adjustTopCrop 中，deltaY 是加到偏移上的
            // 原本的逻辑是拖拽控件，现在是拖拽图片，所以方向需要反转
            let deltaY = -(translation.y - lastPanLocation.y)
            
            // 执行裁剪逻辑：打勾状态下，图片动，控件不动
            activeView.onAdjust?(deltaY)
            
            lastPanLocation = translation
        } else if gesture.state == .ended || gesture.state == .cancelled {
            activeAdjustmentView = nil
        }
    }

    // MARK: - UIGestureRecognizerDelegate
    
    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        // 如果没有气泡被打勾，全局手势不响应，让 UIScrollView 正常滚动
        let isAnySelected = adjustmentViews.contains(where: { $0.isSelected })
        return isAnySelected
    }
    
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
                        self?.showWarningTip(nsError.localizedDescription) { [weak self] in
                            // 等toast消失后，标题栏改成手动拼图
                            self?.titleLabel.text = NSLocalizedString("manual_stitch", comment: "")
                        }
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

    private func setupImageDisplay(lockingIndex: Int? = nil) {
        let images = viewModel.images
        guard !images.isEmpty, currentOffsets.count == images.count, currentBottomStarts.count == images.count else { return }
        
        let selectedStates = adjustmentViews.map { $0.isSelected }
        let existingTops = imageViewTopConstraints.map { $0.constant }
        
        view.layoutIfNeeded()
        contentView.subviews.forEach { $0.removeFromSuperview() }
        imageViews.removeAll()
        adjustmentViews.removeAll()
        imageViewTopConstraints.removeAll()
        imageViewHeightConstraints.removeAll()
        imageViewInternalTopConstraints.removeAll()
        
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        contentView.backgroundColor = .white
        let paddingTop: CGFloat = 0
        var lastContainer: UIView?
        
        var adjViewIndex = 0
        for (index, image) in images.enumerated() {
            let displayScale = containerWidth / image.size.width
            let displayHeight = image.size.height * displayScale
            let canvasY = currentOffsets[index] * displayScale
            let selfStartY = currentBottomStarts[index] * displayScale
            
            // 布局逻辑优化：
            let containerStartY: CGFloat
            if let lockIdx = lockingIndex, index == lockIdx, index < existingTops.count {
                // 如果是正在操作的中间控件，强制保持其 top 不变
                containerStartY = existingTops[index]
            } else if index == 0 && !existingTops.isEmpty {
                // 第一张图的容器 top 永远固定在 0 (或者 paddingTop)
                containerStartY = paddingTop
            } else {
                // 其他情况，根据 canvasY 重新计算位置
                // 这样可以保证当上面的重合度改变时，下面的图会整体跟着位移，不会产生空白
                containerStartY = canvasY + paddingTop + (index == 0 ? topCrop : 0)
            }
            
            let containerHeight: CGFloat
            if index == images.count - 1 {
                containerHeight = max(0, displayHeight - selfStartY - bottomCrop)
            } else {
                let nextCanvasY = currentOffsets[index+1] * displayScale
                containerHeight = max(0, nextCanvasY - canvasY)
            }
            
            let container = UIView()
            container.clipsToBounds = true
            container.backgroundColor = .clear
            container.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(container)
            
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleToFill
            imageView.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(imageView)
            imageViews.append(imageView)
            
            let topConstraint = container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: containerStartY)
            let heightConstraint = container.heightAnchor.constraint(equalToConstant: containerHeight)
            
            // 内部偏移计算：
            // 我们要显示图片的哪一部分？
            // 如果 containerStartY 是固定的，但 canvasY 变了，
            // 那么内部偏移 imgTop 必须补偿这个差值：imgTop = -(canvasY - (containerStartY - paddingTop))
            let internalTopOffset = -(canvasY - (containerStartY - paddingTop)) - (index == 0 ? topCrop : 0)
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
            
            // 重新创建气泡并恢复状态
            if index > 0 {
                let adjustmentView = StitchAdjustmentView(type: .middle)
                adjustmentView.onAdjust = { [weak self] deltaY in
                    self?.adjustOffset(at: index, deltaY: deltaY)
                }
                adjustmentView.onStateChanged = { [weak self] isSelected in
                    if isSelected {
                        self?.adjustmentViews.forEach { if $0 !== adjustmentView { $0.isSelected = false } }
                    }
                    self?.updateScrollState()
                }
                if adjViewIndex < selectedStates.count { adjustmentView.isSelected = selectedStates[adjViewIndex] }
                adjViewIndex += 1
                adjustmentView.isHidden = matchedIndices.contains(index)
                contentView.addSubview(adjustmentView)
                adjustmentViews.append(adjustmentView)
                NSLayoutConstraint.activate([
                    adjustmentView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                    adjustmentView.centerYAnchor.constraint(equalTo: container.topAnchor),
                    adjustmentView.widthAnchor.constraint(equalToConstant: 60),
                    adjustmentView.heightAnchor.constraint(equalToConstant: 30)
                ])
            } else {
                let topAdjustment = StitchAdjustmentView(type: .top)
                topAdjustment.onAdjust = { [weak self] deltaY in
                    self?.adjustTopCrop(deltaY: deltaY)
                }
                topAdjustment.onStateChanged = { [weak self] isSelected in
                    if isSelected {
                        self?.adjustmentViews.forEach { if $0 !== topAdjustment { $0.isSelected = false } }
                    }
                    self?.updateScrollState()
                }
                if adjViewIndex < selectedStates.count { topAdjustment.isSelected = selectedStates[adjViewIndex] }
                adjViewIndex += 1
                contentView.addSubview(topAdjustment)
                adjustmentViews.append(topAdjustment)
                topAdjustment.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
                NSLayoutConstraint.activate([
                    topAdjustment.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                    topAdjustment.topAnchor.constraint(equalTo: container.topAnchor),
                    topAdjustment.widthAnchor.constraint(equalToConstant: 60),
                    topAdjustment.heightAnchor.constraint(equalToConstant: 30)
                ])
            }
        }
        
        if let lastContainer = lastContainer {
            let bottomAdjustment = StitchAdjustmentView(type: .bottom)
            bottomAdjustment.onAdjust = { [weak self] deltaY in
                self?.adjustBottomCrop(deltaY: deltaY)
            }
            bottomAdjustment.onStateChanged = { [weak self] isSelected in
                if isSelected {
                    self?.adjustmentViews.forEach { if $0 !== bottomAdjustment { $0.isSelected = false } }
                }
                self?.updateScrollState()
            }
            if adjViewIndex < selectedStates.count { bottomAdjustment.isSelected = selectedStates[adjViewIndex] }
            adjViewIndex += 1
            contentView.addSubview(bottomAdjustment)
            adjustmentViews.append(bottomAdjustment)
            bottomAdjustment.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            NSLayoutConstraint.activate([
                bottomAdjustment.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                bottomAdjustment.bottomAnchor.constraint(equalTo: lastContainer.bottomAnchor),
                bottomAdjustment.widthAnchor.constraint(equalToConstant: 60),
                bottomAdjustment.heightAnchor.constraint(equalToConstant: 30),
                bottomAdjustment.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
            ])
        }
        
        contentView.subviews.forEach { subview in
            if subview is StitchAdjustmentView { contentView.bringSubviewToFront(subview) }
            else { contentView.sendSubviewToBack(subview) }
        }
        view.layoutIfNeeded()
    }
    
    private func updateScrollState() {
        // 如果有任何一个控件处于打勾（选中）状态，禁用滚动视图的滚动
        let isAnySelected = adjustmentViews.contains(where: { $0.isSelected })
        scrollView.isScrollEnabled = !isAnySelected
    }

    private func adjustTopCrop(deltaY: CGFloat) {
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let firstImage = viewModel.images.first
        let displayScale = containerWidth / (firstImage?.size.width ?? 1)
        
        let newTopCrop = max(0, topCrop + deltaY)
        let firstImageDisplayHeight = (firstImage?.size.height ?? 0) * displayScale
        if firstImageDisplayHeight > 0 && newTopCrop >= firstImageDisplayHeight - 10 { return }
        
        let diff = newTopCrop - topCrop
        topCrop = newTopCrop
        
        // 关键：所有图片的容器都要跟着动，实现“整体上移”的效果
        // 1. 第一张图内部偏移并减小高度
        firstImageViewTopConstraint?.constant -= diff
        firstImageHeightConstraint?.constant -= diff
        
        // 2. 所有后续图片的容器位置也要同步上移 diff
        // 这样整个长截图看起来就是整体往上滑动了，而顶部准星（firstImageTopConstraint 对应的位置）保持不动
        for i in 1..<imageViewTopConstraints.count {
            imageViewTopConstraints[i].constant -= diff
        }
        
        view.layoutIfNeeded()
    }
    
    private func adjustBottomCrop(deltaY: CGFloat) {
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let lastImage = viewModel.images.last
        let displayScale = containerWidth / (lastImage?.size.width ?? 1)
        
        // 用户向上拖拽气泡 (deltaY < 0)
        // 效果：底部向上裁剪 (bottomCrop 增加)
        let newBottomCrop = max(0, bottomCrop - deltaY)
        let lastImageDisplayHeight = (lastImage?.size.height ?? 0) * displayScale
        if lastImageDisplayHeight > 0 && newBottomCrop >= lastImageDisplayHeight - 10 { return }
        
        let diff = newBottomCrop - bottomCrop
        bottomCrop = newBottomCrop
        
        // 关键：控件位置不动
        // 高度缩减，底边上移
        lastImageHeightConstraint?.constant -= diff
        
        view.layoutIfNeeded()
    }
    
    private func adjustOffset(at index: Int, deltaY: CGFloat) {
        guard index > 0 && index < viewModel.images.count else { return }
        let containerWidth = view.bounds.width > 0 ? view.bounds.width : UIScreen.main.bounds.width
        let displayScale = containerWidth / viewModel.images[index].size.width
        let imageDeltaY = deltaY / displayScale
        
        matchedIndices.remove(index)
        
        // 中间气泡打勾状态下，滑动图片实现裁剪
        // 我们通过调整 currentOffsets[index] 来改变重合度
        // 这样会影响整张长截图的拼接，而不是仅仅在容器内滑动
        let newOffset = currentOffsets[index] - imageDeltaY
        
        // 限制：不能超过上一张图的范围，也不能让图片完全脱离
        let prevOffset = currentOffsets[index-1]
        if newOffset < prevOffset { return }
        
        let diff = newOffset - currentOffsets[index]
        
        // 更新当前及后续所有图片的偏移
        for i in index..<currentOffsets.count {
            currentOffsets[i] += diff
        }
        
        // 重要：为了实现“控件不动图片动”，我们需要调整 setupImageDisplay 的逻辑
        // 让它在重绘时，保持当前正在操作的这个容器的 top 不变
        setupImageDisplay(lockingIndex: index)
    }

    private func showWarningTip(_ message: String, completion: (() -> Void)? = nil) {
        showToast(message: message, completion: completion)
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
    var onStateChanged: ((Bool) -> Void)?
    
    private var lastLocation: CGPoint = .zero
    
    var isSelected: Bool = false {
        didSet {
            updateUI()
            onStateChanged?(isSelected)
        }
    }
    
    private let iconImageView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = .black
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    private let lineView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemYellow
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private let arrowContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alpha = 0
        return view
    }()
    
    private let arrowImageView: UIImageView = {
        let iv = UIImageView()
        iv.tintColor = .systemYellow
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    
    init(type: AdjustmentType) {
        self.type = type
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .systemYellow
        layer.cornerRadius = 15
        // 只给一边切圆角：顶部气泡切底部圆角，中部切上下圆角，底部切顶部圆角
        // 但根据截图，气泡是齐边的，只有外侧是圆角。
        // 重新审视截图：气泡是半圆形的，贴合在分割线上。
        
        translatesAutoresizingMaskIntoConstraints = false
        
        addSubview(iconImageView)
        addSubview(lineView)
        
        // 箭头动画容器
        superview?.addSubview(arrowContainer) // 注意：这里需要添加到父视图才能显示在气泡外
        arrowContainer.addSubview(arrowImageView)
        
        NSLayoutConstraint.activate([
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconImageView.widthAnchor.constraint(equalToConstant: 20),
            iconImageView.heightAnchor.constraint(equalToConstant: 20),
            
            lineView.heightAnchor.constraint(equalToConstant: 1)
        ])
        
        // 根据类型调整线的位置
        switch type {
        case .top:
            lineView.topAnchor.constraint(equalTo: topAnchor).isActive = true
            lineView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -2000).isActive = true
            lineView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 2000).isActive = true
            arrowImageView.image = UIImage(systemName: "chevron.compact.down")
        case .middle:
            lineView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
            lineView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -2000).isActive = true
            lineView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 2000).isActive = true
            arrowImageView.image = UIImage(systemName: "chevron.compact.up.and.chevron.compact.down")
        case .bottom:
            lineView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
            lineView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -2000).isActive = true
            lineView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 2000).isActive = true
            arrowImageView.image = UIImage(systemName: "chevron.compact.up")
        }
        
        updateUI()
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
        
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        guard let superview = superview else { return }
        
        superview.addSubview(arrowContainer)
        NSLayoutConstraint.activate([
            arrowContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            arrowImageView.centerXAnchor.constraint(equalTo: arrowContainer.centerXAnchor),
            arrowImageView.centerYAnchor.constraint(equalTo: arrowContainer.centerYAnchor),
            arrowImageView.widthAnchor.constraint(equalToConstant: 30),
            arrowImageView.heightAnchor.constraint(equalToConstant: 30),
            arrowContainer.widthAnchor.constraint(equalToConstant: 40),
            arrowContainer.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        switch type {
        case .top:
            arrowContainer.topAnchor.constraint(equalTo: bottomAnchor, constant: 10).isActive = true
        case .middle:
            // 中间的可能有两个箭头，或者根据滑动方向显示
            arrowContainer.topAnchor.constraint(equalTo: bottomAnchor, constant: 10).isActive = true
        case .bottom:
            arrowContainer.bottomAnchor.constraint(equalTo: topAnchor, constant: -10).isActive = true
        }
    }
    
    private func updateUI() {
        if isSelected {
            iconImageView.image = UIImage(systemName: "checkmark")
            startArrowAnimation()
        } else {
            switch type {
            case .top: iconImageView.image = UIImage(systemName: "arrow.up")
            case .middle: iconImageView.image = UIImage(systemName: "arrow.up.arrow.down")
            case .bottom: iconImageView.image = UIImage(systemName: "arrow.down")
            }
            stopArrowAnimation()
        }
    }
    
    @objc private func handleTap() {
        isSelected.toggle()
    }
    
    private func startArrowAnimation() {
        arrowContainer.alpha = 1
        let animation = CABasicAnimation(keyPath: "transform.translation.y")
        
        switch type {
        case .top:
            animation.fromValue = 0
            animation.toValue = 15
        case .middle:
            animation.fromValue = -10
            animation.toValue = 10
        case .bottom:
            animation.fromValue = 0
            animation.toValue = -15
        }
        
        animation.duration = 0.8
        animation.repeatCount = .infinity
        animation.autoreverses = true
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        arrowImageView.layer.add(animation, forKey: "arrowMove")
    }
    
    private func stopArrowAnimation() {
        arrowContainer.alpha = 0
        arrowImageView.layer.removeAnimation(forKey: "arrowMove")
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        // 非打勾状态下，保持现状：拖拽气泡实现裁剪
        if isSelected { 
            return 
        }
        
        let translation = gesture.translation(in: superview)
        if gesture.state == .changed {
            let deltaY = translation.y - lastLocation.y
            onAdjust?(deltaY)
            lastLocation = translation
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
    func showToast(message: String, duration: TimeInterval = 2.0, completion: (() -> Void)? = nil) {
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
                    completion?()
                }
            }
        }
    }
}
