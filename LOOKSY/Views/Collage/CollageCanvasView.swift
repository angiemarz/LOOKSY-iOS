import SwiftUI

/// Static rendering of a collage (used for previews, thumbnails and export).
struct CollageCanvasView: View {
    let composition: CollageComposition
    let pieces: [CollagePiece]

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color(hex: composition.backgroundHex)
                ForEach(composition.sortedItems) { item in
                    let piece = pieces.first { $0.id == item.garmentID }
                    CollageItemView(piece: piece, cardStyle: composition.cardStyleForPhotos, isSelected: false)
                        .frame(width: item.width * proxy.size.width, height: itemHeight(item, piece: piece, canvas: proxy.size))
                        .rotationEffect(.degrees(item.rotation))
                        .position(x: item.centerX * proxy.size.width, y: item.centerY * proxy.size.height)
                }
            }
        }
        .aspectRatio(1 / composition.aspect.heightRatio, contentMode: .fit)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Collage con \(composition.items.count) prendas")
    }

    private func itemHeight(_ item: CollageItem, piece: CollagePiece?, canvas: CGSize) -> CGFloat {
        CGFloat(item.width) * canvas.width * CGFloat(piece?.imageAspect ?? 1.2)
    }
}

/// One garment inside the collage. Cutouts float with a soft shadow; photos
/// that still have a background become clean rounded cards.
struct CollageItemView: View {
    let piece: CollagePiece?
    var cardStyle: Bool
    var isSelected: Bool

    var body: some View {
        Group {
            if let piece, let image = piece.image {
                if piece.isCutout || !cardStyle {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .shadow(color: .black.opacity(piece.isCutout ? 0.18 : 0.1), radius: 8, x: 0, y: 5)
                } else {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(5)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 5)
                }
            } else {
                // The garment was deleted or its photo is missing.
                VStack(spacing: 4) {
                    Image(systemName: piece?.garment.category.symbolName ?? "exclamationmark.triangle")
                        .font(.title3)
                    Text(piece?.garment.name ?? "Prenda eliminada")
                        .font(.caption2)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .foregroundStyle(Color(rgb: 0x6B5F57))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(rgb: 0xD8A7B1), style: StrokeStyle(lineWidth: 1, dash: [4])))
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color(rgb: 0xA35E6E), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .padding(-6)
            }
        }
    }
}
