//
//  PhotoView.swift
//  Queryable
//
//  Created by Mazzystar on 2022/12/26.
//

/*
See the License.txt file for this sample’s licensing information.
*/

import SwiftUI
import Photos

struct PhotoViewForMac: View {
    @AppStorage("HAS_NETWORK_PERMISSION") var HAS_NETWORK_PERMISSION: Bool = false
    // the original photo page
    var asset: PhotoAsset
    var cache: CachedImageManager?
    @State private var image: Image?
    @State private var isFavorite = false
    @State private var isLowerQuality = false
    @State private var showInfo = false
    @State private var showiCloud = false
    @State private var showSimilarImage = false
    @State private var infoIcon = "info.circle"
    @State private var imageRequestID: PHImageRequestID?
    @ObservedObject var photoSearcher: PhotoSearcher
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    private let imageSize = CGSize(width: 1024, height: 1024)
    
    var body: some View {
        VStack {
            Group {
                if let image = image {
                    ZStack {
                        ZoomableScrollView {
                            image
                                .resizable()
                                .scaledToFit()
                                .accessibilityLabel(asset.accessibilityLabel)
                            
                            if showSimilarImage {
                                if colorScheme == .dark {
                                    Text("Remove View Below")
                                        .font(.title)
                                        .padding()
                                        .frame(minWidth: 200)
                                        .foregroundColor(.black)
                                        .background(Color.white)
                                        .cornerRadius(40)
                                        .onTapGesture {
                                            showSimilarImage = false
                                        }
                                } else {
                                    Text("Remove View Below")
                                        .font(.title)
                                        .padding()
                                        .frame(minWidth: 200)
                                        .foregroundColor(.white)
                                        .background(Color.black)
                                        .cornerRadius(40)
                                        .onTapGesture {
                                            showSimilarImage = false
                                        }
                                }
                                
                                
                            } else {
                                HStack {
                                    Spacer(minLength: 400)
                                    
                                    ShareLink(item: image, preview: SharePreview(photoSearcher.searchString, image: image))
                                        .font(.title)
                                        .labelStyle(.iconOnly)
                                        .imageScale(.medium)
//                                        .symbolVariant(.fill)
                                        .buttonStyle(.plain)
                                    
                                    Spacer()
                                    
                                    if colorScheme == .dark {
                                        Text("More Similar Photos")
                                            .font(.title)
                                            .padding()
                                            .frame(minWidth: 200)
                                            .foregroundColor(.black)
                                            .background(Color.white)
                                            .cornerRadius(40)
                                            .onTapGesture {
                                                showSimilarImage = true
                                                
                                                Task {
                                                    await photoSearcher.similarPhoto(with: asset)
                                                }
                                            }
                                    } else {
                                        Text("More Similar Photos")
                                            .font(.title)
                                            .padding()
                                            .frame(minWidth: 200)
                                            .foregroundColor(.white)
                                            .background(Color.black)
                                            .cornerRadius(40)
                                            .onTapGesture {
                                                showSimilarImage = true
                                                
                                                Task {
                                                    await photoSearcher.similarPhoto(with: asset)
                                                }
                                            }
                                    }
                                    
                                    Spacer()
                                    
                                    Label("Delete", systemImage: "trash")
                                        .font(.title)
                                        .labelStyle(.iconOnly)
                                        .foregroundColor(Color.red)
                                        .onTapGesture {
                                            Task {
                                                await asset.delete()
                                                await MainActor.run {
                                                    dismiss()
                                                }
                                                await photoSearcher.deleteEmbeddingByAsset(asset: asset)
                                            }
                                        }
                                    
                                    Spacer(minLength: 400)
                                }
                                
                                
                            }
                            
                        }

                        if HAS_NETWORK_PERMISSION && self.isLowerQuality {
                            VStack {
                                Spacer()
                                HStack{
                                    Spacer()
                                    ProgressView()
                                    Spacer()
                                }
                            }
                        }
                    }
                    
                } else {
                    ProgressView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .task {
                guard image == nil, let cache = cache else { return }
                if HAS_NETWORK_PERMISSION {
                    await cache.requestOptions.isNetworkAccessAllowed = true
                }
                imageRequestID = await cache.requestImage(for: asset, targetSize: imageSize) { result in
                    Task {
                        if let result = result {
                            self.image = Image(uiImage: result.image!)
                            self.isLowerQuality = result.isLowerQuality
                            self.isFavorite = asset.isFavorite
                        }
                    }
                }
            }
            
            if showSimilarImage {
                VStack {
                    if photoSearcher.isFindingSimilarPhotos {
                        ProgressView() {
                            Text("Finding similar photos...")
                        }
                    } else {
                        SimilarPhotoCollectionViewForMac(photoSearcher: photoSearcher)
                    }
                }
            }
            
            if let image = image {
                HStack {
//                    ShareLink(item: image, preview: SharePreview(photoSearcher.searchString, image: image))
//                        .font(.system(size: 23))
//                        .labelStyle(.iconOnly)
//                    Spacer()
                    
                    if !HAS_NETWORK_PERMISSION && self.isLowerQuality {
                        Button {
                            showInfo = false
                            infoIcon = "info.circle"
                            showiCloud = !showiCloud
                            Task {
                                if self.isLowerQuality {
                                    // grant wireless data
                                    await cache!.requestOptions.isNetworkAccessAllowed = true
                                    if await cache!.requestOptions.isNetworkAccessAllowed == true {
                                        HAS_NETWORK_PERMISSION = true
                                    }
                                    
                                    imageRequestID = await cache!.requestImage(for: asset, targetSize: imageSize) { result in
                                        Task {
                                            if let result = result {
                                                self.image = Image(uiImage: result.image!)
                                                self.isLowerQuality = result.isLowerQuality
                                            }
                                        }
                                    }
                                    
                                }
                            }
                        } label: {
                            Label("iCloud", systemImage: "icloud.and.arrow.down")
                                .font(.system(size: 23))
                                .labelStyle(.iconOnly)
                        }
                        Spacer()
                    }
                    
                    if HAS_NETWORK_PERMISSION {
                        Button {
                            showInfo = false
                            infoIcon = "info.circle"
                            
                            self.isFavorite = !self.isFavorite
                            Task {
                                await asset.setIsFavorite(!asset.isFavorite)
                            }
                        } label: {
                            Label("Favorite", systemImage: self.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 23))
                                .labelStyle(.iconOnly)
                        }
                        Spacer()
                    }
                    
//                    Button {
//                        showiCloud = false
//                        showInfo = !showInfo
//                        if infoIcon == "info.circle" {
//                            infoIcon = "info.circle.fill"
//                        } else{
//                            infoIcon = "info.circle"
//                        }
//                    } label: {
//                        Label("Info", systemImage: infoIcon)
//                            .font(.system(size: 23))
//                            .labelStyle(.iconOnly)
//                    }
//                    Spacer()
                    
                }
                .padding()
                .overlay(alignment: .center) {
                    if showInfo {
                        if self.isLowerQuality {
                            VStack(alignment: .leading) {
                                Label("This photo is in iCloud.\nFor privacy, Queryable is designed to run offline. If you don't want it to have network access, you can find this photo in the album by date.", systemImage: "exclamationmark.icloud.fill")
                                    .fixedSize(horizontal: false, vertical: true)
                                Label("\(asset.phAsset?.creationDate ?? Date()).", systemImage: "calendar")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .background(Color.yellow)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                            .padding(10)
                            .offset(x: 0, y: -120)
                            
                        } else {
                            VStack(alignment: .leading) {
                                Label("This photo is stored locally.", systemImage: "checkmark.circle.fill")
                                    .fixedSize(horizontal: false, vertical: true)
                                Label("\(asset.phAsset?.creationDate ?? Date()).", systemImage: "calendar")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(10)
                            .background(Color.weakgreen)
                            .foregroundColor(.black)
                            .cornerRadius(10)
                            .padding(10)
                            .offset(x: 0, y: -90)
                        
                        }
                        
                    }
                    
                    if showiCloud {
                        VStack(alignment: .leading) {
                            Label("Allow access to wireless data to download photo from iCloud. If you have privacy concerns, you can still use Queryable offline.", systemImage: "wifi")
                                .fixedSize(horizontal: false, vertical: true)
                            Label("After authorization is complete, please exit the app and restart it.", systemImage: "arrow.clockwise")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(Color.yellow)
                        .foregroundColor(.black)
                        .cornerRadius(10)
                        .padding(10)
                        .offset(x: 0, y: -110)
//                        .offset(x: 0, y: -90)
                    }
                    
                }
            }
            
        }
        .navigationBarTitle("", displayMode: .inline)
    }
    
    private func buttonsView() -> some View {
        HStack(spacing: 60) {
//            Button {
//                Task {
//                    await asset.setIsFavorite(!asset.isFavorite)
//                }
//            } label: {
//                Label("Favorite", systemImage: asset.isFavorite ? "heart.fill" : "heart")
//                    .font(.system(size: 24))
//            }

            Text("Date: \(asset.phAsset?.creationDate ?? Date())")
            Button {
                Task {
                    await asset.delete()
                    await MainActor.run {
                        dismiss()
                    }
                    await photoSearcher.deleteEmbeddingByAsset(asset: asset)
                }
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 23))
            }
        }
        .buttonStyle(.plain)
        .labelStyle(.iconOnly)
        .padding(EdgeInsets(top: 20, leading: 30, bottom: 20, trailing: 30))
        .background(Color.secondary.colorInvert())
        .cornerRadius(15)
    }
}
