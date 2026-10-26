import SwiftUI

/// Loads a stored photo asynchronously and shows a placeholder meanwhile.
struct StoredImageView: View {
    let fileName: String?
    var contentMode: ContentMode = .fit
    var placeholderSymbol: String = "photo"

    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else if didFail || fileName == nil {
                Image(systemName: placeholderSymbol)
                    .font(.title2)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel("Imagen no disponible")
            } else {
                ShimmerView()
            }
        }
        .task(id: fileName) {
            await load()
        }
    }

    private func load() async {
        guard let fileName else {
            image = nil
            return
        }
        if let cached = ImageStorageService.shared.cachedImage(fileName) {
            image = cached
            return
        }
        let loaded = await ImageStorageService.shared.loadImage(fileName)
        withAnimation(.easeOut(duration: 0.2)) {
            image = loaded
            didFail = loaded == nil
        }
    }
}

/// Garment thumbnail inside a soft card.
struct GarmentThumbnail: View {
    let garment: Garment
    var showsName = true
    var height: CGFloat = 170

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                StoredImageView(fileName: garment.thumbnailFileName ?? garment.imageFileName, contentMode: .fit, placeholderSymbol: garment.category.symbolName)
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
                    .background(Theme.cream, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
                    .opacity(garment.isAvailable ? 1 : 0.55)

                if garment.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(6)
                        .accessibilityLabel("Favorita")
                }
            }
            if showsName {
                VStack(alignment: .leading, spacing: 2) {
                    Text(garment.name.isEmpty ? garment.category.singularName.capitalized : garment.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        ColorDot(color: garment.primaryColor, size: 10)
                        Text(garment.category.displayName)
                            .font(.caption)
                            .foregroundStyle(Theme.textSecondary)
                        if !garment.isAvailable {
                            Text("· No disponible")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Animated placeholder used while images load.
struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        GeometryReader { proxy in
            Theme.beige.opacity(0.5)
                .overlay(
                    LinearGradient(
                        colors: [.clear, Color.white.opacity(0.35), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: proxy.size.width * 0.6)
                    .offset(x: phase * proxy.size.width)
                )
                .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1.4
            }
        }
        .accessibilityHidden(true)
    }
}
