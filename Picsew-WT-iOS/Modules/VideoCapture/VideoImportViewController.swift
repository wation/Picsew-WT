import UIKit

class VideoImportViewController: UIViewController {
    
    private let importer = VideoImporter.shared
    
    private lazy var importButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Import Video", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(importVideoTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Tap to import video"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var framesScrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.isHidden = true
        return scrollView
    }()
    
    private lazy var framesStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkPermission()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "Import Video"
        
        view.addSubview(statusLabel)
        view.addSubview(importButton)
        view.addSubview(framesScrollView)
        framesScrollView.addSubview(framesStackView)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            
            importButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            importButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            importButton.widthAnchor.constraint(equalToConstant: 200),
            importButton.heightAnchor.constraint(equalToConstant: 50),
            
            framesScrollView.topAnchor.constraint(equalTo: importButton.bottomAnchor, constant: 30),
            framesScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            framesScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            framesScrollView.heightAnchor.constraint(equalToConstant: 200),
            framesScrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            
            framesStackView.topAnchor.constraint(equalTo: framesScrollView.topAnchor),
            framesStackView.leadingAnchor.constraint(equalTo: framesScrollView.leadingAnchor, constant: 10),
            framesStackView.trailingAnchor.constraint(equalTo: framesScrollView.trailingAnchor, constant: -10),
            framesStackView.bottomAnchor.constraint(equalTo: framesScrollView.bottomAnchor),
            framesStackView.heightAnchor.constraint(equalTo: framesScrollView.heightAnchor, constant: -20)
        ])
    }
    
    private func checkPermission() {
        importer.checkPhotoLibraryPermission { [weak self] hasPermission in
            DispatchQueue.main.async {
                if !hasPermission {
                    self?.statusLabel.text = "Photo library access denied"
                    self?.importButton.isEnabled = false
                }
            }
        }
    }
    
    @objc private func importVideoTapped() {
        importer.openVideoPicker(from: self) { [weak self] videoURL, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.statusLabel.text = "Error: \(error.localizedDescription)"
                } else if let videoURL = videoURL {
                    self?.statusLabel.text = "Video imported: \(videoURL.lastPathComponent)"
                    self?.extractFrames(from: videoURL)
                }
            }
        }
    }
    
    private func extractFrames(from videoURL: URL) {
        statusLabel.text = "Extracting frames..."
        
        importer.extractFrames(from: videoURL, interval: 1.0) { [weak self] frames, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.statusLabel.text = "Error: \(error.localizedDescription)"
                } else {
                    self?.statusLabel.text = "Extracted \(frames.count) frames"
                    self?.displayFrames(frames)
                }
            }
        }
    }
    
    private func displayFrames(_ frames: [UIImage]) {
        // 清空之前的帧
        for arrangedSubview in framesStackView.arrangedSubviews {
            arrangedSubview.removeFromSuperview()
        }
        
        // 添加新帧
        for frame in frames {
            let imageView = UIImageView(image: frame)
            imageView.contentMode = .scaleAspectFit
            imageView.widthAnchor.constraint(equalToConstant: 150).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: 150).isActive = true
            framesStackView.addArrangedSubview(imageView)
        }
        
        framesScrollView.isHidden = false
    }
}
