import Foundation
import SwiftData
import UIKit

/// Wardrobe operations that touch both SwiftData and the image files.
@MainActor
struct WardrobeService {
    let context: ModelContext
    var images: ImageStorageService = .shared

    struct NewGarmentInput {
        var name: String
        var category: GarmentCategory
        var primaryColor: FashionColor
        var secondaryColors: [FashionColor] = []
        var detectedColorHex: String?
    }

    /// Creates a garment from a photo. The photo is saved to disk first.
    @discardableResult
    func createGarment(image: UIImage, cutout: UIImage? = nil, input: NewGarmentInput) throws -> Garment {
        let garment = Garment(name: input.name, category: input.category, primaryColor: input.primaryColor)
        let files = try images.savePhoto(image, id: garment.id)
        garment.imageFileName = files.original
        garment.thumbnailFileName = files.thumbnail
        if let cutout {
            garment.cutoutFileName = try images.savePNG(cutout, id: garment.id)
            garment.usesCutout = true
            images.delete(files.thumbnail)
            garment.thumbnailFileName = try images.saveThumbnail(for: cutout, baseID: garment.id)
        }
        garment.secondaryColors = input.secondaryColors
        garment.detectedColorHex = input.detectedColorHex
        context.insert(garment)
        try context.save()
        AppLogger.storage.info("Garment created")
        return garment
    }

    /// Replaces the photo of an existing garment (after crop/rotate).
    func replacePhoto(of garment: Garment, with image: UIImage) throws {
        let old = [garment.imageFileName, garment.thumbnailFileName].compactMap { $0 }
        let files = try images.savePhoto(image, id: garment.id)
        garment.imageFileName = files.original
        if !(garment.usesCutout && garment.cutoutFileName != nil) {
            garment.thumbnailFileName = files.thumbnail
            images.delete(old)
        } else {
            images.delete(files.thumbnail)
            images.delete(old.filter { $0 != garment.thumbnailFileName })
        }
        garment.updatedAt = Date()
        try context.save()
    }

    /// Stores a background-removed version and makes it the active image.
    func setCutout(_ cutout: UIImage, for garment: Garment) throws {
        let oldCutout = garment.cutoutFileName
        let oldThumb = garment.thumbnailFileName
        garment.cutoutFileName = try images.savePNG(cutout, id: garment.id)
        garment.thumbnailFileName = try images.saveThumbnail(for: cutout, baseID: garment.id)
        garment.usesCutout = true
        images.delete(oldCutout)
        images.delete(oldThumb)
        garment.updatedAt = Date()
        try context.save()
    }

    /// Switches between the cutout and the original photo.
    func setUsesCutout(_ usesCutout: Bool, for garment: Garment) throws {
        guard garment.usesCutout != usesCutout else { return }
        let source: String? = usesCutout ? garment.cutoutFileName : garment.imageFileName
        guard let source, let image = images.loadImageSync(source) else { return }
        let oldThumb = garment.thumbnailFileName
        garment.thumbnailFileName = try images.saveThumbnail(for: image, baseID: garment.id)
        images.delete(oldThumb)
        garment.usesCutout = usesCutout
        garment.updatedAt = Date()
        try context.save()
    }

    /// Looks that reference the garment (used to warn before deleting).
    func looksUsing(_ garment: Garment) -> [Look] {
        let id = garment.id
        let looks = (try? context.fetch(FetchDescriptor<Look>())) ?? []
        return looks.filter { $0.garmentIDs.contains(id) }
    }

    /// Deletes the garment and its photos. Looks keep the dangling ID so they
    /// can show a "prenda eliminada" warning instead of silently changing.
    func delete(_ garment: Garment, preferences: PreferencesService? = nil) throws {
        let files = garment.allImageFileNames
        let id = garment.id
        context.delete(garment)
        try context.save()
        images.delete(files)
        if let preferences, preferences.preferences.favoriteGarmentIDs.contains(id) {
            preferences.preferences.favoriteGarmentIDs.removeAll { $0 == id }
        }
        AppLogger.storage.info("Garment deleted")
    }

    func duplicate(_ garment: Garment) throws -> Garment {
        let copy = Garment(name: garment.name + " (copia)", category: garment.category, primaryColor: garment.primaryColor)
        copy.secondaryColorRaws = garment.secondaryColorRaws
        copy.materialRaw = garment.materialRaw
        copy.patternRaw = garment.patternRaw
        copy.styleRaws = garment.styleRaws
        copy.silhouetteRaw = garment.silhouetteRaw
        copy.seasonRaws = garment.seasonRaws
        copy.formality = garment.formality
        copy.occasionRaws = garment.occasionRaws
        copy.tags = garment.tags
        copy.notes = garment.notes
        copy.detectedColorHex = garment.detectedColorHex
        if let name = garment.imageFileName, let image = images.loadImageSync(name) {
            let files = try images.savePhoto(image, id: copy.id)
            copy.imageFileName = files.original
            copy.thumbnailFileName = files.thumbnail
        }
        if let name = garment.cutoutFileName, let image = images.loadImageSync(name) {
            copy.cutoutFileName = try images.savePNG(image, id: copy.id)
            copy.usesCutout = garment.usesCutout
            if copy.usesCutout {
                images.delete(copy.thumbnailFileName)
                copy.thumbnailFileName = try images.saveThumbnail(for: image, baseID: copy.id)
            }
        }
        context.insert(copy)
        try context.save()
        return copy
    }

    /// Registers that the garments were worn today (feeds "prendas poco usadas").
    func markWorn(_ garmentIDs: [UUID], on date: Date = Date()) {
        let ids = Set(garmentIDs)
        let garments = (try? context.fetch(FetchDescriptor<Garment>())) ?? []
        for garment in garments where ids.contains(garment.id) {
            garment.wearCount += 1
            garment.lastWornAt = date
        }
        try? context.save()
    }
}
