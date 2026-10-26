import Foundation

/// Personal style profile. Stored as JSON by `PreferencesService`.
struct UserPreferences: Codable, Equatable, Sendable {
    static let currentVersion = 1

    var version: Int = UserPreferences.currentVersion
    var displayName: String = ""
    var favoriteStyles: [FashionStyle] = []
    var favoriteColors: [FashionColor] = []
    var avoidedColors: [FashionColor] = []
    var favoriteGarmentIDs: [UUID] = []
    var preferredShoes: [GarmentCategory] = []
    /// 1 = maximum comfort, 5 = I don't mind sacrificing comfort.
    var comfortLevel: Int = 3
    /// Usual formality on the 1-5 scale.
    var usualFormality: Int = 2
    var silhouettePreferences: [GarmentSilhouette] = []
    var frequentOccasions: [Occasion] = []
    var seasons: [Season] = []
    var avoidHeels: Bool = false

    init() {}

    // Tolerant decoding so new fields never break older backups.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = (try? c.decode(Int.self, forKey: .version)) ?? UserPreferences.currentVersion
        displayName = (try? c.decode(String.self, forKey: .displayName)) ?? ""
        favoriteStyles = Self.decodeLossy(FashionStyle.self, c, .favoriteStyles)
        favoriteColors = Self.decodeLossy(FashionColor.self, c, .favoriteColors)
        avoidedColors = Self.decodeLossy(FashionColor.self, c, .avoidedColors)
        favoriteGarmentIDs = (try? c.decode([UUID].self, forKey: .favoriteGarmentIDs)) ?? []
        preferredShoes = Self.decodeLossy(GarmentCategory.self, c, .preferredShoes)
        comfortLevel = (try? c.decode(Int.self, forKey: .comfortLevel)) ?? 3
        usualFormality = (try? c.decode(Int.self, forKey: .usualFormality)) ?? 2
        silhouettePreferences = Self.decodeLossy(GarmentSilhouette.self, c, .silhouettePreferences)
        frequentOccasions = Self.decodeLossy(Occasion.self, c, .frequentOccasions)
        seasons = Self.decodeLossy(Season.self, c, .seasons)
        avoidHeels = (try? c.decode(Bool.self, forKey: .avoidHeels)) ?? false
    }

    private static func decodeLossy<T: RawRepresentable>(
        _ type: T.Type,
        _ container: KeyedDecodingContainer<CodingKeys>,
        _ key: CodingKeys
    ) -> [T] where T.RawValue == String {
        let raw = (try? container.decode([String].self, forKey: key)) ?? []
        return raw.compactMap(T.init(rawValue:))
    }
}
