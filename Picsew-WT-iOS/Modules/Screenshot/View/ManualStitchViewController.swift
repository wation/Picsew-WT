import UIKit
import PhotosUI
import MobileCoreServices

enum StitchMode {
    case vertical
    case horizontal
}

class ManualStitchViewController: UIViewController {
    
    private var images: [UIImage] = []
    private var mode: StitchMode = .vertical
    private var imageViews: [UIImageView] = []
    private var currentSelectedImageView: UIImageView?
    
    private lazy var importButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Import Images", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(importImagesTapped), for: .touchUpInside)
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
        
        // 分享图片，复制图片，导出到相册，导出到文件
        let buttonsData = [
            (icon: "square.and.arrow.up", action: #selector(shareImageTapped)),
            (icon: "doc.on.doc", action: #selector(copyImageTapped)),
            (icon: "photo", action: #selector(saveToAlbumTapped)),
            (icon: "folder", action: #selector(exportToFileTapped))
        ]
        
        for buttonData in buttonsData {
            let btn = UIButton(type: .system)
            btn.setImage(UIImage(systemName: buttonData.icon), for: .normal)
            btn.tintColor = .systemBlue
            btn.contentVerticalAlignment = .center
            btn.contentHorizontalAlignment = .center
            btn.addTarget(self, action: buttonData.action, for: .touchUpInside)
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
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Import images to manually stitch"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var stitchScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isHidden = true
        scrollView.minimumZoomScale = 0.1
        scrollView.maximumZoomScale = 5.0
        scrollView.delegate = self
        return scrollView
    }()
    
    private lazy var stitchContainerView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .lightGray
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    func setInputImages(_ images: [UIImage], mode: StitchMode = .vertical) {
        self.images = images
        self.mode = mode
        self.statusLabel.text = "Imported \(images.count) images (\(mode == .vertical ? "Vertical" : "Horizontal"))"
        if !images.isEmpty {
            self.stitchScrollView.isHidden = false
            self.setupImageViews()
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "Manual Stitch"
        
        view.addSubview(statusLabel)
        view.addSubview(importButton)
        view.addSubview(stitchScrollView)
        view.addSubview(bottomToolbar)
        stitchScrollView.addSubview(stitchContainerView)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            
            importButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            importButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            importButton.widthAnchor.constraint(equalToConstant: 200),
            importButton.heightAnchor.constraint(equalToConstant: 50),
            
            stitchScrollView.topAnchor.constraint(equalTo: importButton.bottomAnchor, constant: 30),
            stitchScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stitchScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stitchScrollView.bottomAnchor.constraint(equalTo: bottomToolbar.topAnchor, constant: -10),
            
            stitchContainerView.topAnchor.constraint(equalTo: stitchScrollView.topAnchor),
            stitchContainerView.leadingAnchor.constraint(equalTo: stitchScrollView.leadingAnchor),
            stitchContainerView.trailingAnchor.constraint(equalTo: stitchScrollView.trailingAnchor),
            stitchContainerView.bottomAnchor.constraint(equalTo: stitchScrollView.bottomAnchor),
            stitchContainerView.widthAnchor.constraint(equalTo: stitchScrollView.widthAnchor),
            stitchContainerView.heightAnchor.constraint(equalToConstant: 1000), // 初始高度，后续可调整
            
            // 底部工具栏约束
            bottomToolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomToolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomToolbar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomToolbar.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    @objc private func importImagesTapped() {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 0 // 0 means no limit
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    // MARK: - Bottom Toolbar Actions
    
    @objc private func shareImageTapped() {
        guard let stitchedImage = getStitchedImage() else {
            showAlert(title: NSLocalizedString("error", comment: "Error"), message: NSLocalizedString("failed_to_get_stitch_result", comment: "Failed to get stitch result"))
            return
        }
        
        let activityViewController = UIActivityViewController(activityItems: [stitchedImage], applicationActivities: nil)
        activityViewController.popoverPresentationController?.sourceView = view
        present(activityViewController, animated: true)
    }
    
    @objc private func copyImageTapped() {
        guard let stitchedImage = getStitchedImage() else {
            showAlert(title: NSLocalizedString("error", comment: "Error"), message: NSLocalizedString("failed_to_get_stitch_result", comment: "Failed to get stitch result"))
            return
        }
        
        UIPasteboard.general.image = stitchedImage
        showAlert(title: NSLocalizedString("success", comment: "Success"), message: NSLocalizedString("image_copied_to_clipboard", comment: "Image copied to clipboard"))
    }
    
    @objc private func saveToAlbumTapped() {
        guard let stitchedImage = getStitchedImage() else {
            showAlert(title: NSLocalizedString("error", comment: "Error"), message: NSLocalizedString("failed_to_get_stitch_result", comment: "Failed to get stitch result"))
            return
        }
        
        // 请求相册访问权限
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch status {
                case .authorized, .limited:
                    // 保存到相册
                    PHPhotoLibrary.shared().performChanges { [weak self] in
                        PHAssetChangeRequest.creationRequestForAsset(from: stitchedImage)
                    } completionHandler: { [weak self] success, error in
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }
                            if success {
                                self.showAlert(title: NSLocalizedString("success", comment: "Success"), message: NSLocalizedString("image_saved_to_album", comment: "Image saved to album"))
                            } else {
                                let errorMessage = error?.localizedDescription ?? NSLocalizedString("save_failed", comment: "Save failed")
                                self.showAlert(title: NSLocalizedString("error", comment: "Error"), message: errorMessage)
                            }
                        }
                    }
                default:
                    self.showAlert(title: NSLocalizedString("permission_denied", comment: "Permission denied"), message: NSLocalizedString("allow_photo_album_permission", comment: "Allow photo album permission"))
                }
            }
        }
    }
    
    @objc private func exportToFileTapped() {
        guard let stitchedImage = getStitchedImage() else {
            showAlert(title: NSLocalizedString("error", comment: "Error"), message: NSLocalizedString("failed_to_get_stitch_result", comment: "Failed to get stitch result"))
            return
        }
        
        // 将图片转换为PNG数据
        guard let pngData = stitchedImage.pngData() else {
            showAlert(title: NSLocalizedString("error", comment: "Error"), message: NSLocalizedString("failed_to_convert_to_png", comment: "Failed to convert to PNG"))
            return
        }
        
        // 创建临时文件
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("PicsewAI_Stitched.png")
        do {
            try pngData.write(to: tempURL)
        } catch {
            showAlert(title: NSLocalizedString("error", comment: "Error"), message: NSLocalizedString("failed_to_create_temp_file", comment: "Failed to create temp file"))
            return
        }
        
        // 显示文件选择器
        let documentPicker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: true)
        documentPicker.delegate = self
        present(documentPicker, animated: true)
    }
    
    // MARK: - Helper Methods
    
    private func getStitchedImage() -> UIImage? {
        // 获取拼接结果图片
        return stitchContainerView.asImage()
    }
    
    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("ok", comment: "OK"), style: .default))
        present(alert, animated: true)
    }
    
    private func setupImageViews() {
        // 清空之前的图片视图
        for imageView in imageViews {
            imageView.removeFromSuperview()
        }
        imageViews.removeAll()
        
        // 创建图片视图
        let horizontalMargin: CGFloat = 16
        var currentX: CGFloat = horizontalMargin
        var currentY: CGFloat = horizontalMargin
        let containerWidth = stitchContainerView.frame.width
        let containerHeight = stitchContainerView.frame.height
        
        for image in images {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            
            if mode == .vertical {
                let displayWidth = containerWidth - (horizontalMargin * 2)
                let displayHeight = image.size.height * (displayWidth / image.size.width)
                imageView.frame = CGRect(x: horizontalMargin, y: currentY, width: displayWidth, height: displayHeight)
                currentY += displayHeight + horizontalMargin
            } else {
                let displayHeight = containerHeight - (horizontalMargin * 2)
                let displayWidth = image.size.width * (displayHeight / image.size.height)
                imageView.frame = CGRect(x: currentX, y: horizontalMargin, width: displayWidth, height: displayHeight)
                currentX += displayWidth + horizontalMargin
            }
            
            imageView.isUserInteractionEnabled = true
            
            // 添加拖拽手势
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            imageView.addGestureRecognizer(panGesture)
            
            // 添加点击手势
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
            imageView.addGestureRecognizer(tapGesture)
            
            // 添加边框以区分选中状态
            imageView.layer.borderWidth = 2
            imageView.layer.borderColor = UIColor.clear.cgColor
            
            stitchContainerView.addSubview(imageView)
            imageViews.append(imageView)
        }
        
        // 调整容器大小
        if mode == .vertical {
            stitchContainerView.heightAnchor.constraint(equalToConstant: currentY + 20).isActive = true
        } else {
            stitchContainerView.widthAnchor.constraint(equalToConstant: currentX + 20).isActive = true
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let imageView = gesture.view as? UIImageView else { return }
        
        let translation = gesture.translation(in: stitchContainerView)
        
        switch gesture.state {
        case .began:
            // 选中当前图片
            selectImageView(imageView)
        case .changed:
            // 移动图片
            imageView.center = CGPoint(x: imageView.center.x + translation.x, y: imageView.center.y + translation.y)
            gesture.setTranslation(.zero, in: stitchContainerView)
        default:
            break
        }
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let imageView = gesture.view as? UIImageView else { return }
        selectImageView(imageView)
    }
    
    private func selectImageView(_ imageView: UIImageView) {
        // 取消之前的选中状态
        for view in imageViews {
            view.layer.borderColor = UIColor.clear.cgColor
        }
        
        // 设置当前选中状态
        imageView.layer.borderColor = UIColor.systemBlue.cgColor
        currentSelectedImageView = imageView
    }
}

// MARK: - PHPickerViewControllerDelegate

extension ManualStitchViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        
        let group = DispatchGroup()
        var newImages: [UIImage] = []
        
        for result in results {
            group.enter()
            result.itemProvider.loadObject(ofClass: UIImage.self) { (object, error) in
                if let image = object as? UIImage {
                    newImages.append(image)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.images.append(contentsOf: newImages)
            self.statusLabel.text = "Imported \(self.images.count) images"
            
            if !self.images.isEmpty {
                self.stitchScrollView.isHidden = false
                self.setupImageViews()
            }
        }
    }
}

// MARK: - UIScrollViewDelegate

extension ManualStitchViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return stitchContainerView
    }
}

// MARK: - UIDocumentPickerDelegate

extension ManualStitchViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        // 文件导出成功
        showAlert(title: NSLocalizedString("success", comment: "Success"), message: NSLocalizedString("image_exported_to_file", comment: "Image exported to file"))
    }
    
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        // 文件导出被取消
    }
}

// MARK: - UIView Extension

extension UIView {
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}
