//
//  CachedAsyncImage.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//

import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL
    private let scale: CGFloat
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder

    init(
        url: URL,
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        if #available(iOS 15.0, *) {
            AsyncImage(
                url: url,
                scale: scale,
                content: content,
                placeholder: placeholder
            )
        } else {
            // Fallback for iOS 14 and earlier
            LegacyAsyncImage(
                url: url,
                scale: scale,
                content: content,
                placeholder: placeholder
            )
        }
    }
}

// Simpler initializer when you don't need to customize both content and placeholder
extension CachedAsyncImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    init(
        url: URL,
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping (Image) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.content = content
        self.placeholder = { ProgressView() }
    }
}

// For iOS 14 and earlier
private struct LegacyAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL
    private let scale: CGFloat
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var isLoading = true
    @State private var image: UIImage?
    
    init(
        url: URL,
        scale: CGFloat = 1.0,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = image {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .onAppear(perform: loadImage)
            }
        }
    }
    
    private func loadImage() {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let loadedImage = UIImage(data: data) else {
                return
            }
            
            DispatchQueue.main.async {
                self.image = loadedImage
                self.isLoading = false
            }
        }.resume()
    }
}
