//
//  PhotoItemView.swift
//  Queryable
//
//  Created by Ke Fang on 2022/12/26.
//

/*
See the License.txt file for this sample’s licensing information.
*/

import SwiftUI
import Photos

struct PhotoItemView: View {
    // the item grid for a specific photo
    var asset: PhotoAsset
    var cache: CachedImageManager?
    var imageSize: CGSize
    
    @State private var image: Image?
    @State private var imageRequestID: PHImageRequestID?

    var body: some View {
        
        Group {
            if let image = image {
                image
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1, contentMode: .fill)
            } else {
                ProgressView()
                    .scaleEffect(0.5)
            }
        }
        .task {
            guard image == nil, let cache = cache else { return }
            imageRequestID = await cache.requestImage(for: asset, targetSize: imageSize) { result in
                Task {
                    if let result = result {
                        self.image = Image(uiImage: result.image!)
                    }
                }
            }
        }
    }
}
