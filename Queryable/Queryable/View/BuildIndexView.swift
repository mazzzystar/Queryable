//
//  BuildIndexView.swift
//  Queryable
//
//  Created by Ke Fang on 2022/12/16.
//

import SwiftUI

struct BuildIndexView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var photoSearcher: PhotoSearcher

    var body: some View {
        switch photoSearcher.buildIndexCode {
        case BUILD_INDEX_CODE.DEFAULT.rawValue:
            Text("")
        case BUILD_INDEX_CODE.LOADING_PHOTOS.rawValue:
            ProgressView() {
                Text("Loading Photos...")
            }
        case BUILD_INDEX_CODE.PHOTOS_LOADED.rawValue:
            StartBuildView(photoSearcher: photoSearcher)
            
        case BUILD_INDEX_CODE.LOADING_MODEL.rawValue:
            ProgressView() {
                Text("Loading Model...")
            }
            .onAppear {
                Task {
                    await photoSearcher.loadImageIncoder()
                }
            }
        case BUILD_INDEX_CODE.IS_BUILDING_INDEX.rawValue:
            BuildingIndexView(photoSearcher: photoSearcher)
                .onAppear {
                    Task {
                        UIApplication.shared.isIdleTimerDisabled = true
                        await photoSearcher.buildIndex()
                        UIApplication.shared.isIdleTimerDisabled = false
                    }
                }
        case BUILD_INDEX_CODE.BUILD_FINISHED.rawValue:
            BuildFinishView(photoSearcher: photoSearcher)
        default:
            Text("")
            
        }
        
    }
}


struct StartBuildView: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var photoSearcher: PhotoSearcher
    
    var body: some View {
        VStack {
            let start = "Total"
            let end = "Photos need to be indexed."
            Text("\(NSLocalizedString(start, comment: "")) \(photoSearcher.totalUnIndexedPhotosNum) \(NSLocalizedString(end, comment: ""))")
            // Prevent Low Power Mode to avoid crash.
            if ProcessInfo.processInfo.isLowPowerModeEnabled && photoSearcher.totalUnIndexedPhotosNum > 300 {
                // Low Power Mode is enabled. Start reducing activity to conserve energy.
                Text("* Please turn off Low Power Mode when build index.")
                    .foregroundColor(.red)
                    .scaledToFit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            } else {
                // Low Power Mode is not enabled.
                
            }
            
            HStack {
                if colorScheme == .dark {
                    Text("Index Photos")
                        .font(.title)
                        .padding()
                        .frame(minWidth: 200)
                        .foregroundColor(.black)
                        .background(Color.white)
                        .cornerRadius(40)
                } else {
                    Text("Index Photos")
                        .font(.title)
                        .padding()
                        .frame(minWidth: 200)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(40)
                }
            }
            .accessibilityHint("Press button to build index for all your photos, this may takes a few minutes, depending on the number of your unindexed photos")
            .onTapGesture {
                if photoSearcher.totalUnIndexedPhotosNum > 0 {
                    photoSearcher.changeState(from: BUILD_INDEX_CODE.PHOTOS_LOADED.rawValue, to: BUILD_INDEX_CODE.LOADING_MODEL.rawValue)
                } else {
                    photoSearcher.changeState(from: BUILD_INDEX_CODE.PHOTOS_LOADED.rawValue, to: BUILD_INDEX_CODE.BUILD_FINISHED.rawValue)
                }
            }
        }
    }
}

struct BuildingIndexView: View {
    @ObservedObject var photoSearcher: PhotoSearcher
    
    var body: some View {
        VStack {
            Image(uiImage: photoSearcher.curShowingPhoto)
                .resizable()
                .scaledToFit()
            
            let end = "Photos have been indexed."
            Text("\(photoSearcher.curIndexingNums+1)/\(photoSearcher.totalUnIndexedPhotosNum) \(NSLocalizedString(end, comment: ""))")
            Text("Task runs entirely locally. Do not operate until completed.")
                .foregroundColor(.gray)
                .scaledToFit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
        }
        
    }
}


struct BuildFinishView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject var photoSearcher: PhotoSearcher
    
    var isDarkMode: Bool {
        return colorScheme == .dark
    }
    
    var body: some View {
        VStack {
            Text("Build Finished.")
                .accessibilityHint(Text("All photos have been indexed"))
            HStack {
                Text("Start Search")
                    .font(.title)
                    .padding()
                    .frame(minWidth: 200)
                    .foregroundColor(isDarkMode ? .black : .white)
                    .background(isDarkMode ? .white : .black)
                    .cornerRadius(40)
            }
            .accessibilityHint(Text("All photos have been indexed, click to search"))
            .onTapGesture {
                self.presentationMode.wrappedValue.dismiss()
                self.photoSearcher.searchResultCode = .MODEL_PREPARED
                if !self.photoSearcher.searchString.isEmpty {
                    Task {
                        self.photoSearcher.searchResultCode = .IS_SEARCHING
                        await self.photoSearcher.search(with: self.photoSearcher.searchString)
                    }
                }
            }
        }
    }
}

struct BuildIndexView_Previews: PreviewProvider {
    static var previews: some View {
        BuildIndexView(photoSearcher: PhotoSearcher())
    }
}
