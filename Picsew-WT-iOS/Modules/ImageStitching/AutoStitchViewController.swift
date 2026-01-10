import UIKit
import MobileCoreServices

class AutoStitchViewController: UIViewController {
    
    private let stitchManager = AutoStitchManager.shared
    private var images: [UIImage] = []
    
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
    
    private lazy var stitchButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Auto Stitch", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(autoStitchTapped), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Import images to stitch"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var imageScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isHidden = true
        return scrollView
    }()
    
    private lazy var stitchedImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "Auto Stitch"
        
        view.addSubview(statusLabel)
        view.addSubview(importButton)
        view.addSubview(stitchButton)
        view.addSubview(imageScrollView)
        imageScrollView.addSubview(stitchedImageView)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            
            importButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            importButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            importButton.widthAnchor.constraint(equalToConstant: 200),
            importButton.heightAnchor.constraint(equalToConstant: 50),
            
            stitchButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stitchButton.topAnchor.constraint(equalTo: importButton.bottomAnchor, constant: 30),
            stitchButton.widthAnchor.constraint(equalToConstant: 200),
            stitchButton.heightAnchor.constraint(equalToConstant: 50),
            
            imageScrollView.topAnchor.constraint(equalTo: stitchButton.bottomAnchor, constant: 30),
            imageScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            stitchedImageView.topAnchor.constraint(equalTo: imageScrollView.topAnchor),
            stitchedImageView.leadingAnchor.constraint(equalTo: imageScrollView.leadingAnchor),
            stitchedImageView.trailingAnchor.constraint(equalTo: imageScrollView.trailingAnchor),
            stitchedImageView.bottomAnchor.constraint(equalTo: imageScrollView.bottomAnchor)
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
    
    @objc private func autoStitchTapped() {
        guard !images.isEmpty else {
            statusLabel.text = "Please import images first"
            return
        }
        
        statusLabel.text = "Stitching images..."
        
        stitchManager.autoStitch(images) { [weak self] stitchedImage, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.statusLabel.text = "Error: \(error.localizedDescription)"
                } else if let stitchedImage = stitchedImage {
                    self?.statusLabel.text = "Stitching completed"
                    self?.stitchedImageView.image = stitchedImage
                    self?.imageScrollView.isHidden = false
                }
            }
        }
    }
}

// MARK: - UIImagePickerControllerDelegate

extension AutoStitchViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        
        // 处理选择的图片
        if let image = info[.originalImage] as? UIImage {
            images.append(image)
            statusLabel.text = "Imported \(images.count) images"
            stitchButton.isEnabled = images.count >= 2
        }
    }
    
    // 注意：在iOS 14及以上版本，UIImagePickerController支持多选，但回调方法与单选相同
    // 这里简化处理，实际应用中可能需要使用PHPickerViewController来实现更完整的多选功能
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
}
