/*
See the License.txt file for this sample’s licensing information.
*/

import Photos
import os.log

class PhotoLibrary {
    static func checkAuthorization(status: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)) async -> Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized:
            logger.debug("Photo library access authorized.")
            return true
        case .notDetermined:
            logger.debug("Photo library access not determined.")
            return await checkAuthorization(status: PHPhotoLibrary.requestAuthorization(for: .readWrite))
        case .denied:
            logger.debug("Photo library access denied.")
            return false
        case .limited:
            logger.debug("Photo library access limited.")
            return true
        case .restricted:
            logger.debug("Photo library access restricted.")
            return false
        @unknown default:
            return false
        }
    }
}

fileprivate let logger = Logger(subsystem: "com.mazzystar.Queryable", category: "PhotoLibrary")

