//
//  CachedNetworkImage.swift
//  Aldo
//
//  Created by Andrew Katsifis on 3/5/25.
//

import SwiftUI

struct CachedNetworkImage<Content: View, Placeholder: View>: View {
    private let url: URL
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    
    @State private var isLoading = true
    @State private var loadedImage: UIImage? = nil
    @State private var loadError: Error? = nil
    
    /// Initialize with content and placeholder
    /// - Parameters:
    ///   - url: The image URL to load
    ///   - content: View builder for the successful image loading state
    ///   - placeholder: View builder for the loading state
    init(
        url: URL,
        @ViewBuilder content: @escaping (Image) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }
    
    var body: some View {
        Group {
            if let image = loadedImage {
                content(Image(uiImage: image))
            } else if let _ = loadError {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
            } else {
                placeholder()
            }
        }
        .onAppear(perform: loadImage)
    }
    
    private func loadImage() {
        // Skip if image already loaded
        guard loadedImage == nil, loadError == nil else { return }
        
        isLoading = true
        
        // First check the cache
        let urlString = url.absoluteString
        if let cachedImage = ImageCache.shared.retrieveImage(forKey: urlString) {
            loadedImage = cachedImage
            isLoading = false
            return
        }
        
        // If not in cache, download the image
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let error = error {
                    loadError = error
                    print("Error loading image from \(url): \(error)")
                    return
                }
                
                guard let data = data, let downloadedImage = UIImage(data: data) else {
                    loadError = NSError(domain: "CachedNetworkImage", code: 101, userInfo: [NSLocalizedDescriptionKey: "Failed to convert data to image"])
                    return
                }
                
                // Store in cache for faster access next time
                ImageCache.shared.storeImage(downloadedImage, forKey: urlString)
                
                // Update state with loaded image
                loadedImage = downloadedImage
            }
        }.resume()
    }
}

// MARK: - Convenience initializers

extension CachedNetworkImage where Placeholder == ProgressView<EmptyView, EmptyView> {
    /// Initialize with just content, using a progress view as placeholder
    init(url: URL, @ViewBuilder content: @escaping (Image) -> Content) {
        self.init(url: url, content: content, placeholder: { ProgressView() })
    }
}

// MARK: - Drop-in replacement for SwiftUI AsyncImage

/// A drop-in replacement for SwiftUI AsyncImage that uses the image cache
struct CachedAsyncImage<Content: View>: View where Content: View {
    private let url: URL?
    private let scale: CGFloat
    private let content: ((AsyncImagePhase) -> Content)?
    
    init(url: URL?, scale: CGFloat = 1) where Content == Image {
        self.url = url
        self.scale = scale
        self.content = nil
    }
    
    init<I, P>(url: URL?, scale: CGFloat = 1, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping () -> P) where Content == _ConditionalContent<I, P>, I: View, P: View {
        self.url = url
        self.scale = scale
        self.content = { phase in
            if let image = phase.image {
                return ViewBuilder.buildEither(first: content(image)) as Content
            } else {
                return ViewBuilder.buildEither(second: placeholder()) as Content
            }
        }
    }
    
    init(url: URL?, scale: CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.url = url
        self.scale = scale
        self.content = content
    }
    
    var body: some View {
        if let url = url {
            if let content = content {
                Group {
                    CachedNetworkImage(
                        url: url,
                        content: { image in
                            content(.success(image))
                        },
                        placeholder: {
                            content(.empty)
                        }
                    )
                }
            } else {
                CachedNetworkImage(
                    url: url,
                    content: { image in
                        image.resizable().scaledToFit()
                    },
                    placeholder: {
                        ProgressView()
                    }
                )
            }
        } else {
            if let content = content {
                content(.empty)
            } else {
                Image(systemName: "photo").resizable().scaledToFit()
            }
        }
    }
}

// AsyncImagePhase enum to match SwiftUI's API
enum AsyncImagePhase {
    case empty
    case success(Image)
    case failure(Error)
    
    var image: Image? {
        guard case .success(let image) = self else { return nil }
        return image
    }
    
    var error: Error? {
        guard case .failure(let error) = self else { return nil }
        return error
    }
}
