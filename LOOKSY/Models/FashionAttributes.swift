import Foundation

enum FashionStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case casual
    case casualChic
    case minimalista
    case coquette
    case oldMoney
    case romantico
    case elegante
    case streetwear
    case oficina
    case pinterestAesthetic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .casual: return "Casual"
        case .casualChic: return "Casual chic"
        case .minimalista: return "Minimalista"
        case .coquette: return "Coquette"
        case .oldMoney: return "Old money"
        case .romantico: return "Romántico"
        case .elegante: return "Elegante"
        case .streetwear: return "Streetwear"
        case .oficina: return "Oficina"
        case .pinterestAesthetic: return "Pinterest aesthetic"
        }
    }

    var englishName: String {
        switch self {
        case .casual: return "casual"
        case .casualChic: return "casual chic"
        case .minimalista: return "minimalist"
        case .coquette: return "coquette"
        case .oldMoney: return "old money"
        case .romantico: return "romantic"
        case .elegante: return "elegant"
        case .streetwear: return "streetwear"
        case .oficina: return "office"
        case .pinterestAesthetic: return "aesthetic"
        }
    }

    /// Typical formality for the style on a 1-5 scale.
    var typicalFormality: Int {
        switch self {
        case .casual, .streetwear: return 1
        case .casualChic, .minimalista, .pinterestAesthetic, .coquette: return 2
        case .romantico: return 3
        case .oldMoney, .oficina: return 4
        case .elegante: return 4
        }
    }

    /// Styles that combine naturally with this one.
    var relatedStyles: Set<FashionStyle> {
        switch self {
        case .casual: return [.casualChic, .streetwear, .minimalista]
        case .casualChic: return [.casual, .minimalista, .pinterestAesthetic, .oldMoney]
        case .minimalista: return [.casualChic, .oldMoney, .oficina]
        case .coquette: return [.romantico, .pinterestAesthetic]
        case .oldMoney: return [.elegante, .minimalista, .oficina]
        case .romantico: return [.coquette, .elegante]
        case .elegante: return [.oldMoney, .romantico, .oficina]
        case .streetwear: return [.casual, .pinterestAesthetic]
        case .oficina: return [.oldMoney, .minimalista, .elegante]
        case .pinterestAesthetic: return [.casualChic, .coquette, .streetwear]
        }
    }
}

enum Occasion: String, Codable, CaseIterable, Identifiable, Sendable {
    case diario
    case cafe
    case trabajo
    case cita
    case fiesta
    case eventoFormal
    case viaje
    case brunch
    case compras
    case deporte

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .diario: return "Día a día"
        case .cafe: return "Café"
        case .trabajo: return "Trabajo"
        case .cita: return "Cita"
        case .fiesta: return "Fiesta"
        case .eventoFormal: return "Evento formal"
        case .viaje: return "Viaje"
        case .brunch: return "Brunch"
        case .compras: return "Compras"
        case .deporte: return "Deporte"
        }
    }

    var englishName: String {
        switch self {
        case .diario: return "everyday"
        case .cafe: return "coffee date"
        case .trabajo: return "work"
        case .cita: return "date night"
        case .fiesta: return "party"
        case .eventoFormal: return "formal event"
        case .viaje: return "travel"
        case .brunch: return "brunch"
        case .compras: return "shopping day"
        case .deporte: return "athleisure"
        }
    }

    var typicalFormality: Int {
        switch self {
        case .deporte: return 1
        case .diario, .compras, .viaje: return 2
        case .cafe, .brunch: return 2
        case .cita, .fiesta: return 3
        case .trabajo: return 4
        case .eventoFormal: return 5
        }
    }

    var suggestedStyles: Set<FashionStyle> {
        switch self {
        case .diario: return [.casual, .casualChic, .minimalista]
        case .cafe: return [.casualChic, .casual, .pinterestAesthetic, .coquette]
        case .trabajo: return [.oficina, .oldMoney, .minimalista, .elegante]
        case .cita: return [.romantico, .coquette, .elegante, .casualChic]
        case .fiesta: return [.elegante, .streetwear, .pinterestAesthetic]
        case .eventoFormal: return [.elegante, .oldMoney]
        case .viaje: return [.casual, .minimalista, .streetwear]
        case .brunch: return [.casualChic, .romantico, .coquette]
        case .compras: return [.casual, .casualChic, .streetwear]
        case .deporte: return [.casual, .streetwear]
        }
    }
}

enum Season: String, Codable, CaseIterable, Identifiable, Sendable {
    case primavera
    case verano
    case otono
    case invierno

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .primavera: return "Primavera"
        case .verano: return "Verano"
        case .otono: return "Otoño"
        case .invierno: return "Invierno"
        }
    }

    var isCool: Bool { self == .otono || self == .invierno }
}

enum GarmentPattern: String, Codable, CaseIterable, Identifiable, Sendable {
    case liso
    case rayas
    case cuadros
    case floral
    case lunares
    case animalPrint
    case estampado
    case otro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .liso: return "Liso"
        case .rayas: return "Rayas"
        case .cuadros: return "Cuadros"
        case .floral: return "Floral"
        case .lunares: return "Lunares"
        case .animalPrint: return "Animal print"
        case .estampado: return "Estampado"
        case .otro: return "Otro"
        }
    }

    var englishName: String {
        switch self {
        case .liso: return ""
        case .rayas: return "striped"
        case .cuadros: return "plaid"
        case .floral: return "floral"
        case .lunares: return "polka dot"
        case .animalPrint: return "leopard print"
        case .estampado: return "printed"
        case .otro: return ""
        }
    }
}

enum GarmentMaterial: String, Codable, CaseIterable, Identifiable, Sendable {
    case desconocido
    case algodon
    case mezclilla
    case lino
    case seda
    case satin
    case punto
    case lana
    case piel
    case poliester
    case otro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .desconocido: return "Sin especificar"
        case .algodon: return "Algodón"
        case .mezclilla: return "Mezclilla"
        case .lino: return "Lino"
        case .seda: return "Seda"
        case .satin: return "Satín"
        case .punto: return "Punto / tejido"
        case .lana: return "Lana"
        case .piel: return "Piel"
        case .poliester: return "Poliéster"
        case .otro: return "Otro"
        }
    }
}

enum GarmentSilhouette: String, Codable, CaseIterable, Identifiable, Sendable {
    case noDefinida
    case ajustada
    case recta
    case holgada
    case oversize
    case cropped
    case acampanada
    case wideLeg

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noDefinida: return "Sin especificar"
        case .ajustada: return "Ajustada"
        case .recta: return "Recta"
        case .holgada: return "Holgada"
        case .oversize: return "Oversize"
        case .cropped: return "Cropped"
        case .acampanada: return "Acampanada"
        case .wideLeg: return "Wide leg"
        }
    }
}

enum Formality {
    static let range = 1...5

    static func label(for level: Int) -> String {
        switch level {
        case ...1: return "Muy casual"
        case 2: return "Casual"
        case 3: return "Arreglado casual"
        case 4: return "Elegante"
        default: return "Formal"
        }
    }
}
