import Foundation
import CoreGraphics

enum CollageAspect: String, Codable, CaseIterable, Identifiable, Sendable {
    case square
    case portrait
    case story

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .square: return "1:1"
        case .portrait: return "4:5"
        case .story: return "9:16"
        }
    }

    /// Height divided by width.
    var heightRatio: CGFloat {
        switch self {
        case .square: return 1
        case .portrait: return 1.25
        case .story: return 16.0 / 9.0
        }
    }

    /// Export size in pixels (width 1080 px, common for sharing).
    var exportSize: CGSize {
        CGSize(width: 1080, height: (1080 * heightRatio).rounded())
    }
}

/// One garment placed on the collage canvas. Positions are normalized
/// (0...1) relative to the canvas so the composition survives size changes.
struct CollageItem: Codable, Hashable, Identifiable, Sendable {
    var id: UUID = UUID()
    var garmentID: UUID
    /// Center X as a fraction of canvas width.
    var centerX: Double
    /// Center Y as a fraction of canvas height.
    var centerY: Double
    /// Width as a fraction of canvas width.
    var width: Double
    /// Rotation in degrees.
    var rotation: Double = 0
    var zIndex: Int = 0
}

struct CollageComposition: Codable, Hashable, Sendable {
    static let currentVersion = 1

    var version: Int = CollageComposition.currentVersion
    var aspect: CollageAspect = .portrait
    var backgroundHex: String = "#F5EFE8"
    /// Shows photos that still have a background as clean rounded cards.
    var cardStyleForPhotos: Bool = true
    var items: [CollageItem] = []

    var sortedItems: [CollageItem] {
        items.sorted { $0.zIndex < $1.zIndex }
    }

    var garmentIDs: [UUID] {
        sortedItems.map(\.garmentID)
    }

    mutating func bringToFront(_ itemID: UUID) {
        let top = (items.map(\.zIndex).max() ?? 0) + 1
        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].zIndex = top
        }
        normalizeZOrder()
    }

    mutating func sendToBack(_ itemID: UUID) {
        let bottom = (items.map(\.zIndex).min() ?? 0) - 1
        if let index = items.firstIndex(where: { $0.id == itemID }) {
            items[index].zIndex = bottom
        }
        normalizeZOrder()
    }

    mutating func moveForward(_ itemID: UUID) {
        reorder(itemID, by: 1)
    }

    mutating func moveBackward(_ itemID: UUID) {
        reorder(itemID, by: -1)
    }

    mutating func remove(_ itemID: UUID) {
        items.removeAll { $0.id == itemID }
        normalizeZOrder()
    }

    /// Re-numbers z-indices to 0..<n keeping their order.
    mutating func normalizeZOrder() {
        let ordered = sortedItems.map(\.id)
        for (position, id) in ordered.enumerated() {
            if let index = items.firstIndex(where: { $0.id == id }) {
                items[index].zIndex = position
            }
        }
    }

    private mutating func reorder(_ itemID: UUID, by offset: Int) {
        var ordered = sortedItems
        guard let position = ordered.firstIndex(where: { $0.id == itemID }) else { return }
        let target = min(max(position + offset, 0), ordered.count - 1)
        guard target != position else { return }
        let item = ordered.remove(at: position)
        ordered.insert(item, at: target)
        for (z, element) in ordered.enumerated() {
            if let index = items.firstIndex(where: { $0.id == element.id }) {
                items[index].zIndex = z
            }
        }
    }
}
