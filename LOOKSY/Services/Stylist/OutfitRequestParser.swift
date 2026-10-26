import Foundation

/// Rule-based, fully local interpretation of outfit requests in Spanish
/// (with common English fashion words). No remote language model is used.
struct OutfitRequestParser {
    /// Garments of the wardrobe, used to recognize garments mentioned by name.
    var wardrobe: [GarmentSnapshot] = []

    func parse(_ text: String) -> OutfitRequest {
        var request = OutfitRequest(text: text)
        let normalized = " " + text.searchTokens.joined(separator: " ") + " "
        var working = normalized

        // 1. Multi-word color phrases become single placeholder tokens.
        var phraseColors: [String: FashionColor] = [:]
        for (index, entry) in FashionLexicon.colorPhrases.enumerated() {
            let placeholder = "colorphrase\(index)"
            if working.contains(" \(entry.0) ") {
                working = working.replacingOccurrences(of: " \(entry.0) ", with: " \(placeholder) ")
                phraseColors[placeholder] = entry.1
            }
        }

        let tokens = working.split(separator: " ").map(String.init)
        var consumed = Set<Int>()

        func color(at index: Int) -> FashionColor? {
            guard tokens.indices.contains(index) else { return nil }
            let token = tokens[index]
            return phraseColors[token] ?? FashionLexicon.colorWords[token]
        }

        func isNegated(before index: Int) -> Bool {
            let start = max(0, index - 3)
            guard start < index else { return false }
            for i in start..<index where FashionLexicon.negationWords.contains(tokens[i]) {
                return true
            }
            return false
        }

        // 2. Garment mentions with attached colors ("jeans negros", "blusa color rosa").
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            // "de mezclilla" right after another garment is a material, not jeans.
            if token == "mezclilla", index >= 2, tokens[index - 1] == "de",
               FashionLexicon.garmentWords[tokens[index - 2]] != nil {
                consumed.insert(index)
                index += 1
                continue
            }
            guard let term = FashionLexicon.garmentWords[token] else {
                index += 1
                continue
            }
            consumed.insert(index)
            // Attached colors: up to three tokens after the noun, skipping fillers.
            var colors: [FashionColor] = []
            var lookahead = index + 1
            var steps = 0
            while lookahead < tokens.count, steps < 4 {
                let next = tokens[lookahead]
                if ["de", "color", "en", "tono", "tonos", "y"].contains(next) {
                    lookahead += 1
                    steps += 1
                    continue
                }
                if let c = color(at: lookahead) {
                    colors.append(c)
                    consumed.insert(lookahead)
                    lookahead += 1
                    steps += 1
                    continue
                }
                break
            }
            // English order: "pink blouse".
            if colors.isEmpty, index > 0, !consumed.contains(index - 1), let c = color(at: index - 1),
               !FashionLexicon.ambiguousColorWords.contains(tokens[index - 1]) {
                colors.append(c)
                consumed.insert(index - 1)
            }

            if isNegated(before: index) {
                if term.isHeel {
                    request.excludeHeels = true
                } else if let category = term.category {
                    request.excludedCategories.insert(category)
                }
            } else {
                // Collapse "crop top" or repeated nouns of the same category.
                let phraseWords = [token] + colors.map(\.adjective)
                let requirement = ItemRequirement(
                    category: term.category,
                    slot: term.slot,
                    colors: colors,
                    requiresHeel: term.isHeel,
                    phrase: phraseWords.joined(separator: " ")
                )
                if let last = request.requirements.last, last.category == requirement.category, last.slot == requirement.slot {
                    var merged = last
                    merged.colors = Array(Set(last.colors + colors)).sorted { $0.rawValue < $1.rawValue }
                    if !colors.isEmpty { merged.phrase = requirement.phrase }
                    request.requirements[request.requirements.count - 1] = merged
                } else {
                    request.requirements.append(requirement)
                }
            }
            index = max(lookahead, index + 1)
        }

        // 3. Free colors: palette preferences or exclusions ("sin negro").
        for (i, token) in tokens.enumerated() where !consumed.contains(i) {
            guard let c = color(at: i) else { continue }
            if FashionLexicon.ambiguousColorWords.contains(token) { continue }
            if isNegated(before: i) {
                request.excludedColors.insert(c)
            } else if !request.paletteColors.contains(c) {
                request.paletteColors.append(c)
            }
            consumed.insert(i)
        }

        // 4. Phrase-level signals on the normalized text.
        let padded = " " + tokens.joined(separator: " ") + " "
        func has(_ phrase: String) -> Bool {
            padded.contains(" \(phrase) ")
        }

        for (phrase, occasion) in FashionLexicon.occasionPhrases where request.occasion == nil {
            if has(phrase) { request.occasion = occasion }
        }
        // A bare "cafe" not used as a garment color means the coffee occasion.
        if request.occasion == nil, tokens.enumerated().contains(where: { $0.element == "cafe" && !consumed.contains($0.offset) }) {
            request.occasion = .cafe
        }

        var styleText = padded
        for (phrase, style) in FashionLexicon.stylePhrases where styleText.contains(" \(phrase) ") {
            if !request.styles.contains(style) { request.styles.append(style) }
            styleText = styleText.replacingOccurrences(of: " \(phrase) ", with: " ")
        }

        if FashionLexicon.coolWeatherWords.contains(where: has) {
            request.weather = .cool
            request.seasons = [.otono, .invierno]
        } else if FashionLexicon.warmWeatherWords.contains(where: has) {
            request.weather = .warm
            request.seasons = [.primavera, .verano]
        }
        if has("invierno") { request.seasons = [.invierno] }
        if has("verano") { request.seasons = [.verano] }
        if has("primavera") { request.seasons = [.primavera] }
        if has("otono") { request.seasons = [.otono] }

        request.prefersComfort = FashionLexicon.comfortWords.contains(where: has)
        request.feminine = FashionLexicon.feminineWords.contains(where: has)
        if request.prefersComfort && !request.requirements.contains(where: { $0.requiresHeel }) {
            request.excludeHeels = request.excludeHeels || has("sin tacones")
        }

        // 5. Formality target.
        if has("muy formal") || has("de gala") {
            request.formalityTarget = 5
        } else if has("arreglada") || has("arreglado") || has("verme bien") {
            request.formalityTarget = max(3, request.occasion?.typicalFormality ?? 3)
        } else if has("muy casual") || has("relajada") || has("relajado") {
            request.formalityTarget = 1
        }

        // 6. Specific garments mentioned by name ("mi blusa de lino").
        let requestTokens = Set(tokens)
        var namedMatches: [(GarmentSnapshot, Int)] = []
        for garment in wardrobe {
            let nameTokens = Set(garment.name.searchTokens).subtracting(FashionLexicon.stopWords)
            guard nameTokens.count >= 2, nameTokens.isSubset(of: requestTokens) else { continue }
            // Require at least one distinctive word (not only category/color words).
            let distinctive = nameTokens.filter { FashionLexicon.garmentWords[$0] == nil && FashionLexicon.colorWords[$0] == nil }
            guard !distinctive.isEmpty else { continue }
            namedMatches.append((garment, nameTokens.count))
        }
        for (garment, _) in namedMatches.sorted(by: { $0.1 > $1.1 }) {
            let slotIndex = request.requirements.firstIndex { $0.slot == garment.slot && ($0.category == nil || $0.category == garment.category) }
            if let slotIndex {
                if request.requirements[slotIndex].garmentID == nil {
                    request.requirements[slotIndex].garmentID = garment.id
                    request.requirements[slotIndex].phrase = garment.name
                }
            } else if !request.requirements.contains(where: { $0.garmentID == garment.id }) {
                request.requirements.append(ItemRequirement(category: garment.category, slot: garment.slot, garmentID: garment.id, phrase: garment.name))
            }
        }

        return request
    }
}
