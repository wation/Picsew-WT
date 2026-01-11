import UIKit
import Photos

class PhotoCell: UICollectionViewCell {
    private let imageView = UIImageView()
    private let selectionOverlay = UIView()
    private let orderLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(selectionOverlay)
        selectionOverlay.addSubview(orderLabel)
        
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        
        selectionOverlay.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        selectionOverlay.layer.borderColor = UIColor.systemBlue.cgColor
        selectionOverlay.layer.borderWidth = 2
        selectionOverlay.translatesAutoresizingMaskIntoConstraints = false
        selectionOverlay.isHidden = true
        
        orderLabel.textColor = .white
        orderLabel.backgroundColor = .systemBlue
        orderLabel.textAlignment = .center
        orderLabel.font = .systemFont(ofSize: 12, weight: .bold)
        orderLabel.layer.cornerRadius = 10
        orderLabel.clipsToBounds = true
        orderLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            selectionOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            orderLabel.topAnchor.constraint(equalTo: selectionOverlay.topAnchor, constant: 5),
            orderLabel.trailingAnchor.constraint(equalTo: selectionOverlay.trailingAnchor, constant: -5),
            orderLabel.widthAnchor.constraint(equalToConstant: 20),
            orderLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    func configure(with asset: PHAsset, isSelected: Bool, order: Int?) {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        manager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: options) { [weak self] image, _ in
            self?.imageView.image = image
        }
        
        selectionOverlay.isHidden = !isSelected
        if let order = order {
            orderLabel.text = "\(order)"
        }
    }
}
