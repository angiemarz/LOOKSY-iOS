import Foundation

/// A Pinterest search the user can open. LOOKSY only builds public search
/// links; it never scrapes Pinterest or shows invented pins.
struct PinterestQuery: Identifiable, Hashable, Sendable {
    enum Language: String, Sendable {
        case english = "EN"
        case spanish = "ES"
    }

    var text: String
    var language: Language

    var id: String { language.rawValue + ":" + text }

    var url: URL {
        PinterestSearchService.searchURL(for: text)
    }
}

enum PinterestSearchService {
    /// Public Pinterest search page (opens the Pinterest app when installed).
    static func searchURL(for query: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.pinterest.com"
        components.path = "/search/pins/"
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url ?? URL(string: "https://www.pinterest.com")!
    }

    /// Accepts pinterest.* domains and the pin.it short links.
    static func isPinterestURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "pin.it" || host.hasSuffix(".pin.it") || host.contains("pinterest.")
    }

    /// Validates a pasted link, adding https:// when missing.
    static func normalizedURL(from text: String) -> URL? {
        var value = text.trimmed
        guard !value.isEmpty else { return nil }
        if !value.lowercased().hasPrefix("http://") && !value.lowercased().hasPrefix("https://") {
            value = "https://" + value
        }
        guard let url = URL(string: value), url.host != nil else { return nil }
        return url
    }

    // MARK: Query generation

    /// Searches for an outfit made of the given garments.
    static func queries(
        for garments: [GarmentSnapshot],
        style: FashionStyle? = nil,
        occasion: Occasion? = nil,
        feminine: Bool = false,
        limit: Int = 6
    ) -> [PinterestQuery] {
        let main = garments
            .filter { [.top, .onePiece, .bottom, .outerwear].contains($0.slot) }
            .sorted { $0.slot.sortOrder < $1.slot.sortOrder }
        let shoes = garments.first { $0.slot == .shoes }
        var results: [PinterestQuery] = []

        func add(_ text: String, _ language: PinterestQuery.Language) {
            let clean = text.split(separator: " ").joined(separator: " ").lowercased()
            guard !clean.isEmpty, !results.contains(where: { $0.text == clean }) else { return }
            results.append(PinterestQuery(text: clean, language: language))
        }

        let pieces = Array(main.prefix(2))
        if !pieces.isEmpty {
            let english = pieces.map { englishPhrase($0) }.joined(separator: " ")
            add("\(english) outfit", .english)
            let spanish = pieces.map { spanishPhrase($0) }.joined(separator: " ")
            add("\(spanish) outfit", .spanish)
        }

        let accent = garments.map(\.primaryColor).first { !$0.isNeutral } ?? pieces.first?.primaryColor
        if let style, let accent {
            add("\(style.englishName) \(feminine ? "feminine " : "")\(accent.englishName) outfit", .english)
        }
        if let first = pieces.first, let shoes {
            add("\(first.primaryColor.englishName) \(first.category.englishName) \(shoes.category.englishName) pinterest aesthetic", .english)
        }
        if let occasion, let first = pieces.first {
            add("\(occasion.englishName) outfit \(englishPhrase(first))", .english)
            add("outfit para \(occasion.displayName.lowercased()) \(spanishPhrase(first))", .spanish)
        }
        if let style, pieces.isEmpty {
            add("\(style.englishName) outfit ideas", .english)
            add("outfit \(style.displayName.lowercased())", .spanish)
        }
        return Array(results.prefix(limit))
    }

    /// Searches derived from a parsed text request.
    static func queries(for request: OutfitRequest, limit: Int = 6) -> [PinterestQuery] {
        var results: [PinterestQuery] = []
        func add(_ text: String, _ language: PinterestQuery.Language) {
            let clean = text.split(separator: " ").joined(separator: " ").lowercased()
            guard !clean.isEmpty, !results.contains(where: { $0.text == clean }) else { return }
            results.append(PinterestQuery(text: clean, language: language))
        }
        let pieceEN = request.requirements.prefix(2).map { requirement -> String in
            let color = requirement.colors.first.map { $0.englishName + " " } ?? ""
            return color + (requirement.category?.englishName ?? "shoes")
        }.joined(separator: " ")
        let pieceES = request.requirements.prefix(2).map { requirement -> String in
            if let category = requirement.category, let color = requirement.colors.first {
                return SpanishGrammar.phrase(category, color)
            }
            return requirement.category?.singularName ?? requirement.phrase
        }.joined(separator: " ")
        let styleEN = request.styles.first?.englishName ?? ""
        let occasionEN = request.occasion?.englishName ?? ""
        let palette = request.paletteColors.first?.englishName ?? ""
        let feminine = request.feminine ? "feminine" : ""
        let weather = request.weather == .cool ? "fall" : (request.weather == .warm ? "summer" : "")

        add("\(styleEN) \(feminine) \(palette) \(pieceEN) \(occasionEN) outfit", .english)
        if !pieceES.isEmpty || request.occasion != nil || !request.styles.isEmpty {
            let occasionES = request.occasion.map { "para \($0.displayName.lowercased())" } ?? ""
            add("outfit \(request.styles.first?.displayName.lowercased() ?? "") \(pieceES) \(occasionES)", .spanish)
        }
        if !pieceEN.isEmpty {
            add("\(pieceEN) outfit pinterest aesthetic", .english)
        }
        if !occasionEN.isEmpty {
            add("\(weather) \(occasionEN) outfit ideas \(feminine)", .english)
        }
        if !styleEN.isEmpty {
            add("\(styleEN) \(weather) outfit inspiration", .english)
        }
        if results.isEmpty {
            add(request.text, .spanish)
        }
        return Array(results.prefix(limit))
    }

    /// Searches inspired by a palette and/or a style.
    static func queries(colors: [FashionColor], style: FashionStyle?) -> [PinterestQuery] {
        let names = colors.prefix(3).map(\.englishName).joined(separator: " and ")
        let namesES = colors.prefix(3).map(\.adjective).joined(separator: " y ")
        var results: [PinterestQuery] = []
        if !names.isEmpty {
            results.append(PinterestQuery(text: "\(names) outfit \(style?.englishName ?? "")".trimmed, language: .english))
            results.append(PinterestQuery(text: "outfit \(namesES) \(style?.displayName.lowercased() ?? "")".trimmed, language: .spanish))
            results.append(PinterestQuery(text: "\(names) color palette outfit aesthetic", language: .english))
        } else if let style {
            results.append(PinterestQuery(text: "\(style.englishName) outfit ideas", language: .english))
            results.append(PinterestQuery(text: "outfits \(style.displayName.lowercased())", language: .spanish))
        }
        return results
    }

    private static func spanishPhrase(_ garment: GarmentSnapshot) -> String {
        if garment.primaryColor == .mezclilla {
            return garment.category == .jeans ? "jeans" : "\(garment.category.singularName) de mezclilla"
        }
        return SpanishGrammar.phrase(garment.category, garment.primaryColor)
    }

    private static func englishPhrase(_ garment: GarmentSnapshot) -> String {
        let pattern = garment.pattern.englishName
        let color = garment.primaryColor == .mezclilla ? (garment.category == .jeans ? "blue" : "denim") : garment.primaryColor.englishName
        return [color, pattern, garment.category.englishName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}
