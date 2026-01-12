import UIKit
import Photos

class HomeViewController: UIViewController {
    private let viewModel = HomeViewModel()
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let margin: CGFloat = 16
        let spacing: CGFloat = 12
        let totalSpacing = (margin * 2) + (spacing * 2)
        let width = (UIScreen.main.bounds.width - totalSpacing) / 3
        layout.itemSize = CGSize(width: width, height: width)
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = spacing
        layout.sectionInset = UIEdgeInsets(top: margin, left: margin, bottom: 100, right: margin)
        
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .systemGray6
        cv.register(PhotoCell.self, forCellWithReuseIdentifier: "PhotoCell")
        cv.delegate = self
        cv.dataSource = self
        cv.showsVerticalScrollIndicator = false
        return cv
    }()
    
    private lazy var bottomActionBar: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.isHidden = true
        view.layer.cornerRadius = 10
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
    
    private lazy var manualStitchButton: UIButton = {
        let btn = UIButton(type: .system)
        btn.setTitle(NSLocalizedString("manual_stitch", comment: "手动拼图"), for: .normal)
        btn.setImage(UIImage(systemName: "hand.raised"), for: .normal)
        btn.addTarget(self, action: #selector(manualStitchTapped), for: .touchUpInside)
        applyButtonStyle(btn, position: .right)
        return btn
    }()
    
    enum ButtonPosition {
        case left, right
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
            case .right:
                button.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            }
        } else {
            button.layer.cornerRadius = cornerRadius
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
        setupNavigationBar()
        checkPermission()
    }
    
    private func setupNavigationBar() {
        // 设置导航栏外观，确保与 AutoStitchViewController 一致
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = .white
            appearance.shadowColor = UIColor(white: 0, alpha: 0.1)
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override var prefersStatusBarHidden: Bool {
        return false
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }
    
    private func setupUI() {
        title = NSLocalizedString("image_stitch", comment: "")
        view.backgroundColor = .white
        
        view.addSubview(collectionView)
        view.addSubview(bottomActionBar)
        view.addSubview(loadingIndicator)
        
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        bottomActionBar.translatesAutoresizingMaskIntoConstraints = false
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            bottomActionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            bottomActionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            bottomActionBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            bottomActionBar.heightAnchor.constraint(equalToConstant: 60),
            
            loadingIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        let stackView = UIStackView(arrangedSubviews: [autoStitchButton, manualStitchButton])
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = -1.0 // 使边框重叠，避免中间线变粗
        bottomActionBar.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: bottomActionBar.topAnchor),
            stackView.leadingAnchor.constraint(equalTo: bottomActionBar.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: bottomActionBar.trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomActionBar.bottomAnchor)
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
        guard viewModel.selectedAssets.count == 2 else { return }
        loadingIndicator.startAnimating()
        viewModel.fetchSelectedImages { [weak self] images in
            self?.loadingIndicator.stopAnimating()
            let vc = AutoStitchViewController()
            vc.setInputImages(images)
            self?.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    @objc private func manualStitchTapped() {
        guard viewModel.selectedAssets.count >= 2 else { return }
        loadingIndicator.startAnimating()
        viewModel.fetchSelectedImages { [weak self] images in
            self?.loadingIndicator.stopAnimating()
            let vc = AutoStitchViewController(isManualMode: true)
            vc.setInputImages(images)
            self?.navigationController?.pushViewController(vc, animated: true)
        }
    }

    private func startManualStitch(mode: StitchMode) {
        loadingIndicator.startAnimating()
        viewModel.fetchSelectedImages { [weak self] images in
            self?.loadingIndicator.stopAnimating()
            let vc = ManualStitchViewController()
            vc.setInputImages(images, mode: mode)
            self?.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func updateBottomBar() {
        let count = viewModel.selectedAssets.count
        bottomActionBar.isHidden = count < 2
        
        // 自动拼图目前仅支持 2 张图片
        let isAutoStitchEnabled = (count == 2)
        autoStitchButton.isEnabled = isAutoStitchEnabled
        autoStitchButton.alpha = isAutoStitchEnabled ? 1.0 : 0.5
        
        let isManualStitchEnabled = (count >= 2)
        manualStitchButton.isEnabled = isManualStitchEnabled
        manualStitchButton.alpha = isManualStitchEnabled ? 1.0 : 0.5
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
        // 记录操作前所有已选中的 asset，用于后续精准刷新
        let previouslySelectedAssets = viewModel.selectedAssets
        
        viewModel.toggleSelection(at: indexPath.item)
        
        // 收集需要更新的 IndexPaths：
        // 1. 当前点击的 cell (状态改变)
        // 2. 之前已选中的所有 cell (序号可能因重排而改变)
        var indexPathsToUpdate = Set<IndexPath>()
        indexPathsToUpdate.insert(indexPath)
        
        for asset in previouslySelectedAssets {
            if let index = viewModel.assets.firstIndex(of: asset) {
                indexPathsToUpdate.insert(IndexPath(item: index, section: 0))
            }
        }
        
        // 使用 reconfigureItems 仅更新 Cell 内容，不触发重新加载或动画，彻底解决闪烁问题
        if #available(iOS 15.0, *) {
            collectionView.reconfigureItems(at: Array(indexPathsToUpdate))
        } else {
            collectionView.reloadItems(at: Array(indexPathsToUpdate))
        }
        
        updateBottomBar()
    }
}
