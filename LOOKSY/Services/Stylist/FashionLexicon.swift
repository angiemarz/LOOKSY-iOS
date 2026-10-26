import Foundation

/// Local Spanish/English fashion vocabulary used by the request parser and
/// the Pinterest query generator. All terms are normalized (no accents, lowercase).
enum FashionLexicon {
    /// Two-word color expressions, checked before single words.
    static let colorPhrases: [(String, FashionColor)] = [
        ("azul marino", .azulMarino),
        ("azul claro", .celeste),
        ("azul cielo", .celeste),
        ("rosa palo", .rosaPalo),
        ("palo de rosa", .rosaPalo),
        ("rosa pastel", .rosaPalo),
        ("rosa claro", .rosaPalo),
        ("verde oliva", .oliva),
        ("verde militar", .oliva),
        ("verde menta", .menta),
        ("light blue", .celeste),
        ("navy blue", .azulMarino),
        ("blush pink", .rosaPalo)
    ]

    static let colorWords: [String: FashionColor] = {
        var map: [String: FashionColor] = [:]
        func add(_ color: FashionColor, _ words: [String]) {
            for word in words { map[word] = color }
        }
        add(.negro, ["negro", "negra", "negros", "negras", "black"])
        add(.blanco, ["blanco", "blanca", "blancos", "blancas", "white"])
        add(.gris, ["gris", "grises", "gray", "grey"])
        add(.crema, ["crema", "cremas", "marfil", "hueso", "ivory", "cream"])
        add(.beige, ["beige", "beiges", "arena", "nude", "khaki", "caqui"])
        add(.camel, ["camel", "caramelo", "tan"])
        add(.cafe, ["cafe", "cafes", "marron", "marrones", "chocolate", "brown"])
        add(.mezclilla, ["denim"])
        add(.azulMarino, ["marino", "navy"])
        add(.azul, ["azul", "azules", "blue", "rey"])
        add(.celeste, ["celeste", "celestes"])
        add(.verde, ["verde", "verdes", "green", "esmeralda"])
        add(.oliva, ["oliva", "militar", "olive"])
        add(.menta, ["menta", "mint"])
        add(.rojo, ["rojo", "roja", "rojos", "rojas", "red"])
        add(.vino, ["vino", "guinda", "burdeos", "tinto", "burgundy", "borgona"])
        add(.rosa, ["rosa", "rosas", "rosado", "rosada", "rosados", "rosadas", "pink"])
        add(.fucsia, ["fucsia", "fiusha", "magenta", "fuchsia"])
        add(.morado, ["morado", "morada", "morados", "moradas", "purpura", "purple", "violeta"])
        add(.lila, ["lila", "lilas", "lavanda", "lilac", "lavender"])
        add(.amarillo, ["amarillo", "amarilla", "amarillos", "amarillas", "yellow"])
        add(.mostaza, ["mostaza", "mustard"])
        add(.naranja, ["naranja", "naranjas", "anaranjado", "anaranjada", "orange"])
        add(.coral, ["coral", "corales", "durazno", "peach"])
        add(.dorado, ["dorado", "dorada", "dorados", "doradas", "gold", "oro"])
        add(.plateado, ["plateado", "plateada", "plateados", "plateadas", "plata", "silver"])
        add(.multicolor, ["multicolor", "colorido", "colorida", "coloridos", "coloridas"])
        return map
    }()

    /// Words that need a garment next to them to count as a color
    /// ("botas cafe" yes, "tomar un cafe" no).
    static let ambiguousColorWords: Set<String> = ["cafe", "cafes", "oro", "rey", "tan", "arena", "plata", "vino"]

    struct GarmentTerm {
        var category: GarmentCategory?
        var slot: OutfitSlot
        var isHeel: Bool = false
    }

    static let garmentWords: [String: GarmentTerm] = {
        var map: [String: GarmentTerm] = [:]
        func add(_ category: GarmentCategory, _ words: [String], heel: Bool = false) {
            for word in words { map[word] = GarmentTerm(category: category, slot: category.slot, isHeel: heel) }
        }
        add(.blusas, ["blusa", "blusas", "blouse", "blouses"])
        add(.tops, ["top", "tops", "crop", "corset", "bodysuit", "body"])
        add(.camisas, ["camisa", "camisas", "shirt", "shirts"])
        add(.playeras, ["playera", "playeras", "camiseta", "camisetas", "remera", "remeras", "tshirt", "polo"])
        add(.jeans, ["jean", "jeans", "vaquero", "vaqueros", "mezclilla"])
        add(.pantalones, ["pantalon", "pantalones", "pants", "trousers", "leggings", "joggers"])
        add(.shorts, ["short", "shorts", "bermuda", "bermudas"])
        add(.faldas, ["falda", "faldas", "minifalda", "skirt"])
        add(.vestidos, ["vestido", "vestidos", "dress", "jumpsuit", "enterizo", "overol"])
        add(.sueteres, ["sueter", "sueteres", "sweater", "jersey", "cardigan", "sudadera", "hoodie", "sweatshirt"])
        add(.chamarras, ["chamarra", "chamarras", "chaqueta", "chaquetas", "blazer", "blazers", "saco", "jacket", "cazadora"])
        add(.abrigos, ["abrigo", "abrigos", "gabardina", "trench", "coat", "poncho"])
        add(.tenis, ["tenis", "sneakers", "deportivos"])
        add(.zapatos, ["zapato", "zapatos", "flats", "mocasines", "mocasin", "botas", "bota", "botines", "botin", "loafers", "shoes", "balerinas"])
        add(.zapatos, ["tacon", "tacones", "heels", "stilettos", "zapatillas", "zapatilla"], heel: true)
        add(.sandalias, ["sandalia", "sandalias", "sandals", "huaraches"])
        add(.bolsos, ["bolso", "bolsos", "bolsa", "bolsas", "cartera", "mochila", "clutch", "bag", "tote"])
        add(.accesorios, ["accesorio", "accesorios", "collar", "collares", "aretes", "arete", "cinturon", "lentes", "gorra", "bufanda", "reloj", "pulsera", "sombrero", "diadema", "panuelo", "jewelry"])
        map["calzado"] = GarmentTerm(category: nil, slot: .shoes)
        return map
    }()

    static let negationWords: Set<String> = ["sin", "no", "evitar", "evita", "nada", "excepto", "menos"]

    static let occasionPhrases: [(String, Occasion)] = [
        ("tomar cafe", .cafe), ("tomar un cafe", .cafe), ("por un cafe", .cafe), ("al cafe", .cafe),
        ("cafeteria", .cafe), ("coffee", .cafe), ("cafecito", .cafe),
        ("trabajo", .trabajo), ("trabajar", .trabajo), ("oficina", .trabajo), ("junta", .trabajo),
        ("reunion", .trabajo), ("entrevista", .trabajo), ("work", .trabajo),
        ("primera cita", .cita), ("cita", .cita), ("date", .cita), ("cena romantica", .cita), ("aniversario", .cita),
        ("fiesta", .fiesta), ("antro", .fiesta), ("party", .fiesta), ("salir de noche", .fiesta), ("concierto", .fiesta),
        ("cumpleanos", .fiesta), ("noche de chicas", .fiesta), ("bar", .fiesta), ("cena", .cita),
        ("boda", .eventoFormal), ("gala", .eventoFormal), ("graduacion", .eventoFormal), ("evento formal", .eventoFormal),
        ("ceremonia", .eventoFormal), ("bautizo", .eventoFormal), ("xv anos", .eventoFormal),
        ("viaje", .viaje), ("viajar", .viaje), ("aeropuerto", .viaje), ("vacaciones", .viaje), ("avion", .viaje),
        ("brunch", .brunch), ("desayuno", .brunch), ("almuerzo", .brunch), ("comida con amigas", .brunch),
        ("compras", .compras), ("shopping", .compras), ("centro comercial", .compras), ("mall", .compras),
        ("gym", .deporte), ("gimnasio", .deporte), ("correr", .deporte), ("ejercicio", .deporte), ("yoga", .deporte),
        ("pilates", .deporte), ("deporte", .deporte), ("entrenar", .deporte),
        ("dia a dia", .diario), ("diario", .diario), ("everyday", .diario), ("universidad", .diario),
        ("escuela", .diario), ("clases", .diario), ("uni", .diario)
    ]

    static let stylePhrases: [(String, FashionStyle)] = [
        ("casual chic", .casualChic), ("smart casual", .casualChic), ("chic", .casualChic),
        ("old money", .oldMoney), ("quiet luxury", .oldMoney), ("clasico", .oldMoney), ("clasica", .oldMoney),
        ("pinterest aesthetic", .pinterestAesthetic), ("pinterest", .pinterestAesthetic), ("aesthetic", .pinterestAesthetic),
        ("tendencia", .pinterestAesthetic), ("trendy", .pinterestAesthetic), ("de moda", .pinterestAesthetic),
        ("minimalista", .minimalista), ("minimal", .minimalista), ("basico", .minimalista), ("basica", .minimalista),
        ("sencillo", .minimalista), ("sencilla", .minimalista), ("clean girl", .minimalista),
        ("coquette", .coquette), ("monos", .coquette), ("lazos", .coquette), ("coqueta", .coquette),
        ("romantico", .romantico), ("romantica", .romantico), ("delicado", .romantico), ("delicada", .romantico),
        ("elegante", .elegante), ("arreglada", .elegante), ("arreglado", .elegante), ("sofisticada", .elegante),
        ("sofisticado", .elegante), ("glam", .elegante), ("formal", .elegante),
        ("streetwear", .streetwear), ("urbano", .streetwear), ("urbana", .streetwear), ("street", .streetwear),
        ("oficina", .oficina), ("profesional", .oficina), ("ejecutiva", .oficina), ("business", .oficina),
        ("casual", .casual), ("relajado", .casual), ("relajada", .casual)
    ]

    static let coolWeatherWords = ["fresco", "fresca", "frio", "fria", "invierno", "lluvia", "lluvioso", "nublado", "otono", "templado"]
    static let warmWeatherWords = ["calor", "caluroso", "calurosa", "verano", "playa", "soleado", "soleada", "caliente"]
    static let comfortWords = ["comoda", "comodo", "comodidad", "comodas", "comodos", "caminar mucho", "sin sufrir", "practica", "practico"]
    static let feminineWords = ["femenino", "femenina", "girly", "coqueta", "femeninos", "femeninas"]

    /// Words ignored when matching garment names.
    static let stopWords: Set<String> = ["de", "la", "el", "los", "las", "mi", "mis", "con", "y", "un", "una", "para", "en", "a", "al", "del", "que", "quiero", "outfit", "look", "algo", "arma", "combina", "por", "favor", "estilo", "color", "tono"]
}
