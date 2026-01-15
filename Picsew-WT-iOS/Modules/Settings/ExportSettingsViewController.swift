import UIKit

class ExportSettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let exportFormats = ["png", "jpeg", "heic"]
    private var selectedFormatIndex = 0
    private var selectedResolutionIndex = 0
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ExportSettingsCell")
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSavedSettings()
    }
    
    private func loadSavedSettings() {
        // 加载保存的分辨率设置
        if let savedResolution = UserDefaults.standard.string(forKey: "resolution") {
            if let resolution = Resolution(rawValue: savedResolution) {
                selectedResolutionIndex = Resolution.allCases.firstIndex(of: resolution) ?? 0
            }
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = NSLocalizedString("export_settings", comment: "Export settings page title")
        
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    // MARK: - UITableViewDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0:
            return exportFormats.count
        case 1:
            return Resolution.allCases.count
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return NSLocalizedString("image_format", comment: "Image format section title")
        case 1:
            return NSLocalizedString("resolution", comment: "Resolution section title")
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExportSettingsCell", for: indexPath)
        
        switch indexPath.section {
        case 0:
            cell.textLabel?.text = NSLocalizedString(exportFormats[indexPath.row], comment: "Image format option")
            if indexPath.row == selectedFormatIndex {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        case 1:
            cell.textLabel?.text = Resolution.allCases[indexPath.row].localizedString
            if indexPath.row == selectedResolutionIndex {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        default:
            break
        }
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        switch indexPath.section {
        case 0:
            selectedFormatIndex = indexPath.row
        case 1:
            selectedResolutionIndex = indexPath.row
        default:
            break
        }
        
        tableView.reloadData()
        
        // 保存设置
        UserDefaults.standard.set(exportFormats[selectedFormatIndex], forKey: "exportFormat")
        UserDefaults.standard.set(Resolution.allCases[selectedResolutionIndex].rawValue, forKey: "resolution")
    }
}
