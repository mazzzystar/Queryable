//
//  ContentView.swift
//  Queryable
//
//  Created by Ke Fang on 2022/12/14.
//

import SwiftUI

struct ContentView: View {
    @State private var goToIndexView = false
    @ObservedObject var photoSearcher = PhotoSearcher()
    
    var body: some View {
        NavigationStack {
            ZStack {
                switch UIDevice.current.userInterfaceIdiom {
                case .phone, .pad:
                    VStack {
                        Form {
                            SearchBarView(photoSearcher: photoSearcher)
                        }
                        SearchResultsView(goToIndexView: $goToIndexView, photoSearcher: photoSearcher)
                        Spacer()
                    }
                    
                case .mac, .unspecified, .tv, .carPlay:
                    VStack {
                        HStack {
                            Spacer(minLength: 300)
                            Form {
                                SearchBarView(photoSearcher: photoSearcher)
                                    .frame(height: 45)
                                    .font(.title2)
                            }
                            Spacer(minLength: 300)
                        }
                        
                        HStack {
                            Spacer(minLength: 200)
                            SearchResultsViewForMac(goToIndexView: $goToIndexView, photoSearcher: photoSearcher)
                                .font(.title2)
                            
                            Spacer(minLength: 200)
                        }
                        
                        Spacer()
                    }
                    
                @unknown default:
                    VStack {
                        Form {
                            SearchBarView(photoSearcher: photoSearcher)
                        }
                        SearchResultsView(goToIndexView: $goToIndexView, photoSearcher: photoSearcher)
                        Spacer()
                    }
                }
                
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbar() {
                ToolbarItemGroup {
                    NavigationLink(destination: ConfigView().environmentObject(photoSearcher)) {
                        Label("Config", systemImage: "gearshape")
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .accessibilityLabel(Text("Config Button"))
                            .accessibilityHint(Text("About Queryable, privacy concerns and feedback concat"))
                    }
                }
            }
            .navigationTitle("Queryable")
            .accessibilityAddTraits(.isHeader)
            .navigationDestination(isPresented: $goToIndexView) {
                BuildIndexView(photoSearcher: photoSearcher)
            }
            .ignoresSafeArea(.keyboard)
        }
        .accentColor(.weakgreen)
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(photoSearcher: PhotoSearcher())
    }
}
