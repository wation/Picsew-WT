import Foundation
import UIKit

class AutoStitchViewModel {
    private let stitchManager = AutoStitchManager.shared
    
    var images: [UIImage] = []
    var statusMessage: String = "正在加载图片..."
    var stitchedImage: UIImage?
    var offsets: [CGFloat] = [] // 每一张图在画布上的起始 Y 坐标
    var bottomStartOffsets: [CGFloat] = [] // 每一张图自身开始显示的 Y 坐标（用于裁掉 header）
    var matchedIndices: [Int] = []
    
    // 自动拼接图片
    func autoStitch(forceManual: Bool = false, completion: @escaping (UIImage?, [CGFloat]?, [CGFloat]?, [Int]?, Error?) -> Void) {
        stitchManager.autoStitch(images, forceManual: forceManual) { [weak self] stitchedImage, offsets, bottomStarts, matched, workingImages, error in
            DispatchQueue.main.async {
                if let workingImages = workingImages {
                    self?.images = workingImages
                }
                
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == "StitchWarning" {
                        // 警告：仍然保存结果
                        self?.statusMessage = NSLocalizedString("stitch_warning_auto_to_manual", comment: "")
                        self?.stitchedImage = stitchedImage
                        self?.offsets = offsets ?? []
                        self?.bottomStartOffsets = bottomStarts ?? []
                        self?.matchedIndices = matched ?? []
                        completion(stitchedImage, offsets, bottomStarts, matched, error)
                    } else {
                        // 真正错误
                        self?.statusMessage = error.localizedDescription
                        completion(nil, nil, nil, nil, error)
                    }
                } else if let stitchedImage = stitchedImage, let offsets = offsets {
                    self?.statusMessage = "拼接完成"
                    self?.stitchedImage = stitchedImage
                    self?.offsets = offsets
                    self?.bottomStartOffsets = bottomStarts ?? []
                    self?.matchedIndices = matched ?? []
                    completion(stitchedImage, offsets, bottomStarts, matched, nil)
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
