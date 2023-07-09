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
        case SEARCH_RESULT_CODE.DEFAULT.rawValue:
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
        case SEARCH_RESULT_CODE.MODEL_PREPARED.rawValue:
            Text("")
        case SEARCH_RESULT_CODE.IS_SEARCHING.rawValue:
            // Searching...
            ProgressView() {
                Text("Searching...")
            }
            .padding(.top, -500)
        case SEARCH_RESULT_CODE.NEVER_INDEXED.rawValue:
            // User never searched before
            FirstTimeSearchView(photoSearcher: photoSearcher)
            
        case SEARCH_RESULT_CODE.NO_RESULT.rawValue:
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
        case SEARCH_RESULT_CODE.HAS_RESULT.rawValue:
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
            
        default:
            Text("")
        }
    }
    
}
