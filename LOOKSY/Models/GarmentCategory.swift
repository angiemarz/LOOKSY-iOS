import Foundation

/// Position a garment occupies in an outfit.
enum OutfitSlot: String, Codable, CaseIterable, Identifiable, Sendable {
    case top
    case bottom
    case onePiece
    case outerwear
    case shoes
    case bag
    case accessory

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .top: return "Parte superior"
        case .bottom: return "Parte inferior"
        case .onePiece: return "Vestido"
        case .outerwear: return "Capa exterior"
        case .shoes: return "Calzado"
        case .bag: return "Bolso"
        case .accessory: return "Accesorio"
        }
    }

    /// Order used when listing outfit pieces.
    var sortOrder: Int {
        switch self {
        case .outerwear: return 0
        case .top: return 1
        case .onePiece: return 2
        case .bottom: return 3
        case .shoes: return 4
        case .bag: return 5
        case .accessory: return 6
        }
    }
}

enum GarmentCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case blusas
    case tops
    case camisas
    case playeras
    case jeans
    case pantalones
    case shorts
    case faldas
    case vestidos
    case sueteres
    case chamarras
    case abrigos
    case tenis
    case zapatos
    case sandalias
    case bolsos
    case accesorios

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blusas: return "Blusas"
        case .tops: return "Tops"
        case .camisas: return "Camisas"
        case .playeras: return "Playeras"
        case .jeans: return "Jeans"
        case .pantalones: return "Pantalones"
        case .shorts: return "Shorts"
        case .faldas: return "Faldas"
        case .vestidos: return "Vestidos"
        case .sueteres: return "Suéteres"
        case .chamarras: return "Chamarras"
        case .abrigos: return "Abrigos"
        case .tenis: return "Tenis"
        case .zapatos: return "Zapatos"
        case .sandalias: return "Sandalias"
        case .bolsos: return "Bolsos"
        case .accesorios: return "Accesorios"
        }
    }

    /// Singular name used in sentences ("blusa", "jeans").
    var singularName: String {
        switch self {
        case .blusas: return "blusa"
        case .tops: return "top"
        case .camisas: return "camisa"
        case .playeras: return "playera"
        case .jeans: return "jeans"
        case .pantalones: return "pantalón"
        case .shorts: return "shorts"
        case .faldas: return "falda"
        case .vestidos: return "vestido"
        case .sueteres: return "suéter"
        case .chamarras: return "chamarra"
        case .abrigos: return "abrigo"
        case .tenis: return "tenis"
        case .zapatos: return "zapatos"
        case .sandalias: return "sandalias"
        case .bolsos: return "bolso"
        case .accesorios: return "accesorio"
        }
    }

    /// English term used to build Pinterest searches.
    var englishName: String {
        switch self {
        case .blusas: return "blouse"
        case .tops: return "top"
        case .camisas: return "shirt"
        case .playeras: return "t-shirt"
        case .jeans: return "jeans"
        case .pantalones: return "trousers"
        case .shorts: return "shorts"
        case .faldas: return "skirt"
        case .vestidos: return "dress"
        case .sueteres: return "sweater"
        case .chamarras: return "jacket"
        case .abrigos: return "coat"
        case .tenis: return "sneakers"
        case .zapatos: return "shoes"
        case .sandalias: return "sandals"
        case .bolsos: return "bag"
        case .accesorios: return "accessories"
        }
    }

    var slot: OutfitSlot {
        switch self {
        case .blusas, .tops, .camisas, .playeras, .sueteres: return .top
        case .jeans, .pantalones, .shorts, .faldas: return .bottom
        case .vestidos: return .onePiece
        case .chamarras, .abrigos: return .outerwear
        case .tenis, .zapatos, .sandalias: return .shoes
        case .bolsos: return .bag
        case .accesorios: return .accessory
        }
    }

    var symbolName: String {
        switch self {
        case .blusas, .tops, .camisas, .playeras, .sueteres: return "tshirt"
        case .jeans, .pantalones, .shorts: return "rectangle.split.2x1"
        case .faldas: return "triangle"
        case .vestidos: return "figure.stand.dress"
        case .chamarras, .abrigos: return "cloud.snow"
        case .tenis, .zapatos, .sandalias: return "shoeprints.fill"
        case .bolsos: return "handbag"
        case .accesorios: return "sparkles"
        }
    }

    /// Typical formality on a 1-5 scale, used as the default for new garments.
    var defaultFormality: Int {
        switch self {
        case .playeras, .shorts, .tenis, .sandalias: return 1
        case .tops, .jeans, .sueteres, .chamarras: return 2
        case .blusas, .faldas, .accesorios, .bolsos: return 3
        case .camisas, .pantalones, .vestidos, .abrigos, .zapatos: return 3
        }
    }

    static func categories(in slot: OutfitSlot) -> [GarmentCategory] {
        allCases.filter { $0.slot == slot }
    }
}
