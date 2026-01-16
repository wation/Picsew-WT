import Foundation

// 公共枚举定义，供所有模块使用
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
