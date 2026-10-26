import Foundation
import CoreGraphics

/// Automatic flat-lay layout: top in the center, bottom below, shoes at the
/// bottom, bag on one side and accessories around. Pure and testable.
enum CollageLayoutEngine {
    struct Input: Hashable {
        var garmentID: UUID
        var slot: OutfitSlot
        /// Image height / width. Use 1.2 when unknown.
        var imageAspect: Double
    }

    private struct Box {
        var centerX: Double
        var centerY: Double
        var maxWidth: Double
        var maxHeight: Double
        var rotation: Double = 0
        var z: Int
    }

    static func layout(_ inputs: [Input], aspect: CollageAspect) -> [CollageItem] {
        let hasSide = inputs.contains { $0.slot == .outerwear || $0.slot == .bag }
        let column = hasSide ? 0.40 : 0.5
        let hasDress = inputs.contains { $0.slot == .onePiece }
        let heightRatio = Double(aspect.heightRatio)
        // Taller canvases leave more vertical room: spread pieces a bit.
        let stretch = heightRatio >= 1.7 ? 1.0 : (heightRatio >= 1.2 ? 1.0 : 0.92)

        var accessoryIndex = 0
        let accessorySpots: [(Double, Double, Double)] = [
            (0.15, 0.10, -10), (0.86, 0.09, 8), (0.14, 0.88, 6), (0.86, 0.91, -6), (0.13, 0.48, 4), (0.88, 0.40, -4)
        ]

        var items: [CollageItem] = []
        for input in inputs {
            let box: Box
            switch input.slot {
            case .top:
                box = Box(centerX: column, centerY: 0.24, maxWidth: 0.48, maxHeight: 0.36 * stretch, z: 2)
            case .bottom:
                box = Box(centerX: column, centerY: 0.60, maxWidth: 0.42, maxHeight: 0.40 * stretch, z: 1)
            case .onePiece:
                box = Box(centerX: column, centerY: 0.43, maxWidth: 0.50, maxHeight: 0.66 * stretch, z: 2)
            case .shoes:
                box = Box(centerX: column, centerY: hasDress ? 0.89 : 0.89, maxWidth: 0.30, maxHeight: 0.15, rotation: -6, z: 3)
            case .outerwear:
                box = Box(centerX: 0.76, centerY: 0.28, maxWidth: 0.38, maxHeight: 0.42 * stretch, rotation: 3, z: 0)
            case .bag:
                box = Box(centerX: 0.80, centerY: 0.68, maxWidth: 0.30, maxHeight: 0.24, rotation: 4, z: 4)
            case .accessory:
                let spot = accessorySpots[accessoryIndex % accessorySpots.count]
                accessoryIndex += 1
                box = Box(centerX: spot.0, centerY: spot.1, maxWidth: 0.20, maxHeight: 0.14, rotation: spot.2, z: 5 + accessoryIndex)
            }
            let imageAspect = input.imageAspect > 0 ? input.imageAspect : 1.2
            // Width fraction such that the item fits inside the box.
            let widthFromHeight = box.maxHeight * heightRatio / imageAspect
            let width = min(box.maxWidth, widthFromHeight)
            items.append(CollageItem(
                garmentID: input.garmentID,
                centerX: box.centerX,
                centerY: box.centerY,
                width: max(width, 0.08),
                rotation: box.rotation,
                zIndex: box.z
            ))
        }
        var composition = CollageComposition(aspect: aspect, items: items)
        composition.normalizeZOrder()
        return composition.items
    }

    /// Builds a full composition for the given pieces.
    static func composition(
        for inputs: [Input],
        aspect: CollageAspect = .portrait,
        backgroundHex: String = "#F5EFE8"
    ) -> CollageComposition {
        CollageComposition(aspect: aspect, backgroundHex: backgroundHex, items: layout(inputs, aspect: aspect))
    }

    /// Height fraction (of canvas height) of an item given its image aspect.
    static func heightFraction(of item: CollageItem, imageAspect: Double, canvasAspect: CollageAspect) -> Double {
        item.width * (imageAspect > 0 ? imageAspect : 1.2) / Double(canvasAspect.heightRatio)
    }
}
