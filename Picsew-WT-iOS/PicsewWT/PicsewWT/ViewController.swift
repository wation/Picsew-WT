import UIKit

class ViewController: UIViewController {

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = "app_name".localized
        label.font = UIFont.systemFont(ofSize: 32, weight: .bold)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var videoCaptureButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("video_capture".localized, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(videoCaptureTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var importVideoButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("import_video".localized, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(importVideoTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var autoStitchButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("auto_stitch".localized, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemOrange
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(autoStitchTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var manualStitchButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("manual_stitch".localized, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemPurple
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(manualStitchTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var settingsButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("settings".localized, for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGray
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(settingsTapped), for: .touchUpInside)
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        
        view.addSubview(titleLabel)
        view.addSubview(videoCaptureButton)
        view.addSubview(importVideoButton)
        view.addSubview(autoStitchButton)
        view.addSubview(manualStitchButton)
        view.addSubview(settingsButton)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            
            videoCaptureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            videoCaptureButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 50),
            videoCaptureButton.widthAnchor.constraint(equalToConstant: 250),
            videoCaptureButton.heightAnchor.constraint(equalToConstant: 60),
            
            importVideoButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            importVideoButton.topAnchor.constraint(equalTo: videoCaptureButton.bottomAnchor, constant: 20),
            importVideoButton.widthAnchor.constraint(equalToConstant: 250),
            importVideoButton.heightAnchor.constraint(equalToConstant: 60),
            
            autoStitchButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            autoStitchButton.topAnchor.constraint(equalTo: importVideoButton.bottomAnchor, constant: 20),
            autoStitchButton.widthAnchor.constraint(equalToConstant: 250),
            autoStitchButton.heightAnchor.constraint(equalToConstant: 60),
            
            manualStitchButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            manualStitchButton.topAnchor.constraint(equalTo: autoStitchButton.bottomAnchor, constant: 20),
            manualStitchButton.widthAnchor.constraint(equalToConstant: 250),
            manualStitchButton.heightAnchor.constraint(equalToConstant: 60),
            
            settingsButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            settingsButton.topAnchor.constraint(equalTo: manualStitchButton.bottomAnchor, constant: 20),
            settingsButton.widthAnchor.constraint(equalToConstant: 250),
            settingsButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    @objc private func videoCaptureTapped() {
        let videoCaptureVC = VideoCaptureViewController()
        navigationController?.pushViewController(videoCaptureVC, animated: true)
    }
    
    @objc private func importVideoTapped() {
        let videoImportVC = VideoImportViewController()
        navigationController?.pushViewController(videoImportVC, animated: true)
    }
    
    @objc private func autoStitchTapped() {
        let autoStitchVC = AutoStitchViewController()
        navigationController?.pushViewController(autoStitchVC, animated: true)
    }
    
    @objc private func manualStitchTapped() {
        let manualStitchVC = ManualStitchViewController()
        navigationController?.pushViewController(manualStitchVC, animated: true)
    }
    
    @objc private func settingsTapped() {
        let settingsVC = SettingsViewController()
        navigationController?.pushViewController(settingsVC, animated: true)
    }
}