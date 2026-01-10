import UIKit

class ExportSettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let exportFormats = ["PNG", "JPEG", "HEIC"]
    private let resolutions = ["Original", "High", "Medium", "Low"]
    
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
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "Export Settings"
        
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
            return resolutions.count
        default:
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Image Format"
        case 1:
            return "Resolution"
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ExportSettingsCell", for: indexPath)
        
        switch indexPath.section {
        case 0:
            cell.textLabel?.text = exportFormats[indexPath.row]
            if indexPath.row == selectedFormatIndex {
                cell.accessoryType = .checkmark
            } else {
                cell.accessoryType = .none
            }
        case 1:
            cell.textLabel?.text = resolutions[indexPath.row]
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
        UserDefaults.standard.set(resolutions[selectedResolutionIndex], forKey: "resolution")
    }
}
