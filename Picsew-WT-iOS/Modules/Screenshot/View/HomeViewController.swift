import UIKit
import Photos

class HomeViewController: UIViewController {
    private let viewModel = HomeViewModel()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let width = (view.bounds.width - 4) / 3
        layout.itemSize = CGSize(width: width, height: width)
        layout.minimumInteritemSpacing = 2
        layout.minimumLineSpacing = 2
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .white
        cv.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        cv.delegate = self
        cv.dataSource = self
        return cv
    }()
    
    private lazy var bottomActionBar: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        let blurEffect = UIBlurEffect(style: .light)
        let blurView = UIVisualEffectView(effect: blurEffect)
        view.addSubview(blurView)
        blurView.frame = view.bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.isHidden = true
        view.layer.cornerRadius = 15
        view.clipsToBounds = true
        return view
    }()
    
    private lazy var autoStitchButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(NSLocalizedString("auto_stitch", comment: "自动拼图"), for: .normal)
        btn.setImage(UIImage(systemName: "magicmouse"), for: .normal)
        btn.addTarget(self, action: #selector(autoStitchTapped), for: .touchUpInside)
        applyButtonStyle(btn, position: .left)
        return btn
    }()
    
    private lazy var verticalStitchButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(NSLocalizedString("vertical_stitch", comment: "垂直拼图"), for: .normal)
        btn.setImage(UIImage(systemName: "rectangle.stack.badge.plus"), for: .normal)
        btn.addTarget(self, action: #selector(verticalStitchTapped), for: .touchUpInside)
        applyButtonStyle(btn, position: .middle)
        return btn
    }()

    private lazy var horizontalStitchButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(NSLocalizedString("horizontal_stitch", comment: "横向拼图"), for: .normal)
        btn.setImage(UIImage(systemName: "square.split.2x1"), for: .normal)
        btn.addTarget(self, action: #selector(horizontalStitchTapped), for: .touchUpInside)
        applyButtonStyle(btn, position: .right)
        return btn
    }()
    
    enum ButtonPosition {
        case left, middle, right
    }

    private func applyButtonStyle(_ button: UIButton, position: ButtonPosition) {
        button.layer.borderWidth = 1.0
        button.layer.borderColor = UIColor.systemBlue.cgColor
        button.tintColor = .systemBlue
        
        let cornerRadius: CGFloat = 10
        if #available(iOS 11.0, *) {
            button.layer.cornerRadius = cornerRadius
            switch position {
            case .left:
                button.layer.maskedCorners = [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            case .middle:
                button.layer.cornerRadius = 0
            case .right:
                button.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            }
        } else {
            // 对于 iOS 11 以下版本，逻辑较复杂，由于项目要求 iOS 17+，此处直接按 iOS 11 处理
            button.layer.cornerRadius = position == .middle ? 0 : cornerRadius
        }
        
        // 设置图片和文字的间距
        if #available(iOS 15.0, *) {
            var config = UIButton.Configuration.plain()
            config.imagePlacement = .top
            config.imagePadding = 5
            button.configuration = config
        } else {
            button.imageEdgeInsets = UIEdgeInsets(top: -10, left: 0, bottom: 0, right: 0)
            button.titleEdgeInsets = UIEdgeInsets(top: 30, left: -20, bottom: 0, right: 0)
        }
    }
    
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        checkPermission()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    private func setupUI() {
        title = NSLocalizedString("image_stitch", comment: "图片拼图")
        view.backgroundColor = .white
        
        view.addSubview(collectionView)
        view.addSubview(bottomActionBar)
        view.addSubview(loadingIndicator)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        bottomActionBar.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            bottomActionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bottomActionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bottomActionBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            bottomActionBar.heightAnchor.constraint(equalToConstant: 80),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        let stackView = UIStackView(arrangedSubviews: [autoStitchButton, verticalStitchButton, horizontalStitchButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = -1.0 // 使边框重叠，避免中间线变粗
        bottomActionBar.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: bottomActionBar.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: bottomActionBar.leadingAnchor, constant: 15),
            stackView.trailingAnchor.constraint(equalTo: bottomActionBar.trailingAnchor, constant: -15),
            stackView.bottomAnchor.constraint(equalTo: bottomActionBar.bottomAnchor, constant: -10)
        ])
    }
    
    private func checkPermission() {
        PHPhotoLibrary.requestAuthorization { [weak self] status in
            if status == .authorized {
                self?.viewModel.fetchAssets {
                    DispatchQueue.main.async {
                        self?.collectionView.reloadData()
                    }
                }
            }
        }
    }
    
    @objc private func autoStitchTapped() {
        guard viewModel.selectedAssets.count >= 2 else { return }
        loadingIndicator.startAnimating()
        viewModel.fetchSelectedImages { [weak self] images in
            self?.loadingIndicator.stopAnimating()
            let vc = AutoStitchViewController()
            vc.setInputImages(images)
            self?.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @objc private func verticalStitchTapped() {
        guard viewModel.selectedAssets.count >= 2 else { return }
        loadingIndicator.startAnimating()
        viewModel.fetchSelectedImages { [weak self] images in
            self?.loadingIndicator.stopAnimating()
            let vc = ManualStitchViewController()
            vc.setInputImages(images, mode: .vertical)
            self?.navigationController?.pushViewController(vc, animated: true)
        }
    }

    @objc private func horizontalStitchTapped() {
        guard viewModel.selectedAssets.count >= 2 else { return }
        loadingIndicator.startAnimating()
        viewModel.fetchSelectedImages { [weak self] images in
            self?.loadingIndicator.stopAnimating()
            let vc = ManualStitchViewController()
            vc.setInputImages(images, mode: .horizontal)
            self?.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func updateBottomBar() {
        bottomActionBar.isHidden = viewModel.selectedAssets.count < 2
    }
}

extension HomeViewController: UICollectionViewDelegate, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return viewModel.assets.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PhotoCell", for: indexPath) as! PhotoCell
        let asset = viewModel.assets[indexPath.item]
        cell.configure(with: asset, isSelected: viewModel.isSelected(at: indexPath.item), order: viewModel.selectionOrder(at: indexPath.item))
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        viewModel.toggleSelection(at: indexPath.item)
        collectionView.reloadItems(at: [indexPath])
        updateBottomBar()
    }
}
