import UIKit

class SettingsViewController: UIViewController {
    
    // MARK: - UI 组件
    private let titleLabel = UILabel()
    private let settingsTableView = UITableView()
    
    // MARK: - 数据
    private let settingsItems = [
        (title: NSLocalizedString("export_settings", comment: "导出设置"), subtitle: "调整导出图片的质量和格式", icon: "square.and.arrow.up", viewController: ExportSettingsViewController()),
        (title: NSLocalizedString("scroll_settings", comment: "滚动设置"), subtitle: "调整自动滚动的速度和灵敏度", icon: "arrow.down.to.line", viewController: ScrollSettingsViewController()),
        (title: NSLocalizedString("tutorial", comment: "教程"), subtitle: "查看如何使用应用的详细教程", icon: "book", viewController: TutorialViewController()),
        (title: "关于", subtitle: NSLocalizedString("version", comment: "版本") + " 1.0.0", icon: "info.circle", viewController: nil)
    ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGray6
        setupUI()
        setupConstraints()
        setupTableView()
    }
    
    // MARK: - UI 设置
    private func setupUI() {
        // 设置标题
        titleLabel.text = NSLocalizedString("settings", comment: "设置")
        titleLabel.font = UIFont.boldSystemFont(ofSize: 18)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(titleLabel)
        
        // 设置表格视图
        settingsTableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(settingsTableView)
    }
    
    private func setupTableView() {
        settingsTableView.dataSource = self
        settingsTableView.delegate = self
        settingsTableView.backgroundColor = .systemGray6
        settingsTableView.separatorStyle = .none
        settingsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
    }
    
    // MARK: - 约束设置
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 标题
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            titleLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            
            // 表格视图
            settingsTableView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            settingsTableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            settingsTableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            settingsTableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    // MARK: - 导航方法
    private func navigateToViewController(_ viewController: UIViewController) {
        navigationController?.pushViewController(viewController, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension SettingsViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        let settingsItem = settingsItems[indexPath.row]
        
        // 配置单元格
        var content = cell.defaultContentConfiguration()
        content.text = settingsItem.title
        content.secondaryText = settingsItem.subtitle
        content.image = UIImage(systemName: settingsItem.icon)
        content.imageProperties.tintColor = .systemBlue
        content.textProperties.font = UIFont.systemFont(ofSize: 16)
        content.secondaryTextProperties.font = UIFont.systemFont(ofSize: 14)
        content.secondaryTextProperties.color = .secondaryLabel
        cell.contentConfiguration = content
        
        // 添加右侧箭头
        cell.accessoryType = .disclosureIndicator
        cell.backgroundColor = .systemGray6
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension SettingsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let settingsItem = settingsItems[indexPath.row]
        if let viewController = settingsItem.viewController {
            navigateToViewController(viewController)
        } else {
            // 处理关于按钮点击
            showAboutAlert()
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 70
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        return nil
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    // MARK: - 关于弹窗
    private func showAboutAlert() {
        let alertController = UIAlertController(title: "关于 Picsew-WT", message: "版本 1.0.0\n\nPicsew-WT 是一款功能强大的长截图和图片拼接工具，支持视频截图和手动拼接。\n\n© 2026 MagiXun", preferredStyle: .alert)
        let okAction = UIAlertAction(title: "确定", style: .default)
        alertController.addAction(okAction)
        present(alertController, animated: true)
    }
}
