import SwiftUI
import UIKit
import Photos

/// Everything a collage needs to draw one garment.
struct CollagePiece: Identifiable {
    var id: UUID { garment.id }
    var garment: GarmentSnapshot
    var image: UIImage?

    var imageAspect: Double {
        guard let image, image.size.width > 0 else { return 1.2 }
        return Double(image.size.height / image.size.width)
    }

    /// True when the image has transparency (background removed).
    var isCutout: Bool { image?.hasAlphaChannel ?? false }
}

/// Loads images, builds layouts, renders and exports collages.
@MainActor
enum CollageService {
    enum ExportError: LocalizedError {
        case renderFailed
        case photosAccessDenied
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .renderFailed: return "No se pudo generar la imagen del collage."
            case .photosAccessDenied: return "LOOKSY no tiene permiso para guardar en Fotos. Actívalo en Ajustes > LOOKSY > Fotos."
            case .saveFailed: return "No se pudo guardar el collage en Fotos."
            }
        }
    }

    /// Loads the collage image (cutout when selected) of each garment.
    static func loadPieces(for garments: [Garment]) async -> [CollagePiece] {
        var pieces: [CollagePiece] = []
        for garment in garments {
            var image: UIImage?
            if let name = garment.collageImageFileName {
                image = await ImageStorageService.shared.loadImage(name)
            }
            pieces.append(CollagePiece(garment: GarmentSnapshot(garment), image: image))
        }
        return pieces
    }

    static func automaticComposition(for pieces: [CollagePiece], aspect: CollageAspect = .portrait, backgroundHex: String = "#F5EFE8") -> CollageComposition {
        CollageLayoutEngine.composition(
            for: pieces.map { CollageLayoutEngine.Input(garmentID: $0.garment.id, slot: $0.garment.slot, imageAspect: $0.imageAspect) },
            aspect: aspect,
            backgroundHex: backgroundHex
        )
    }

    /// Re-applies the automatic layout to a new aspect while keeping background and style.
    static func relayout(_ composition: CollageComposition, pieces: [CollagePiece], aspect: CollageAspect) -> CollageComposition {
        var updated = automaticComposition(for: pieces.filter { piece in composition.items.contains { $0.garmentID == piece.id } }, aspect: aspect, backgroundHex: composition.backgroundHex)
        updated.cardStyleForPhotos = composition.cardStyleForPhotos
        return updated
    }

    /// Renders the collage at its export size (1080 px wide).
    static func render(_ composition: CollageComposition, pieces: [CollagePiece], width: CGFloat = 1080) -> UIImage? {
        let size = CGSize(width: width, height: (width * composition.aspect.heightRatio).rounded())
        let canvas = CollageCanvasView(composition: composition, pieces: pieces)
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 1
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Writes a PNG to a temporary file for the share sheet.
    static func pngFile(for image: UIImage, name: String) throws -> URL {
        guard let data = image.pngData() else { throw ExportError.renderFailed }
        let safeName = name.isEmpty ? "LOOKSY" : name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeName).png")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// Saves the image to the photo library (add-only permission).
    static func saveToPhotos(_ image: UIImage) async throws {
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else { throw ExportError.photosAccessDenied }
        guard let data = image.pngData() else { throw ExportError.renderFailed }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }
        } catch {
            throw ExportError.saveFailed
        }
    }
}
