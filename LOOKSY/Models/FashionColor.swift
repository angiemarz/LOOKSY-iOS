import Foundation

/// Named color families used to describe garments. Detected colors are
/// mapped to the nearest name so the stylist can reason about them.
enum FashionColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case negro
    case blanco
    case gris
    case crema
    case beige
    case camel
    case cafe
    case mezclilla
    case azulMarino
    case azul
    case celeste
    case verde
    case oliva
    case menta
    case rojo
    case vino
    case rosa
    case rosaPalo
    case fucsia
    case morado
    case lila
    case amarillo
    case mostaza
    case naranja
    case coral
    case dorado
    case plateado
    case multicolor

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .negro: return "Negro"
        case .blanco: return "Blanco"
        case .gris: return "Gris"
        case .crema: return "Crema"
        case .beige: return "Beige"
        case .camel: return "Camel"
        case .cafe: return "Café"
        case .mezclilla: return "Mezclilla"
        case .azulMarino: return "Azul marino"
        case .azul: return "Azul"
        case .celeste: return "Celeste"
        case .verde: return "Verde"
        case .oliva: return "Verde oliva"
        case .menta: return "Menta"
        case .rojo: return "Rojo"
        case .vino: return "Vino"
        case .rosa: return "Rosa"
        case .rosaPalo: return "Rosa palo"
        case .fucsia: return "Fucsia"
        case .morado: return "Morado"
        case .lila: return "Lila"
        case .amarillo: return "Amarillo"
        case .mostaza: return "Mostaza"
        case .naranja: return "Naranja"
        case .coral: return "Coral"
        case .dorado: return "Dorado"
        case .plateado: return "Plateado"
        case .multicolor: return "Multicolor"
        }
    }

    /// Adjective in Spanish to build sentences ("jeans negros" uses `adjective`).
    var adjective: String {
        displayName.lowercased()
    }

    var englishName: String {
        switch self {
        case .negro: return "black"
        case .blanco: return "white"
        case .gris: return "gray"
        case .crema: return "cream"
        case .beige: return "beige"
        case .camel: return "camel"
        case .cafe: return "brown"
        case .mezclilla: return "denim blue"
        case .azulMarino: return "navy"
        case .azul: return "blue"
        case .celeste: return "light blue"
        case .verde: return "green"
        case .oliva: return "olive"
        case .menta: return "mint"
        case .rojo: return "red"
        case .vino: return "burgundy"
        case .rosa: return "pink"
        case .rosaPalo: return "blush pink"
        case .fucsia: return "fuchsia"
        case .morado: return "purple"
        case .lila: return "lilac"
        case .amarillo: return "yellow"
        case .mostaza: return "mustard"
        case .naranja: return "orange"
        case .coral: return "coral"
        case .dorado: return "gold"
        case .plateado: return "silver"
        case .multicolor: return "colorful"
        }
    }

    /// Representative sRGB value.
    var rgbValue: UInt32 {
        switch self {
        case .negro: return 0x1C1C1E
        case .blanco: return 0xF7F7F5
        case .gris: return 0x8E8E93
        case .crema: return 0xF1E6D2
        case .beige: return 0xD9C6A5
        case .camel: return 0xB48A5A
        case .cafe: return 0x6F4E37
        case .mezclilla: return 0x4A6A8F
        case .azulMarino: return 0x1F2A44
        case .azul: return 0x2E64C8
        case .celeste: return 0x9CC7E8
        case .verde: return 0x3A8F5C
        case .oliva: return 0x6B7340
        case .menta: return 0xA8DCC4
        case .rojo: return 0xC62828
        case .vino: return 0x6D1A2C
        case .rosa: return 0xE58FAE
        case .rosaPalo: return 0xE8C3C8
        case .fucsia: return 0xD0217A
        case .morado: return 0x6A3D9A
        case .lila: return 0xC3A8DB
        case .amarillo: return 0xF2D23C
        case .mostaza: return 0xC9A227
        case .naranja: return 0xE8772E
        case .coral: return 0xF08070
        case .dorado: return 0xC9A74A
        case .plateado: return 0xC0C0C8
        case .multicolor: return 0x9B7FB5
        }
    }

    var rgb: RGBColor { RGBColor(rgb: rgbValue) }

    var hex: String { rgb.hexString }

    /// Neutrals combine with almost anything. Denim behaves as a neutral.
    var isNeutral: Bool {
        switch self {
        case .negro, .blanco, .gris, .crema, .beige, .camel, .cafe, .mezclilla, .azulMarino, .dorado, .plateado:
            return true
        default:
            return false
        }
    }

    /// Broader family used to match requests such as "azul" to navy or light blue.
    var family: ColorFamily {
        switch self {
        case .negro: return .black
        case .blanco, .crema: return .white
        case .gris, .plateado: return .gray
        case .beige, .camel, .cafe, .dorado: return .brown
        case .mezclilla, .azulMarino, .azul, .celeste: return .blue
        case .verde, .oliva, .menta: return .green
        case .rojo, .vino: return .red
        case .rosa, .rosaPalo, .fucsia, .coral: return .pink
        case .morado, .lila: return .purple
        case .amarillo, .mostaza: return .yellow
        case .naranja: return .orange
        case .multicolor: return .multi
        }
    }

    /// Hue angle used for harmony rules (nil for neutrals/multicolor).
    var hue: Double? {
        guard !isNeutral, self != .multicolor else { return nil }
        return rgb.hsl.hue
    }

    /// Nearest named color for a measured RGB value (perceptual distance).
    static func nearest(to color: RGBColor) -> FashionColor {
        let candidates = allCases.filter { $0 != .multicolor }
        var best = FashionColor.gris
        var bestDistance = Double.greatestFiniteMagnitude
        for candidate in candidates {
            let distance = candidate.rgb.distance(to: color)
            if distance < bestDistance {
                bestDistance = distance
                best = candidate
            }
        }
        return best
    }
}

enum ColorFamily: String, Codable, Sendable {
    case black, white, gray, brown, blue, green, red, pink, purple, yellow, orange, multi
}
