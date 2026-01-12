import UIKit
import Photos

class VideoCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let durationLabel = UILabel()
    private let durationBgView = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(durationBgView)
        durationBgView.addSubview(durationLabel)
        
        contentView.layer.cornerRadius = 8
        contentView.clipsToBounds = true
        backgroundColor = .systemGray5 // 添加默认背景色
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        durationBgView.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        durationBgView.layer.cornerRadius = 4
        durationBgView.translatesAutoresizingMaskIntoConstraints = false
        
        durationLabel.textColor = .white
        durationLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            durationBgView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -5),
            durationBgView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -5),
            
            durationLabel.topAnchor.constraint(equalTo: durationBgView.topAnchor, constant: 2),
            durationLabel.bottomAnchor.constraint(equalTo: durationBgView.bottomAnchor, constant: -2),
            durationLabel.leadingAnchor.constraint(equalTo: durationBgView.leadingAnchor, constant: 4),
            durationLabel.trailingAnchor.constraint(equalTo: durationBgView.trailingAnchor, constant: -4)
        ])
    }
    
    func configure(with asset: PHAsset) {
        let manager = PHImageManager.default()
        let option = PHImageRequestOptions()
        option.isSynchronous = false
        option.deliveryMode = .opportunistic
        
        manager.requestImage(for: asset, targetSize: bounds.size, contentMode: .aspectFill, options: option) { [weak self] image, _ in
            self?.imageView.image = image
        }
        
        durationLabel.text = formatDuration(asset.duration)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
