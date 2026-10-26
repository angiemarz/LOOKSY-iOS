import Foundation

/// Immutable value copy of a garment used by the recommendation engine.
/// Keeps the engine independent from SwiftData (pure, testable, thread-safe).
struct GarmentSnapshot: Hashable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var category: GarmentCategory
    var primaryColor: FashionColor
    var secondaryColors: [FashionColor] = []
    var pattern: GarmentPattern = .liso
    var material: GarmentMaterial = .desconocido
    var silhouette: GarmentSilhouette = .noDefinida
    var styles: [FashionStyle] = []
    var occasions: [Occasion] = []
    var seasons: [Season] = []
    var formality: Int = 2
    var tags: [String] = []
    var isAvailable: Bool = true
    var isFavorite: Bool = false
    var wearCount: Int = 0
    var lastWornAt: Date?

    var slot: OutfitSlot { category.slot }

    var colors: [FashionColor] { [primaryColor] + secondaryColors }

    /// Normalized words from the name and tags, used for name matching and exclusions.
    var searchableText: String {
        ([name] + tags).joined(separator: " ").normalizedForSearch
    }

    var isHeel: Bool {
        let text = searchableText
        return text.contains("tacon") || text.contains("stiletto") || text.contains("heel")
    }
}

extension GarmentSnapshot {
    init(_ garment: Garment) {
        self.init(
            id: garment.id,
            name: garment.name,
            category: garment.category,
            primaryColor: garment.primaryColor,
            secondaryColors: garment.secondaryColors,
            pattern: garment.pattern,
            material: garment.material,
            silhouette: garment.silhouette,
            styles: garment.styles,
            occasions: garment.occasions,
            seasons: garment.seasons,
            formality: garment.formality,
            tags: garment.tags,
            isAvailable: garment.isAvailable,
            isFavorite: garment.isFavorite,
            wearCount: garment.wearCount,
            lastWornAt: garment.lastWornAt
        )
    }
}
