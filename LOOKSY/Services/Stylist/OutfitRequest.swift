import Foundation

/// A piece the user explicitly asked for ("mis jeans negros").
struct ItemRequirement: Hashable, Sendable {
    var category: GarmentCategory?
    var slot: OutfitSlot
    var colors: [FashionColor] = []
    /// Set when the request names one specific garment of the wardrobe.
    var garmentID: UUID?
    var requiresHeel = false
    /// Human readable phrase ("jeans negros").
    var phrase: String

    func matches(_ garment: GarmentSnapshot) -> Bool {
        if let garmentID { return garment.id == garmentID }
        if let category {
            guard garment.category == category else { return false }
        } else {
            guard garment.slot == slot else { return false }
        }
        if requiresHeel && !garment.isHeel { return false }
        guard !colors.isEmpty else { return true }
        // Accept the exact color or the same family ("azul" matches navy).
        return garment.colors.contains { color in
            colors.contains(color) || colors.contains { $0.family == color.family && $0.family != .multi }
        }
    }
}

enum WeatherHint: String, Sendable {
    case cool
    case warm
}

/// Structured interpretation of a free-text outfit request.
struct OutfitRequest: Sendable {
    var text: String = ""
    var requirements: [ItemRequirement] = []
    var excludedCategories: Set<GarmentCategory> = []
    var excludedColors: Set<FashionColor> = []
    var excludeHeels = false
    var styles: [FashionStyle] = []
    var occasion: Occasion?
    var weather: WeatherHint?
    var seasons: Set<Season> = []
    var formalityTarget: Int?
    /// Colors mentioned without a garment ("algo en tonos rosa").
    var paletteColors: [FashionColor] = []
    var prefersComfort = false
    var feminine = false

    var isEmpty: Bool {
        requirements.isEmpty && styles.isEmpty && occasion == nil && weather == nil
            && paletteColors.isEmpty && excludedCategories.isEmpty && excludedColors.isEmpty
            && !excludeHeels && !prefersComfort && !feminine && formalityTarget == nil
    }

    /// Short explanation of what LOOKSY understood, shown to the user.
    var interpretation: [String] {
        var lines: [String] = []
        if !requirements.isEmpty {
            lines.append("Incluir: " + requirements.map(\.phrase).joined(separator: ", "))
        }
        if let occasion { lines.append("Ocasión: \(occasion.displayName)") }
        if !styles.isEmpty { lines.append("Estilo: " + styles.map(\.displayName).joined(separator: ", ")) }
        if let weather { lines.append(weather == .cool ? "Clima fresco" : "Clima cálido") }
        if !paletteColors.isEmpty { lines.append("Colores: " + paletteColors.map(\.displayName).joined(separator: ", ")) }
        var avoid: [String] = []
        if excludeHeels { avoid.append("tacones") }
        avoid += excludedCategories.sorted { $0.rawValue < $1.rawValue }.map(\.singularName)
        avoid += excludedColors.sorted { $0.rawValue < $1.rawValue }.map(\.adjective)
        if !avoid.isEmpty { lines.append("Evitar: " + avoid.joined(separator: ", ")) }
        if prefersComfort { lines.append("Prioridad: comodidad") }
        if feminine { lines.append("Toque femenino") }
        if let formalityTarget { lines.append("Formalidad: \(Formality.label(for: formalityTarget))") }
        return lines
    }
}
