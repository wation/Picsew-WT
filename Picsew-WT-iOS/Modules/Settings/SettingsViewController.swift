import UIKit

class SettingsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    private let settingsViewModel = SettingsViewModel()
    
    private lazy var tableView: UITableView = {
        let tableView = UITableView()
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SettingsCell")
        return tableView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .white
        title = "Settings"
        
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
        return settingsViewModel.sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return settingsViewModel.sections[section].rows.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return settingsViewModel.sections[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsCell", for: indexPath)
        let row = settingsViewModel.sections[indexPath.section].rows[indexPath.row]
        
        cell.textLabel?.text = row.title
        cell.accessoryType = .disclosureIndicator
        
        return cell
    }
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let row = settingsViewModel.sections[indexPath.section].rows[indexPath.row]
        handleRowSelection(row)
    }
    
    private func handleRowSelection(_ row: SettingsRow) {
        switch row.type {
        case .exportSettings:
            showExportSettings()
        case .scrollSettings:
            showScrollSettings()
        case .tutorial:
            showTutorial()
        case .version:
            showVersion()
        case .contactUs:
            showContactUs()
        case .rateApp:
            rateApp()
        case .shareApp:
            shareApp()
        }
    }
    
    private func showExportSettings() {
        let exportSettingsVC = ExportSettingsViewController()
        navigationController?.pushViewController(exportSettingsVC, animated: true)
    }
    
    private func showScrollSettings() {
        let scrollSettingsVC = ScrollSettingsViewController()
        navigationController?.pushViewController(scrollSettingsVC, animated: true)
    }
    
    private func showTutorial() {
        let tutorialVC = TutorialViewController()
        navigationController?.pushViewController(tutorialVC, animated: true)
    }
    
    private func showVersion() {
        let alert = UIAlertController(title: "Version", message: "Picsew-WT v1.0", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showContactUs() {
        if let url = URL(string: "mailto:contact@picsew-wt.com") {
            UIApplication.shared.open(url)
        }
    }
    
    private func rateApp() {
        if let url = URL(string: "https://apps.apple.com/app/id1234567890") {
            UIApplication.shared.open(url)
        }
    }
    
    private func shareApp() {
        let text = "Check out Picsew-WT, the best long screenshot app!"
        let url = URL(string: "https://apps.apple.com/app/id1234567890")!
        
        let activityViewController = UIActivityViewController(activityItems: [text, url], applicationActivities: nil)
        present(activityViewController, animated: true)
    }
}
