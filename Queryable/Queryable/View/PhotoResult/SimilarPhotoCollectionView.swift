//
//  PhotosCollectionView.swift
//  Queryable
//
//  Created by Ke Fang on 2022/12/26.
//

/*
See the License.txt file for this sample’s licensing information.
*/

import SwiftUI
import os.log

struct SimilarPhotoCollectionView: View {
    //all photos grid
    @ObservedObject var photoSearcher: PhotoSearcher
    
    @Environment(\.displayScale) private var displayScale
        
    private static let itemSpacing = 2.0
    private static let itemCornerRadius = 15.0
    private static let itemSize = CGSize(width: 108, height: 108)
    
    private var imageSize: CGSize {
        return CGSize(width: Self.itemSize.width * min(displayScale, 3), height: Self.itemSize.height * min(displayScale, 3))
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: itemSize.width, maximum: itemSize.height), spacing: itemSpacing)
    ]
    
    // Somewhere in my view struct
    private let threeColumnGrid = [
        GridItem(.flexible(minimum: 40), spacing: itemSpacing),
        GridItem(.flexible(minimum: 40), spacing: itemSpacing),
        GridItem(.flexible(minimum: 40), spacing: itemSpacing),
    ]
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: threeColumnGrid, alignment: .center, spacing: SimilarPhotoCollectionView.itemSpacing) {
                ForEach(photoSearcher.similarPhotoAssets) { asset in
                    GeometryReader { gr in
                        NavigationLink {
                            PhotoView(asset: asset, cache: photoSearcher.photoCollection.cache, photoSearcher: photoSearcher)
                        } label: {
                            photoItemView(asset: asset)
                                .scaledToFill()
                                .frame(height: gr.size.height)
                        }
                    }
                    .clipped()
                    .aspectRatio(1, contentMode: .fit)
                }
            }
            
//            LazyVGrid(columns: columns, spacing: Self.itemSpacing) {
//                ForEach(photoSearcher.similarPhotoAssets) { asset in
//                    NavigationLink {
//                        PhotoView(asset: asset, cache: photoSearcher.photoCollection.cache, photoSearcher: photoSearcher)
//                    } label: {
//                        photoItemView(asset: asset)
//                    }
//                    .buttonStyle(.borderless)
//                    .accessibilityLabel(asset.accessibilityLabel)
//                }
//            }
//            .padding([.vertical], Self.itemSpacing)
        }
//        .navigationTitle(photoSearcher.photoCollection.albumName ?? "Gallery")
//        .navigationBarTitleDisplayMode(.inline)
//        .statusBar(hidden: false)
    }
    
    private func photoItemView(asset: PhotoAsset) -> some View {
        PhotoItemView(asset: asset, cache: photoSearcher.photoCollection.cache, imageSize: imageSize)
//            .frame(width: Self.itemSize.width, height: Self.itemSize.height)
//            .clipped()
//            .cornerRadius(Self.itemCornerRadius)
            .overlay(alignment: .bottomLeading) {
                if asset.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 1)
                        .font(.callout)
                        .offset(x: 4, y: -4)
                }
            }
            .onAppear {
                Task {
                    await photoSearcher.photoCollection.cache.startCaching(for: [asset], targetSize: imageSize)
                }
            }
            .onDisappear {
                Task {
                    await photoSearcher.photoCollection.cache.stopCaching(for: [asset], targetSize: imageSize)
                }
            }
    }
}
