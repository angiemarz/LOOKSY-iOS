import Foundation
import SwiftData

/// A real piece of clothing photographed by the user.
/// Photos live on disk (see `ImageStorageService`); the model only keeps file names.
@Model
final class Garment {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    /// Original (cropped/rotated) photo.
    var imageFileName: String?
    /// Optional background-removed PNG.
    var cutoutFileName: String?
    var thumbnailFileName: String?
    /// When true, collages use the cutout instead of the original photo.
    var usesCutout: Bool = false
    var categoryRaw: String = GarmentCategory.blusas.rawValue
    var primaryColorRaw: String = FashionColor.negro.rawValue
    var secondaryColorRaws: [String] = []
    /// Average color measured from the photo, if analysis ran.
    var detectedColorHex: String?
    var materialRaw: String = GarmentMaterial.desconocido.rawValue
    var patternRaw: String = GarmentPattern.liso.rawValue
    var styleRaws: [String] = []
    var silhouetteRaw: String = GarmentSilhouette.noDefinida.rawValue
    var seasonRaws: [String] = []
    var formality: Int = 2
    var occasionRaws: [String] = []
    var tags: [String] = []
    var notes: String = ""
    var isAvailable: Bool = true
    var isFavorite: Bool = false
    var wearCount: Int = 0
    var lastWornAt: Date?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(
        id: UUID = UUID(),
        name: String,
        category: GarmentCategory,
        primaryColor: FashionColor,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.categoryRaw = category.rawValue
        self.primaryColorRaw = primaryColor.rawValue
        self.formality = category.defaultFormality
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    // MARK: Typed accessors

    var category: GarmentCategory {
        get { GarmentCategory(rawValue: categoryRaw) ?? .accesorios }
        set { categoryRaw = newValue.rawValue }
    }

    var primaryColor: FashionColor {
        get { FashionColor(rawValue: primaryColorRaw) ?? .multicolor }
        set { primaryColorRaw = newValue.rawValue }
    }

    var secondaryColors: [FashionColor] {
        get { secondaryColorRaws.compactMap(FashionColor.init(rawValue:)) }
        set { secondaryColorRaws = newValue.map(\.rawValue) }
    }

    var material: GarmentMaterial {
        get { GarmentMaterial(rawValue: materialRaw) ?? .desconocido }
        set { materialRaw = newValue.rawValue }
    }

    var pattern: GarmentPattern {
        get { GarmentPattern(rawValue: patternRaw) ?? .liso }
        set { patternRaw = newValue.rawValue }
    }

    var styles: [FashionStyle] {
        get { styleRaws.compactMap(FashionStyle.init(rawValue:)) }
        set { styleRaws = newValue.map(\.rawValue) }
    }

    var silhouette: GarmentSilhouette {
        get { GarmentSilhouette(rawValue: silhouetteRaw) ?? .noDefinida }
        set { silhouetteRaw = newValue.rawValue }
    }

    var seasons: [Season] {
        get { seasonRaws.compactMap(Season.init(rawValue:)) }
        set { seasonRaws = newValue.map(\.rawValue) }
    }

    var occasions: [Occasion] {
        get { occasionRaws.compactMap(Occasion.init(rawValue:)) }
        set { occasionRaws = newValue.map(\.rawValue) }
    }

    /// File used for collages: the cutout when selected and available.
    var collageImageFileName: String? {
        if usesCutout, let cutoutFileName { return cutoutFileName }
        return imageFileName
    }

    var allImageFileNames: [String] {
        [imageFileName, cutoutFileName, thumbnailFileName].compactMap { $0 }
    }
}
