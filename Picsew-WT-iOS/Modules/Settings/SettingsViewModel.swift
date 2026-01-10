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
    
    init() {
        sections = [
            SettingsSection(
                title: "Export Settings",
                rows: [
                    SettingsRow(title: "Export Format", type: .exportSettings),
                    SettingsRow(title: "Resolution", type: .exportSettings)
                ]
            ),
            SettingsSection(
                title: "Scroll Settings",
                rows: [
                    SettingsRow(title: "Auto Scroll Duration", type: .scrollSettings)
                ]
            ),
            SettingsSection(
                title: "About",
                rows: [
                    SettingsRow(title: "Tutorial", type: .tutorial),
                    SettingsRow(title: "Version", type: .version),
                    SettingsRow(title: "Contact Us", type: .contactUs),
                    SettingsRow(title: "Rate App", type: .rateApp),
                    SettingsRow(title: "Share App", type: .shareApp)
                ]
            )
        ]
    }
}
