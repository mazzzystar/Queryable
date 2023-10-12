//
//  SearchResultView.swift
//  Queryable
//
//  Created by Ke Fang on 2022/12/14.
//
import SwiftUI
import Photos

extension Color {
    static let weakgreen = Color("weakgreen")
    static let MIDORI = Color("MIDORI")
}

struct SearchResultsView: View {
    @Binding var goToIndexView: Bool
    @ObservedObject var photoSearcher: PhotoSearcher
//    private let imageSize = CGSize(width: 1024, height: 1024)
    
    var body: some View {
        switch photoSearcher.searchResultCode {
        case SEARCH_RESULT_CODE.DEFAULT.rawValue:
            ProgressView() {
                Text("Loading Model...")
            }
            .padding(.top, -UIScreen.main.bounds.height * 0.65)
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
                    .accessibilityAddTraits(.isStaticText)
                    .accessibilityValue(Text("Searching"))
            }
            .padding(.top, -UIScreen.main.bounds.height * 0.65)
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
            .padding(.top, -UIScreen.main.bounds.height * 0.3)
        case SEARCH_RESULT_CODE.HAS_RESULT.rawValue:
            // Has result
            VStack {
                if photoSearcher.totalUnIndexedPhotosNum > 0 {
                    UpdateIndexView(goToIndexView: $goToIndexView, photoSearcher: photoSearcher)
                }
                
                // Top 1 result
                
                ScrollView {
                    if photoSearcher.searchResultPhotoAssets.count > 0 {
                        NavigationLink {
                            PhotoView(asset: photoSearcher.searchResultPhotoAssets[0], cache: photoSearcher.photoCollection.cache, photoSearcher: photoSearcher)
                        } label: {
                            Top1PhotoView(asset: photoSearcher.searchResultPhotoAssets[0], cache: photoSearcher.photoCollection.cache)
                        }
                        
                        PhotoCollectionView(photoSearcher: photoSearcher)
                    } else {
                        EmptyView()
                    }
                    
                }
                Spacer()
            }
            .padding(.top, -UIScreen.main.bounds.height * 0.32)
            
        default:
            Text("")
        }
    }
    
}


struct FirstTimeSearchView: View {
    @ObservedObject var photoSearcher: PhotoSearcher
    
    var body: some View {
        VStack {
            VStack {
                
                TipsView(photoSearcher: photoSearcher)
                Spacer(minLength: 100)
                
            }
            
        }
        .padding(.top, -UIScreen.main.bounds.height * 0.32)
    }
}


import SwiftUI
import Photos

struct Top1PhotoView: View {
    let defaults = UserDefaults.standard
    // the original photo page
    var asset: PhotoAsset
    var cache: CachedImageManager?
    @State private var image: Image?
    @State private var imageRequestID: PHImageRequestID?
    @Environment(\.dismiss) var dismiss
    private let imageSize = CGSize(width: 1024, height: 1024)
    
    var body: some View {
        Group {
            if let image = image {
                VStack {
                    image
                        .resizable()
                        .scaledToFill()
                        .accessibilityLabel(asset.accessibilityLabel)
                    Text("Scroll down for more results")
                        .font(.custom("AppleSDGothicNeo-Light", fixedSize: 16))
                        .foregroundColor(.gray)
                        .scaledToFill()
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                }
                .scaledToFit()

            } else {
                ProgressView()
            }
        }
        .frame(maxWidth: UIScreen.main.bounds.width, maxHeight: .infinity)
        .ignoresSafeArea()
        .task {
            guard image == nil, let cache = cache else { return }
            if defaults.bool(forKey: "HAS_NETWORK_PERMISSION") {
                await cache.requestOptions.isNetworkAccessAllowed = true
            }
            
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




struct TipsView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var photoSearcher: PhotoSearcher
    
    var body: some View {
        VStack (alignment: .leading) {
            Label("Index your photos!", systemImage: "atom")
                .font(.title)
                .fontWeight(.semibold)
            
            Text("Photos must be indexed to be queryable.")
            
            Spacer()
            
            Group {
                HStack {
                    Label("Queryable is an offline application. It runs smoothly without a network.", systemImage: "wifi.slash")
                }
                Spacer()
                
                HStack {
                    Label("The task is performed only once. It could take a few minutes, as it will index all your photos.", systemImage: "timer")
                }
                Spacer()
                
                HStack {
                    Label("You may need to manually update the index when you have new photos.", systemImage: "arrow.clockwise")
                }
                Spacer()
            }
            
        }
        .padding()
        .background(Color.MIDORI)
        .foregroundColor(.black)
        .cornerRadius(10)
        .padding()
        
        VStack() {
            Color.clear.frame(height: 0)

            NavigationLink(destination: BuildIndexView(photoSearcher: photoSearcher)
                .onAppear {
                    Task {
                        photoSearcher.buildIndexCode = BUILD_INDEX_CODE.PHOTOS_LOADED.rawValue
                        await photoSearcher.fetchPhotos()
                        photoSearcher.buildIndexCode = BUILD_INDEX_CODE.PHOTOS_LOADED.rawValue
                    }
                }
                .onDisappear {
                    photoSearcher.buildIndexCode = BUILD_INDEX_CODE.DEFAULT.rawValue
                }
            ) {
                HStack {
                    if colorScheme == .dark {
                        Text("Get Started")
                            .font(.title)
                            .padding()
                            .frame(minWidth: 200)
                            .foregroundColor(.black)
                            .background(Color.white)
                            .cornerRadius(40)
                    } else {
                        Text("Get Started")
                            .font(.title)
                            .padding()
                            .frame(minWidth: 200)
                            .foregroundColor(.white)
                            .background(Color.black)
                            .cornerRadius(40)
                    }
                    
                }
            }
            
        }
    }
}


struct UpdateIndexView: View {
    @Binding var goToIndexView: Bool
    @ObservedObject var photoSearcher: PhotoSearcher
    
    var body: some View {
        Text("Update index for new photos")
            .accessibilityAddTraits(.isLink)
            .accessibilityHint(Text("Click to build index for new photos to make them searchable"))
            .foregroundColor(Color.weakgreen)
            .onTapGesture {
                goToIndexView = true
            }
    }
}


struct SearchResultsView_Previews: PreviewProvider {
    static var previews: some View {
        SearchResultsView(goToIndexView: .constant(false), photoSearcher: PhotoSearcher())
    }
}


import UIKit

public extension UIDevice {
    static func chipIsA13OrLater() -> Bool {
        let devicePattern = /(AppleTV|iPad|iPhone|Watch|iPod)(\d+),(\d+)/
        
        if let match = current.model.firstMatch(of: devicePattern) {
            let deviceModel = match.1
            let majorRevision = Int(match.2)!
            
            return (deviceModel == "iPhone" || deviceModel == "iPad") && majorRevision >= 12
        }

        return false
    }
    
    static let modelIsValid: Bool = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        
        func isDeviceValid(identifier: String) -> Bool {
            // swiftlint:disable:this cyclomatic_complexity
            #if os(tvOS)
            switch identifier {
            case "AppleTV5,3": return false
            case "AppleTV6,2": return false
            case "i386", "x86_64": return false
            default: return false
            }
            #elseif os(iOS)
            return true
            #endif
        }

        return isDeviceValid(identifier: identifier)
    }()

}
