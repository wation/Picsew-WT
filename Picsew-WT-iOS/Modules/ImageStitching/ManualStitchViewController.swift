import UIKit
import MobileCoreServices

class ManualStitchViewController: UIViewController {
    
    private var images: [UIImage] = []
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
    
    private lazy var saveButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Save Stitch", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(saveStitchTapped), for: .touchUpInside)
        button.isEnabled = false
        return button
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
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "Manual Stitch"
        
        view.addSubview(statusLabel)
        view.addSubview(importButton)
        view.addSubview(saveButton)
        view.addSubview(stitchScrollView)
        stitchScrollView.addSubview(stitchContainerView)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            
            importButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            importButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            importButton.widthAnchor.constraint(equalToConstant: 200),
            importButton.heightAnchor.constraint(equalToConstant: 50),
            
            saveButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            saveButton.topAnchor.constraint(equalTo: importButton.bottomAnchor, constant: 30),
            saveButton.widthAnchor.constraint(equalToConstant: 200),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            
            stitchScrollView.topAnchor.constraint(equalTo: saveButton.bottomAnchor, constant: 30),
            stitchScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stitchScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stitchScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            stitchContainerView.topAnchor.constraint(equalTo: stitchScrollView.topAnchor),
            stitchContainerView.leadingAnchor.constraint(equalTo: stitchScrollView.leadingAnchor),
            stitchContainerView.trailingAnchor.constraint(equalTo: stitchScrollView.trailingAnchor),
            stitchContainerView.bottomAnchor.constraint(equalTo: stitchScrollView.bottomAnchor),
            stitchContainerView.widthAnchor.constraint(equalTo: stitchScrollView.widthAnchor),
            stitchContainerView.heightAnchor.constraint(equalToConstant: 1000) // 初始高度，后续可调整
        ])
    }
    
    @objc private func importImagesTapped() {
        let imagePicker = UIImagePickerController()
        imagePicker.sourceType = .photoLibrary
        imagePicker.mediaTypes = [kUTTypeImage as String]
        imagePicker.allowsMultipleSelection = true
        imagePicker.delegate = self
        
        present(imagePicker, animated: true, completion: nil)
    }
    
    @objc private func saveStitchTapped() {
        // 保存拼接结果
        let stitchedImage = stitchContainerView.asImage()
        
        // 保存到相册
        UIImageWriteToSavedPhotosAlbum(stitchedImage, self, #selector(imageSaved(_:didFinishSavingWithError:contextInfo:)), nil)
    }
    
    @objc private func imageSaved(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            statusLabel.text = "Error saving image: \(error.localizedDescription)"
        } else {
            statusLabel.text = "Image saved to相册"
        }
    }
    
    private func setupImageViews() {
        // 清空之前的图片视图
        for imageView in imageViews {
            imageView.removeFromSuperview()
        }
        imageViews.removeAll()
        
        // 创建图片视图
        var currentY: CGFloat = 20
        let containerWidth = stitchContainerView.frame.width
        
        for (index, image) in images.enumerated() {
            let imageView = UIImageView(image: image)
            imageView.contentMode = .scaleAspectFit
            imageView.frame = CGRect(x: 20, y: currentY, width: containerWidth - 40, height: image.size.height * (containerWidth - 40) / image.size.width)
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
            
            currentY += imageView.frame.height + 20
        }
        
        // 调整容器高度
        stitchContainerView.heightAnchor.constraint(equalToConstant: currentY + 20).isActive = true
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

// MARK: - UIImagePickerControllerDelegate

extension ManualStitchViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        // 处理选择的图片
        if let image = info[.originalImage] as? UIImage {
            images.append(image)
            statusLabel.text = "Imported \(images.count) images"
            saveButton.isEnabled = !images.isEmpty
            
            if !images.isEmpty {
                stitchScrollView.isHidden = false
                setupImageViews()
            }
        }
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UIScrollViewDelegate

extension ManualStitchViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return stitchContainerView
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
