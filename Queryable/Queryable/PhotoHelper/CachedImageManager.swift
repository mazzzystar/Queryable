/*
See the License.txt file for this sample’s licensing information.
*/

import UIKit
import Photos
import SwiftUI
import os.log

actor CachedImageManager {
    
    private let imageManager = PHCachingImageManager()
    
    private var imageContentMode = PHImageContentMode.aspectFit
    
    enum CachedImageManagerError: LocalizedError {
        case error(Error)
        case cancelled
        case failed
    }
    
    private var cachedAssetIdentifiers = [String : Bool]()
    
    lazy var requestOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .opportunistic
        return options
    }()
    
    init() {
        imageManager.allowsCachingHighQualityImages = false
    }
    
    var cachedImageCount: Int {
        cachedAssetIdentifiers.keys.count
    }
    
    func startCaching(for assets: [PhotoAsset], targetSize: CGSize) {
        let phAssets = assets.compactMap { $0.phAsset }
        phAssets.forEach {
            cachedAssetIdentifiers[$0.localIdentifier] = true
        }
        imageManager.startCachingImages(for: phAssets, targetSize: targetSize, contentMode: imageContentMode, options: requestOptions)
    }

    func stopCaching(for assets: [PhotoAsset], targetSize: CGSize) {
        let phAssets = assets.compactMap { $0.phAsset }
        phAssets.forEach {
            cachedAssetIdentifiers.removeValue(forKey: $0.localIdentifier)
        }
        imageManager.stopCachingImages(for: phAssets, targetSize: targetSize, contentMode: imageContentMode, options: requestOptions)
    }
    
    func stopCaching() {
        imageManager.stopCachingImagesForAllAssets()
    }
    
    @discardableResult
    func requestImage(for asset: PhotoAsset, targetSize: CGSize, completion: @escaping ((image: UIImage?, isLowerQuality: Bool)?) -> Void) -> PHImageRequestID? {
        guard let phAsset = asset.phAsset else {
            completion(nil)
            return nil
        }
        
        let requestID = imageManager.requestImage(for: phAsset, targetSize: targetSize, contentMode: imageContentMode, options: requestOptions) { image, info in
            if let error = info?[PHImageErrorKey] as? Error {
                logger.error("CachedImageManager requestImage error: \(error.localizedDescription)")
                completion(nil)
            } else if let cancelled = (info?[PHImageCancelledKey] as? NSNumber)?.boolValue, cancelled {
                logger.debug("CachedImageManager request canceled")
                completion(nil)
            } else if let image = image {
                let isLowerQualityImage = (info?[PHImageResultIsDegradedKey] as? NSNumber)?.boolValue ?? false
                let result = (image: image, isLowerQuality: isLowerQualityImage)
                completion(result)
            } else {
                completion(nil)
            }
        }
        return requestID
    }
    
    func cancelImageRequest(for requestID: PHImageRequestID) {
        imageManager.cancelImageRequest(requestID)
    }
}

fileprivate let logger = Logger(subsystem: "com.apple.swiftplaygroundscontent.capturingphotos", category: "CachedImageManager")

