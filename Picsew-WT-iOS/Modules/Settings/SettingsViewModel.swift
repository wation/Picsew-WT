import Foundation

struct SettingsSection {
    let title: String
    let rows: [SettingsRow]
}

struct SettingsRow {
    let title: String
    let type: SettingsRowType
}

enum SettingsRowType {
    case exportSettings
    case scrollSettings
    case tutorial
    case version
    case contactUs
    case rateApp
    case shareApp
}

class SettingsViewModel {
    let sections: [SettingsSection]
    var selectedFormat: ImageFormat = .png
    var selectedResolution: Resolution = .large
    var selectedStopDuration: StopDuration = .twoSeconds
    
    init() {
        // 加载保存的设置
        selectedFormat = UserDefaults.standard.string(forKey: "exportFormat")
            .flatMap { ImageFormat(rawValue: $0.uppercased()) } ?? .png
        
        selectedResolution = UserDefaults.standard.string(forKey: "resolution")
            .flatMap { Resolution(rawValue: $0) } ?? .large
        
        selectedStopDuration = UserDefaults.standard.string(forKey: "stopDuration")
            .flatMap { StopDuration(rawValue: $0) } ?? .twoSeconds
        
        sections = [
            SettingsSection(
                title: NSLocalizedString("export_settings", comment: "Export settings section title"),
                rows: [
                    SettingsRow(title: NSLocalizedString("export_format", comment: "Export format setting title"), type: .exportSettings),
                    SettingsRow(title: NSLocalizedString("resolution", comment: "Resolution setting title"), type: .exportSettings)
                ]
            ),
            SettingsSection(
                title: NSLocalizedString("scroll_settings", comment: "Scroll settings section title"),
                rows: [
                    SettingsRow(title: NSLocalizedString("auto_scroll_duration", comment: "Auto scroll duration setting title"), type: .scrollSettings)
                ]
            ),
            SettingsSection(
                title: NSLocalizedString("about", comment: "About section title"),
                rows: [
                    SettingsRow(title: NSLocalizedString("tutorial", comment: "Tutorial setting title"), type: .tutorial),
                    SettingsRow(title: NSLocalizedString("version", comment: "Version setting title"), type: .version),
                    SettingsRow(title: NSLocalizedString("contact_us", comment: "Contact us setting title"), type: .contactUs),
                    SettingsRow(title: NSLocalizedString("rate_app", comment: "Rate app setting title"), type: .rateApp),
                    SettingsRow(title: NSLocalizedString("share_app", comment: "Share app setting title"), type: .shareApp)
                ]
            )
        ]
    }
}
