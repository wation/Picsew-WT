import UIKit
import ReplayKit

class VideoCaptureViewController: UIViewController {
    
    private let captureManager = VideoCaptureManager.shared
    
    private lazy var startButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Start Recording", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemRed
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(startRecordingTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var stopButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Stop Recording", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 25
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(stopRecordingTapped), for: .touchUpInside)
        button.isEnabled = false
        return button
    }()
    
    private lazy var statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Ready to record"
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkPermission()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "Video Capture"
        
        view.addSubview(statusLabel)
        view.addSubview(startButton)
        view.addSubview(stopButton)
        
        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 50),
            
            startButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            startButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            startButton.widthAnchor.constraint(equalToConstant: 200),
            startButton.heightAnchor.constraint(equalToConstant: 50),
            
            stopButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stopButton.topAnchor.constraint(equalTo: startButton.bottomAnchor, constant: 30),
            stopButton.widthAnchor.constraint(equalToConstant: 200),
            stopButton.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    private func checkPermission() {
        captureManager.checkScreenRecordingPermission { [weak self] hasPermission in
            DispatchQueue.main.async {
                if hasPermission {
                    self?.statusLabel.text = "Ready to record"
                } else {
                    self?.statusLabel.text = "Screen recording not available"
                    self?.startButton.isEnabled = false
                }
            }
        }
    }
    
    @objc private func startRecordingTapped() {
        captureManager.startRecording { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.statusLabel.text = "Error: \(error.localizedDescription)"
                } else {
                    self?.statusLabel.text = "Recording..."
                    self?.startButton.isEnabled = false
                    self?.stopButton.isEnabled = true
                }
            }
        }
    }
    
    @objc private func stopRecordingTapped() {
        captureManager.stopRecording { [weak self] videoURL, error in
            DispatchQueue.main.async {
                if let error = error {
                    self?.statusLabel.text = "Error: \(error.localizedDescription)"
                } else if let videoURL = videoURL {
                    self?.statusLabel.text = "Recording saved: \(videoURL.lastPathComponent)"
                    
                    // 这里可以继续处理视频，比如提取帧、生成截图等
                    
                    self?.startButton.isEnabled = true
                    self?.stopButton.isEnabled = false
                }
            }
        }
    }
}
