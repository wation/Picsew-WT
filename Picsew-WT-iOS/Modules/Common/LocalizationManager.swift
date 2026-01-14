import Foundation

class LocalizationManager {
    static let shared = LocalizationManager()
    
    private init() {}
    
    // 获取本地化字符串
    func localizedString(for key: String) -> String {
        return NSLocalizedString(key, tableName: nil, bundle: Bundle.main, value: "", comment: "")
    }
    
    // 获取当前语言
    func currentLanguage() -> String {
        return Locale.current.languageCode ?? "en"
    }
    
    // 支持的语言列表
    func supportedLanguages() -> [String] {
        return ["en", "zh-Hans", "zh-Hant", "ja", "ko", "es", "pt"]
    }
}

// 扩展String，添加本地化方法
extension String {
    var localized: String {
        return LocalizationManager.shared.localizedString(for: self)
    }
}
