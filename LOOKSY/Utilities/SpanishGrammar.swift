import Foundation

/// Minimal Spanish agreement rules for "garment + color" phrases
/// ("jeans negros", "blusa blanca", "sandalias doradas").
enum SpanishGrammar {
    static func isFeminine(_ category: GarmentCategory) -> Bool {
        switch category {
        case .blusas, .camisas, .playeras, .faldas, .chamarras, .sandalias: return true
        default: return false
        }
    }

    static func isPlural(_ category: GarmentCategory) -> Bool {
        switch category {
        case .jeans, .shorts, .tenis, .zapatos, .sandalias, .accesorios: return true
        default: return false
        }
    }

    /// Color adjective agreeing with gender and number.
    static func color(_ color: FashionColor, feminine: Bool, plural: Bool) -> String {
        let base = color.adjective
        let variable: Set<FashionColor> = [.negro, .blanco, .rojo, .morado, .amarillo, .dorado, .plateado]
        var word = base
        if variable.contains(color), feminine {
            word = String(base.dropLast()) + "a"
        }
        guard plural else { return word }
        switch color {
        case .negro, .blanco, .rojo, .morado, .amarillo, .dorado, .plateado, .celeste:
            return word + "s"
        case .azul:
            return "azules"
        case .gris:
            return "grises"
        case .verde:
            return "verdes"
        default:
            // Invariable color names (rosa, beige, crema, camel, azul marino…).
            return word
        }
    }

    /// "jeans negros", "blusa rosa".
    static func phrase(_ category: GarmentCategory, _ fashionColor: FashionColor) -> String {
        "\(category.singularName) \(color(fashionColor, feminine: isFeminine(category), plural: isPlural(category)))"
    }
}
