import Foundation
import SwiftData

/// A saved outfit made of existing garments plus its collage composition.
@Model
final class Look {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    /// References to `Garment.id`. Garments may be deleted later, so views
    /// must resolve these IDs and warn about missing ones.
    var garmentIDs: [UUID] = []
    /// JSON-encoded `CollageComposition`.
    var compositionData: Data?
    var exportedImageFileName: String?
    var styleRaw: String?
    var occasionRaw: String?
    var tags: [String] = []
    var notes: String = ""
    var explanation: String = ""
    var pinterestURLs: [String] = []
    var referenceIDs: [UUID] = []
    var isFavorite: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var lastWornAt: Date?

    init(id: UUID = UUID(), name: String, garmentIDs: [UUID], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.garmentIDs = garmentIDs
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    var style: FashionStyle? {
        get { styleRaw.flatMap(FashionStyle.init(rawValue:)) }
        set { styleRaw = newValue?.rawValue }
    }

    var occasion: Occasion? {
        get { occasionRaw.flatMap(Occasion.init(rawValue:)) }
        set { occasionRaw = newValue?.rawValue }
    }

    var composition: CollageComposition? {
        get {
            guard let compositionData else { return nil }
            return try? JSONDecoder().decode(CollageComposition.self, from: compositionData)
        }
        set {
            compositionData = newValue.flatMap { try? JSONEncoder().encode($0) }
        }
    }
}

/// A named group of looks ("Oficina", "Vacaciones").
@Model
final class LookCollection {
    @Attribute(.unique) var id: UUID = UUID()
    var name: String = ""
    var lookIDs: [UUID] = []
    var createdAt: Date = Date()

    init(id: UUID = UUID(), name: String, lookIDs: [UUID] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.lookIDs = lookIDs
        self.createdAt = createdAt
    }
}

/// A look planned for a specific day in the local calendar.
@Model
final class PlannedOutfit {
    @Attribute(.unique) var id: UUID = UUID()
    /// Start of the planned day (local time zone).
    var day: Date = Date()
    var lookID: UUID = UUID()
    var note: String = ""
    var markedAsWorn: Bool = false

    init(id: UUID = UUID(), day: Date, lookID: UUID, note: String = "") {
        self.id = id
        self.day = Calendar.current.startOfDay(for: day)
        self.lookID = lookID
        self.note = note
    }
}
