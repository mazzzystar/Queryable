//
//  SearchResultView.swift
//  Queryable
//
//  Created by Mazzystar on 2022/12/14.
//
import SwiftUI
import Photos


struct SearchResultsViewForMac: View {
    @Binding var goToIndexView: Bool
    @ObservedObject var photoSearcher: PhotoSearcher
//    private let imageSize = CGSize(width: 1024, height: 1024)
    
    var body: some View {
        switch photoSearcher.searchResultCode {
        case .DEFAULT:
            ProgressView() {
                Text("Loading Model...")
            }
            .padding(.top, -500)
            .onAppear {
                Task {
                    await photoSearcher.prepareModelForSearch()
                    
                    let hasAccessToPhotos = UserDefaults.standard.bool(forKey: photoSearcher.KEY_HAS_ACCESS_TO_PHOTOS)
                    if hasAccessToPhotos == true {
                        // which means I have the access to Photo Library.
                        await photoSearcher.fetchPhotos()
                    }
                }
            }
        case .MODEL_PREPARED:
            Text("")
        case .IS_SEARCHING:
            // Searching...
            ProgressView() {
                Text("Searching...")
            }
            .padding(.top, -500)
        case .NEVER_INDEXED:
            // User never searched before
            FirstTimeSearchView(photoSearcher: photoSearcher)
            
        case .NO_RESULT:
            // Really no result
            VStack {
                Text("No photos matched your query.")
                    .foregroundColor(.gray)
                    .scaledToFill()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                UpdateIndexView(goToIndexView: $goToIndexView, photoSearcher: photoSearcher)
                Spacer()
            }
            .padding(.top, -240)
        case .HAS_RESULT:
            // Has result
            VStack {
                if photoSearcher.totalUnIndexedPhotosNum > 0 {
                    UpdateIndexView(goToIndexView: $goToIndexView, photoSearcher: photoSearcher)
                }
                
                // Top 1 result
                
                ScrollView {
                    if photoSearcher.searchResultPhotoAssets.count > 0 {
                        Top1PhotoView(asset: photoSearcher.searchResultPhotoAssets[0], cache: photoSearcher.photoCollection.cache)
                        
                        PhotoCollectionViewForMac(photoSearcher: photoSearcher)
                    } else {
                        EmptyView()
                    }
                    
                }
                Spacer()
            }
            .padding(.top, -260)
        }
    }
    
}
