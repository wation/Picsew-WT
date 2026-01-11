import Foundation
import UIKit

class AutoStitchViewModel {
    private let stitchManager = AutoStitchManager.shared
    
    var images: [UIImage] = []
    var statusMessage: String = "正在加载图片..."
    var stitchedImage: UIImage?
    var offsets: [CGFloat] = [] // 图片之间的 Y 偏移量
    
    // 自动拼接图片
    func autoStitch(completion: @escaping (UIImage?, [CGFloat]?, Error?) -> Void) {
        stitchManager.autoStitch(images) { [weak self] stitchedImage, offsets, error in
            DispatchQueue.main.async {
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == "StitchWarning" {
                        // 警告：仍然保存结果
                        self?.statusMessage = "拼接完成 (部分图片未找到重合点)"
                        self?.stitchedImage = stitchedImage
                        self?.offsets = offsets ?? []
                        completion(stitchedImage, offsets, error)
                    } else {
                        // 真正错误
                        self?.statusMessage = error.localizedDescription
                        completion(nil, nil, error)
                    }
                } else if let stitchedImage = stitchedImage, let offsets = offsets {
                    self?.statusMessage = "拼接完成"
                    self?.stitchedImage = stitchedImage
                    self?.offsets = offsets
                    completion(stitchedImage, offsets, nil)
                }
            }
        }
    }
    
    // 添加图片
    func setImages(_ newImages: [UIImage]) {
        images = newImages
        statusMessage = "已导入 \(images.count) 张图片"
    }
}
