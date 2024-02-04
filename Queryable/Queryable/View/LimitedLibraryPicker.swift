//
//  LimitedLibraryPicker.swift
//  Queryable
//
//  Created by Jaden Geller on 10/30/23.
//

import SwiftUI
import PhotosUI

struct LimitedLibraryPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIViewController {
        .init()
    }
    
    class Coordinator {
        var isPresented = false
    }
    func makeCoordinator() -> Coordinator {
        .init()
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {
        if isPresented, !context.coordinator.isPresented {
            Task {
                context.coordinator.isPresented = true
                await PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
                context.coordinator.isPresented = false
                await MainActor.run { isPresented = false }
            }
        }
        else if !isPresented, context.coordinator.isPresented {
            Task {
                await MainActor.run { isPresented = true }
            }
        }
    }
}

extension View {
    func limitedLibraryPicker(isPresented: Binding<Bool>) -> some View {
        overlay(LimitedLibraryPicker(isPresented: isPresented))
    }
}
