//
//  PhotoView.swift
//  Queryable
//
//  Created by Ke Fang on 2022/12/26.
//

/*
See the License.txt file for this sample’s licensing information.
*/

import SwiftUI
import Photos

struct PhotoView: View {
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
    private let imageSize = CGSize(width: 1024, height: 1024)
    
    var body: some View {
        VStack {
            Group {
                if let image = image {
                    ZStack {
                        VStack {
                            Spacer()
                            
                            ZoomableScrollView {
                                image
                                    .resizable()
                                    .scaledToFit()
                                    .accessibilityLabel(asset.accessibilityLabel)
                            }
                            Text("\(asset.phAsset?.creationDate?.formatted(.dateTime.weekday().day().month().year().hour().minute().second()) ?? Date().formatted(.dateTime.day().month().year()) )")
                                .font(.custom("AppleSDGothicNeo-Light", fixedSize: 16))
                            
                            Spacer()
                            
                            if showSimilarImage {
                                Label("Swipe down to remove view below", systemImage: "arrow.down")
                                    .font(.custom("AppleSDGothicNeo-Light", fixedSize: 16))
                                    .foregroundColor(.gray)
                                    .scaledToFit()
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                                
                            } else {
                                Label("Swipe up to search with this photo", systemImage: "arrow.up")
                                    .font(.custom("AppleSDGothicNeo-Light", fixedSize: 16))
                                    .accessibilityAddTraits(.isButton)
                                    .accessibilityHint(Text("You can search with this photo to get more similar photos"))
                                    .foregroundColor(.gray)
                                    .scaledToFit()
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                            
                        }
                        .gesture(DragGesture(minimumDistance: 3.0, coordinateSpace: .local)
                            .onEnded { value in
                                print(value.translation)
                                switch(value.translation.width, value.translation.height) {
                                case (...0, -30...30): do {
                                    print("left swipe");
                                }
                                case (0..., -30...30):  do {
                                    print("right swipe");
                                }
                                case (-100...100, ...0): do {
                                    print("up swipe")
                                    
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    
                                    showSimilarImage = true
                                    Task {
                                        await photoSearcher.similarPhoto(with: asset)
                                    }
                                }
                                case (-100...100, 0...):  do {
                                    print("down swipe")
                                    
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    
                                    if showSimilarImage {
                                        showSimilarImage = false
                                    } else {
                                        dismiss()
                                    }

                                }
                                    default:  print("no clue")
                                }
                            }
                        )
                        
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
//            .ignoresSafeArea()
//            .background(Color.secondary)
//            .navigationTitle("Photo")
//            .navigationBarTitleDisplayMode(.inline)
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
                                .font(.custom("AppleSDGothicNeo-Light", fixedSize: 16))
                        }
                    } else {
                        SimilarPhotoCollectionView(photoSearcher: photoSearcher)
                    }
                }
            }
            
            if let image = image {
                HStack {
                    ShareLink(item: image, preview: SharePreview(photoSearcher.searchString, image: image))
                        .font(.system(size: 23))
                        .labelStyle(.iconOnly)
                    Spacer()
                    
                    
                    // TODO: add a function that let user add top result for a keyword.
                    /**
                    Button {
                        Task {
                            await asset.setIsFavorite(!asset.isFavorite)
                        }
                    } label: {
                        Label("star", systemImage: asset.hasStared ? "star.fill" : "star")
                            .font(.system(size: 23))
                            .labelStyle(.iconOnly)
                    }
                    Spacer()
                     */
                    
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
                    
                    Button {
                        showiCloud = false
                        showInfo = !showInfo
                        if infoIcon == "info.circle" {
                            infoIcon = "info.circle.fill"
                        } else{
                            infoIcon = "info.circle"
                        }
                    } label: {
                        Label("Info", systemImage: infoIcon)
                            .font(.system(size: 23))
                            .labelStyle(.iconOnly)
                    }
                    Spacer()
                    
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
                            .labelStyle(.iconOnly)
                    }
                }
                .padding()
                .overlay(alignment: .center) {
                    if showInfo {
                        if self.isLowerQuality {
                            VStack(alignment: .leading) {
                                Label("This photo is in iCloud.\nFor privacy, Queryable is designed to run offline. If you don't want it to have network access, you can find this photo in the album by date.", systemImage: "exclamationmark.icloud.fill")
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

struct ZoomableScrollView<Content: View>: UIViewRepresentable {
  private var content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  func makeUIView(context: Context) -> UIScrollView {
    // set up the UIScrollView
    let scrollView = UIScrollView()
    scrollView.delegate = context.coordinator  // for viewForZooming(in:)
    scrollView.maximumZoomScale = 20
    scrollView.minimumZoomScale = 1
    scrollView.bouncesZoom = true

    // create a UIHostingController to hold our SwiftUI content
    let hostedView = context.coordinator.hostingController.view!
    hostedView.translatesAutoresizingMaskIntoConstraints = true
    hostedView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    hostedView.frame = scrollView.bounds
    scrollView.addSubview(hostedView)

    return scrollView
  }

  func makeCoordinator() -> Coordinator {
    return Coordinator(hostingController: UIHostingController(rootView: self.content))
  }

  func updateUIView(_ uiView: UIScrollView, context: Context) {
    // update the hosting controller's SwiftUI content
    context.coordinator.hostingController.rootView = self.content
    assert(context.coordinator.hostingController.view.superview == uiView)
  }

  // MARK: - Coordinator

  class Coordinator: NSObject, UIScrollViewDelegate {
    var hostingController: UIHostingController<Content>

    init(hostingController: UIHostingController<Content>) {
      self.hostingController = hostingController
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
      return hostingController.view
    }
  }
}
