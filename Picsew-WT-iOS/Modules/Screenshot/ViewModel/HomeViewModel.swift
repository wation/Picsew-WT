import Foundation
import Photos
import UIKit

class HomeViewModel {
    var assets: [PHAsset] = []
    var selectedAssets: [PHAsset] = []
    
    func fetchAssets(completion: @escaping () -> Void) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let result = PHAsset.fetchAssets(with: .image, options: options)
        
        var fetchedAssets: [PHAsset] = []
        result.enumerateObjects { asset, _, _ in
            fetchedAssets.append(asset)
        }
        self.assets = fetchedAssets
        completion()
    }
    
    func toggleSelection(at index: Int) {
        let asset = assets[index]
        if let selectedIndex = selectedAssets.firstIndex(of: asset) {
            selectedAssets.remove(at: selectedIndex)
        } else {
            selectedAssets.append(asset)
        }
    }
    
    func isSelected(at index: Int) -> Bool {
        return selectedAssets.contains(assets[index])
    }
    
    func selectionOrder(at index: Int) -> Int? {
        if let selectedIndex = selectedAssets.firstIndex(of: assets[index]) {
            return selectedIndex + 1
        }
        return nil
    }

    func fetchSelectedImages(completion: @escaping ([UIImage]) -> Void) {
        let group = DispatchGroup()
        var images = [UIImage?](repeating: nil, count: selectedAssets.count)
        
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false
        
        // 限制请求图片的大小以提高性能和稳定性
        let targetSize = CGSize(width: 2000, height: 2000)
        
        for (index, asset) in selectedAssets.enumerated() {
            group.enter()
            PHImageManager.default().requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, _ in
                images[index] = image
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            completion(images.compactMap { $0 })
        }
    }
}
