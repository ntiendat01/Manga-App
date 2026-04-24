import SwiftUI

final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 200
        cache.totalCostLimit = 100 * 1024 * 1024 // 100 MB
    }

    func image(for key: String) -> UIImage? {
        cache.object(forKey: NSString(string: key))
    }

    func setImage(_ image: UIImage, for key: String) {
        cache.setObject(image, forKey: NSString(string: key))
    }
}

// MARK: - Cached Async Image View

struct CachedAsyncImage: View {
    let url: URL?
    let contentMode: ContentMode
    var maxRetries: Int = 3

    @State private var image: UIImage?
    @State private var isLoading = false
    @State private var hasFailed = false
    @State private var retryCount = 0

    init(url: URL?, contentMode: ContentMode = .fill, maxRetries: Int = 3) {
        self.url = url
        self.contentMode = contentMode
        self.maxRetries = maxRetries
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hasFailed {
                failedView
            } else {
                Color.gray.opacity(0.3)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.gray)
                    }
            }
        }
        .task(id: url) {
            retryCount = 0
            hasFailed = false
            await loadImage()
        }
    }

    private var failedView: some View {
        Color.gray.opacity(0.15)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundStyle(.secondary)

                    Text("Tap to reload")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                retryCount = 0
                hasFailed = false
                Task { await loadImage() }
            }
    }

    private func loadImage() async {
        guard let url else { return }

        let key = url.absoluteString
        if let cached = ImageCache.shared.image(for: key) {
            self.image = cached
            return
        }

        isLoading = true
        defer { isLoading = false }

        while retryCount <= maxRetries {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)

                if let http = response as? HTTPURLResponse, http.statusCode == 429 {
                    retryCount += 1
                    let delay = pow(2.0, Double(retryCount))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }

                guard let uiImage = UIImage(data: data) else {
                    hasFailed = true
                    return
                }

                ImageCache.shared.setImage(uiImage, for: key)
                self.image = uiImage
                return
            } catch is CancellationError {
                return
            } catch {
                retryCount += 1
                if retryCount > maxRetries {
                    hasFailed = true
                    return
                }
                let delay = pow(2.0, Double(retryCount))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        hasFailed = true
    }
}
