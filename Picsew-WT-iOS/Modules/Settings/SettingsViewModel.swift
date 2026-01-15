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
    case large = "large"
    case medium = "medium"
    case small = "small"
    
    var localizedString: String {
        return NSLocalizedString(rawValue, comment: "Resolution option")
    }
}

enum StopDuration: String, CaseIterable {
    case halfSecond = "half_second"
    case oneSecond = "one_second"
    case oneAndHalfSecond = "one_and_half_second"
    case twoSeconds = "two_seconds"
    case twoAndHalfSeconds = "two_and_half_seconds"
    case threeSeconds = "three_seconds"
    case fiveSeconds = "five_seconds"
    case never = "never"
    
    var localizedString: String {
        return NSLocalizedString(rawValue, comment: "Stop duration option")
    }
}

class SettingsViewModel {
    let sections: [SettingsSection]
    var selectedFormat: ImageFormat = .png
    var selectedResolution: Resolution = .large
    var selectedStopDuration: StopDuration = .twoSeconds
    
    init() {
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
