import Foundation
import SwiftData

/// A fashion reference saved by the user: a Pinterest link, a search,
/// or an imported screenshot. LOOKSY never fabricates pins.
@Model
final class InspirationReference {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String = ""
    /// Original link (Pinterest pin, board or search) when provided.
    var urlString: String?
    /// Pinterest search text when the reference is a saved search.
    var searchQuery: String?
    /// Image imported from Photos (e.g. a screenshot), stored on disk.
    var imageFileName: String?
    var colorRaws: [String] = []
    var styleRaw: String?
    var notes: String = ""
    var isFavorite: Bool = false
    var linkedLookIDs: [UUID] = []
    var linkedGarmentIDs: [UUID] = []
    var createdAt: Date = Date()

    init(id: UUID = UUID(), title: String, urlString: String? = nil, searchQuery: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.searchQuery = searchQuery
        self.createdAt = createdAt
    }

    var colors: [FashionColor] {
        get { colorRaws.compactMap(FashionColor.init(rawValue:)) }
        set { colorRaws = newValue.map(\.rawValue) }
    }

    var style: FashionStyle? {
        get { styleRaw.flatMap(FashionStyle.init(rawValue:)) }
        set { styleRaw = newValue?.rawValue }
    }

    var url: URL? {
        urlString.flatMap(URL.init(string:))
    }
}
