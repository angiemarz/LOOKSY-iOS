import SwiftUI
import Observation

/// State of the interactive collage editor.
@MainActor
@Observable
final class CollageEditorViewModel {
    var composition: CollageComposition
    var pieces: [CollagePiece]
    var selectedItemID: UUID?
    var title: String
    private let initialComposition: CollageComposition

    static let backgroundPresets = ["#F5EFE8", "#FAF8F5", "#FFFFFF", "#E8DDD0", "#F3E2E5", "#D8A7B1", "#E6E9E3", "#DDE5EE", "#292522"]

    init(composition: CollageComposition, pieces: [CollagePiece], title: String) {
        self.composition = composition
        self.pieces = pieces
        self.title = title
        self.initialComposition = composition
    }

    var selectedItem: CollageItem? {
        composition.items.first { $0.id == selectedItemID }
    }

    func piece(for item: CollageItem) -> CollagePiece? {
        pieces.first { $0.id == item.garmentID }
    }

    var hasChanges: Bool { composition != initialComposition }

    // MARK: Transformations

    func update(_ itemID: UUID, _ change: (inout CollageItem) -> Void) {
        guard let index = composition.items.firstIndex(where: { $0.id == itemID }) else { return }
        change(&composition.items[index])
        composition.items[index].centerX = min(max(composition.items[index].centerX, 0), 1)
        composition.items[index].centerY = min(max(composition.items[index].centerY, 0), 1)
        composition.items[index].width = min(max(composition.items[index].width, 0.06), 1.2)
    }

    func select(_ itemID: UUID?) {
        selectedItemID = itemID
    }

    func bringToFront() {
        guard let id = selectedItemID else { return }
        composition.bringToFront(id)
    }

    func sendToBack() {
        guard let id = selectedItemID else { return }
        composition.sendToBack(id)
    }

    func moveForward() {
        guard let id = selectedItemID else { return }
        composition.moveForward(id)
    }

    func moveBackward() {
        guard let id = selectedItemID else { return }
        composition.moveBackward(id)
    }

    func removeSelected() {
        guard let id = selectedItemID else { return }
        composition.remove(id)
        selectedItemID = nil
    }

    func setAspect(_ aspect: CollageAspect) {
        guard aspect != composition.aspect else { return }
        composition = CollageService.relayout(composition, pieces: pieces, aspect: aspect)
        selectedItemID = nil
    }

    /// Restores the automatic layout with the current pieces.
    func resetLayout() {
        composition = CollageService.relayout(composition, pieces: pieces, aspect: composition.aspect)
        selectedItemID = nil
    }

    /// Adds a garment from the wardrobe to the canvas.
    func add(_ piece: CollagePiece) {
        if !pieces.contains(where: { $0.id == piece.id }) {
            pieces.append(piece)
        }
        let placed = CollageLayoutEngine.layout(
            [CollageLayoutEngine.Input(garmentID: piece.id, slot: piece.garment.slot, imageAspect: piece.imageAspect)],
            aspect: composition.aspect
        )
        guard var item = placed.first else { return }
        item.zIndex = (composition.items.map(\.zIndex).max() ?? 0) + 1
        // Offset slightly when the slot position is already taken.
        if composition.items.contains(where: { abs($0.centerX - item.centerX) < 0.05 && abs($0.centerY - item.centerY) < 0.05 }) {
            item.centerX = min(item.centerX + 0.12, 0.9)
            item.centerY = min(item.centerY + 0.06, 0.92)
        }
        composition.items.append(item)
        composition.normalizeZOrder()
        selectedItemID = item.id
    }

    var garmentIDsInCanvas: [UUID] {
        composition.sortedItems.map(\.garmentID)
    }

    func render() -> UIImage? {
        CollageService.render(composition, pieces: pieces)
    }
}
