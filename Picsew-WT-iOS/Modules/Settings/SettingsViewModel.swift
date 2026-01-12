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

enum ImageFormat: String, CaseIterable {
    case heic = "HEIC"
    case jpeg = "JPEG"
    case png = "PNG"
}

enum Resolution: String, CaseIterable {
    case large = "大"
    case medium = "中"
    case small = "小"
}

enum StopDuration: String, CaseIterable {
    case halfSecond = "0.5秒"
    case oneSecond = "1秒"
    case oneAndHalfSecond = "1.5秒"
    case twoSeconds = "2秒"
    case twoAndHalfSeconds = "2.5秒"
    case threeSeconds = "3秒"
    case fiveSeconds = "5秒"
    case never = "永不"
}

class SettingsViewModel {
    let sections: [SettingsSection]
    var selectedFormat: ImageFormat = .png
    var selectedResolution: Resolution = .large
    var selectedStopDuration: StopDuration = .twoSeconds
    
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
