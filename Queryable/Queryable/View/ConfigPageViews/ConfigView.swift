//
//  ConfigPage.swift
//  Queryable
//
//  Created by Ke Fang on 2023/02/01.
//
import SwiftUI
import UniformTypeIdentifiers

struct ConfigView: View {
    @State var showAboutText: Bool = false
    @State var showAlbumPrivacyText: Bool = false
    @State var showCrashReportText: Bool = false
    @State var showCleanCache: Bool = false
    @State var showTOPK_SIMSlider: Bool = false
    @EnvironmentObject var photoSearcher: PhotoSearcher
    @State private var sliderValue: Double = 120

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("User Guide and Feedback")) {
                    Label("About Queryable", systemImage: "book")
                        .onTapGesture {
                            withAnimation {
                                showAboutText.toggle()
                            }
                        }

                    if showAboutText {
                        Text("Queryable is a large language model (**LLMs**) that runs entirely locally. Thanks to its powerful understanding of images and text, you can easily find a particular photo from albums using any textual description related to the content of the photo, just like finding a needle in a haystack.\n\nUnlike other apps, Queryable supports complex, long descriptions: more precise descriptions yield more reliable results.\n\nQueryable supports English, French, German, Spanish and Italian input, but English works best.")
                            .foregroundColor(.gray)
                    }


                    Label("Album Privacy Concerns", systemImage: "photo")
                        .onTapGesture {
                            withAnimation {
                                showAlbumPrivacyText.toggle()
                            }
                        }
                    
                    if showAlbumPrivacyText {
                        Text("Queryable cares about your album privacy. \n\nThis is not just a promise: Queryable avoids all situations that require network connection and you can even run it smoothly under **flight mode**.\n\nYou will find that it **does not request your network permission**, and thus it is impossible to upload your album data to anywhere outside your phone.\n\nIn the latest version of Queryable, users are allowed to download iCloud photos. When the photo stored in iCloud and you click the download button, will the network request pop up. You can still refuse and run smoothly.\n\nSome specific compromises made because of offline:\n- Models are built into the app rather than downloaded online.\n- Paid instead of free + in-app purchase, the latter requires network.\n- Photos do not show location information, as this requires network.\n- The design of \"Review the App\" below.\n- ...\n\nThe creator of Queryable values privacy as much as you do.")
                            .foregroundColor(.gray)
                    }
                    
                    Label("Number of Results", systemImage: "circle.grid.2x1.right.filled")
                        .onTapGesture {
                            withAnimation {
                                showTOPK_SIMSlider.toggle()
                            }
                        }
                    
                    if showTOPK_SIMSlider {
                        Slider(value: $sliderValue, in: 10...1000, step: 10)
                            .padding(.horizontal)
                            .accentColor(.primary)
                            .labelsHidden()
                            .onChange(of: sliderValue) { newValue in
                                photoSearcher.TOPK_SIM = Int(newValue)
                            }
                        Text("Display number of results: \(photoSearcher.TOPK_SIM)")
                            .foregroundColor(.gray)
                    }

                    Label("Crashes & Feedback", systemImage: "ant")
                        .onTapGesture {
                            withAnimation {
                                showCrashReportText.toggle()
                            }
                        }

                    if showCrashReportText {
                        Text("Queryable runs on the latest Core ML framework, some devices may experience crashes or abnormal search results.\n\nKnown unsupported devices include: iPhone X/Xs, as well as iPads older than the **A13** chip.\n\nIf your device meets the requirements but still crashes, try the following:\n- Kill apps with high memory usage.\n- Turn off low power mode and try again.\n\nIf crashes still occur or if you have any suggestions, please contact me via:")
                            .foregroundColor(.gray)
                    }


                    Link(destination: URL(string: "https://apps.apple.com/us/app/queryable/id1661598353?platform=iphone")!, label:
                            {
                        Label("Review the App", systemImage: "star")
                    })

                }

                Section(header: Text("Feedback")) {
                    Link(destination: URL(string: NSLocalizedString("https://discord.com/invite/R3wNsqq3v5", comment: "Discord URL"))!, label: {
                        
                            HStack {
                                Image("DiscordIcon")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 36, height: 36)
                                    .shadow(radius: 2)
                                
                                Text("Discord")
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("discord/R3wNsqq3v5", comment: "Discord"))
                                    .foregroundColor(.gray)
                            }
                        })
                    .foregroundColor(Color.primary)
                    
                    Link(destination: URL(string: NSLocalizedString("https://twitter.com/immazzystar", comment: "Twitter URL"))!, label: {
                        
                            HStack {
                                Image("TwitterAvatar")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 0.3))
                                
                                Text("Twitter")
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("twitter.com/immazzystar", comment: "Twitter"))
                                    .foregroundColor(.gray)
                            }
                        })
                    .foregroundColor(Color.primary)
                    
                    Link(destination: URL(string: NSLocalizedString("https://github.com/mazzzystar/Queryable/issues", comment: "Twitter URL"))!, label: {
                        
                            HStack {
                                Image("GitHub")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(Color.gray, lineWidth: 0.3))
                                
                                Text("Github")
                                    .foregroundColor(.primary)
                                Text(NSLocalizedString("github/Queryable", comment: "Github"))
                                    .foregroundColor(.gray)
                            }
                        })
                    .foregroundColor(Color.primary)
                    
                }
                
                Section(header: Text("More App by This Developer")) {
                    Link(destination: URL(string: NSLocalizedString("https://apps.apple.com/us/app/do-not-type/id6449760006", comment: "DoNotType app URL"))!, label: {
                        
                        HStack {
                            Image("DoNotType")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Text(NSLocalizedString("Do Not Type", comment: "DNT app name"))
                        }
                    })
                    .foregroundColor(Color.primary)
                    
                    Link(destination: URL(string: NSLocalizedString("https://apps.apple.com/us/app/id6447748965?platform=iphone", comment: "Queryable app URL"))!, label: {
                        
                        HStack {
                            Image("Dolores")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Text(NSLocalizedString("Dolores: Your Virtual Friend", comment: "Dolores app name"))
                        }
                    })
                    .foregroundColor(Color.primary)
                    
                    Link(destination: URL(string: NSLocalizedString("https://apps.apple.com/us/app/whisper-notes/id6447090616?platform=iphone", comment: "Queryable app URL"))!, label: {
                        
                        HStack {
                            Image("WhisperNotes")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Text(NSLocalizedString("Whisper Notes: Text to Speech", comment: "Whisper Notes app name"))
                        }
                    })
                    .foregroundColor(Color.primary)
                    
                    Link(destination: URL(string: NSLocalizedString("https://apps.apple.com/us/app/id1668297986?platform=iphone", comment: "Queryable app URL"))!, label: {
                        
                        HStack {
                            Image("MemeSearch")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Text(NSLocalizedString("MemeSearch: Reddit Meme Finder", comment: "MemeSearch app name"))
                        }
                    })
                    .foregroundColor(Color.primary)
                }
                    

            }
        }.onAppear {
            sliderValue = Double(photoSearcher.TOPK_SIM)
        }
        .navigationBarTitle("", displayMode: .inline)
    }
}

struct ConfigView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigView()
    }
}
