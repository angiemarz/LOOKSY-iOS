import Foundation
import SwiftData
import UIKit

/// Creates and maintains saved looks and their collage previews.
@MainActor
struct LookService {
    let context: ModelContext
    var images: ImageStorageService = .shared

    /// Saves a new look made of existing garments.
    @discardableResult
    func saveLook(
        name: String,
        garmentIDs: [UUID],
        composition: CollageComposition,
        pieces: [CollagePiece],
        style: FashionStyle?,
        occasion: Occasion?,
        explanation: String = "",
        pinterestURLs: [String] = [],
        referenceIDs: [UUID] = []
    ) throws -> Look {
        let look = Look(name: name.trimmed.isEmpty ? "Mi look" : name.trimmed, garmentIDs: garmentIDs)
        look.composition = composition
        look.style = style
        look.occasion = occasion
        look.explanation = explanation
        look.pinterestURLs = pinterestURLs
        look.referenceIDs = referenceIDs
        look.exportedImageFileName = renderPreview(composition: composition, pieces: pieces, lookID: look.id)
        context.insert(look)
        try context.save()
        return look
    }

    /// Applies an edited composition; the garment list follows the canvas.
    func updateComposition(of look: Look, composition: CollageComposition, pieces: [CollagePiece]) throws {
        let old = look.exportedImageFileName
        look.composition = composition
        let canvasIDs = composition.sortedItems.map(\.garmentID)
        // Deleted garments keep their canvas item, so looks still show the warning.
        look.garmentIDs = canvasIDs.reduce(into: [UUID]()) { if !$0.contains($1) { $0.append($1) } }
        look.exportedImageFileName = renderPreview(composition: composition, pieces: pieces, lookID: look.id)
        look.updatedAt = Date()
        images.delete(old)
        try context.save()
    }

    func duplicate(_ look: Look) throws -> Look {
        let copy = Look(name: look.name + " (copia)", garmentIDs: look.garmentIDs)
        copy.compositionData = look.compositionData
        copy.styleRaw = look.styleRaw
        copy.occasionRaw = look.occasionRaw
        copy.tags = look.tags
        copy.notes = look.notes
        copy.explanation = look.explanation
        copy.pinterestURLs = look.pinterestURLs
        copy.referenceIDs = look.referenceIDs
        if let name = look.exportedImageFileName, let data = images.data(for: name) {
            let newName = "\(copy.id.uuidString)-look.png"
            try images.writeData(data, named: newName)
            copy.exportedImageFileName = newName
        }
        context.insert(copy)
        try context.save()
        return copy
    }

    /// Deletes the look, its preview and its calendar entries; removes it from collections.
    func delete(_ look: Look) throws {
        let id = look.id
        images.delete(look.exportedImageFileName)
        let plans = (try? context.fetch(FetchDescriptor<PlannedOutfit>())) ?? []
        for plan in plans where plan.lookID == id {
            context.delete(plan)
        }
        let collections = (try? context.fetch(FetchDescriptor<LookCollection>())) ?? []
        for collection in collections where collection.lookIDs.contains(id) {
            collection.lookIDs.removeAll { $0 == id }
        }
        let references = (try? context.fetch(FetchDescriptor<InspirationReference>())) ?? []
        for reference in references where reference.linkedLookIDs.contains(id) {
            reference.linkedLookIDs.removeAll { $0 == id }
        }
        context.delete(look)
        try context.save()
    }

    /// Renders a small PNG used in grids (keeps lists fast).
    func renderPreview(composition: CollageComposition, pieces: [CollagePiece], lookID: UUID) -> String? {
        guard let image = CollageService.render(composition, pieces: pieces, width: 540),
              let data = image.pngData() else { return nil }
        let name = "\(lookID.uuidString)-look-\(Int(Date().timeIntervalSince1970)).png"
        do {
            try images.writeData(data, named: name)
            return name
        } catch {
            AppLogger.storage.error("Could not store look preview")
            return nil
        }
    }

    /// Re-renders a look's preview (e.g. after garments were deleted).
    func refreshPreview(of look: Look, garments: [Garment]) async {
        guard let composition = look.composition else { return }
        let byID = Dictionary(garments.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let used = composition.sortedItems.compactMap { byID[$0.garmentID] }
        let pieces = await CollageService.loadPieces(for: used)
        let old = look.exportedImageFileName
        look.exportedImageFileName = renderPreview(composition: composition, pieces: pieces, lookID: look.id)
        images.delete(old)
        try? context.save()
    }
}
