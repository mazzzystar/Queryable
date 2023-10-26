//
//  SearchBarView.swift
//  Queryable
//
//  Created by Ke Fang on 2022/12/14.
//

import SwiftUI

struct SearchBarView: View {
    @FocusState private var inputFocused: Bool
    @ObservedObject var photoSearcher: PhotoSearcher
    @State var searchText: String = ""
    private let showString = ["My love", "Dark night room with a lamp", "Snow outside the window", "Deep blue", "Cute kitten", "Photos of our gathering", "Beach, waves, sunset", "In car view, car on the road", "Screen display of traffic info", "Selfie in front of mirror", "Cheers"].randomElement()
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .accessibilityAddTraits(.isImage)
                .accessibilityHint(Text("An icon, no actual usage"))
//            TextField("Input here to search Photos", text: $searchText)
            TextField("\"\(NSLocalizedString(showString ?? "My love", comment: ""))\"", text: $searchText)
//            TextField("Input text here, e.g. \"We fell in love\"", text: $searchText)
                .modifier(TextFieldClearButton(photoSearcher: photoSearcher, inputFocused: $inputFocused, text: $searchText))
                .multilineTextAlignment(.leading)
                .focused($inputFocused)
                .accessibilityAddTraits(.isSearchField)
                .accessibilityLabel(Text("Text Field"))
                .accessibilityHint(Text("Input your sentences here, then press enter"))
                .onSubmit {
                    print("Searching...")
                    Task {
                        await photoSearcher.search(with: searchText)
                    }
                }
                .submitLabel(.search)
        }
    }
    
}


struct TextFieldClearButton: ViewModifier {
    @ObservedObject var photoSearcher: PhotoSearcher
    var inputFocused: FocusState<Bool>.Binding
    @Binding var text: String
    
    func body(content: Content) -> some View {
        HStack {
            content
            if !text.isEmpty {
                Button(
                    action: {
                        self.text = ""
                        inputFocused.wrappedValue = true
                        photoSearcher.searchResultCode = .MODEL_PREPARED
                    },
                    label: {
                        Image(systemName: "delete.left")
                            .foregroundColor(Color(UIColor.opaqueSeparator))
                    }
                )
            }
        }
    }
    
}

struct SearchBarView_Previews: PreviewProvider {
    static var previews: some View {
        SearchBarView(photoSearcher: PhotoSearcher())
    }
}
