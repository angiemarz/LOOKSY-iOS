import Foundation

/// One proposed outfit. Every item is a real garment from the wardrobe.
struct OutfitSuggestion: Identifiable, Hashable, Sendable {
    var id = UUID()
    var name: String
    var items: [GarmentSnapshot]
    var style: FashionStyle?
    var occasion: Occasion?
    var reasons: [String]
    var warnings: [String]
    var score: Double

    var garmentIDs: [UUID] { items.map(\.id) }

    /// Order-independent identity used to avoid repeated outfits.
    var signature: String {
        items.map(\.id.uuidString).sorted().joined(separator: "|")
    }

    var coreItems: [GarmentSnapshot] {
        items.filter { [.top, .bottom, .onePiece, .shoes].contains($0.slot) }
    }

    func item(in slot: OutfitSlot) -> GarmentSnapshot? {
        items.first { $0.slot == slot }
    }
}

struct RecommendationResult: Sendable {
    var suggestions: [OutfitSuggestion]
    /// Explanations of what is missing in the wardrobe for this request.
    var missing: [String]
    var request: OutfitRequest
}

/// Local recommendation engine: filters, scores and combines garments with
/// explainable rules (style, occasion, formality, season, color harmony,
/// preferences). Deterministic for the same inputs and variation seed.
struct OutfitRecommendationService {
    var maxSuggestions = 6
    var candidatesPerSlot = 6

    // MARK: Public API

    func recommend(
        request: OutfitRequest,
        wardrobe: [GarmentSnapshot],
        preferences: UserPreferences = UserPreferences(),
        excludingSignatures: Set<String> = [],
        variationSeed: Int = 0
    ) -> RecommendationResult {
        let context = ScoringContext(request: request, preferences: preferences, seed: variationSeed)
        var missing: [String] = []

        let pool = eligiblePool(wardrobe: wardrobe, request: request, preferences: preferences)
        if pool.isEmpty {
            missing.append(wardrobe.isEmpty
                ? "Tu armario está vacío. Agrega fotos de tus prendas para crear outfits."
                : "No hay prendas disponibles que cumplan la solicitud.")
            return RecommendationResult(suggestions: [], missing: missing, request: request)
        }

        // Requirements lock slots to matching garments.
        var locked: [OutfitSlot: [GarmentSnapshot]] = [:]
        for requirement in request.requirements {
            let matches = pool.filter(requirement.matches)
            if matches.isEmpty {
                let unavailable = wardrobe.contains { requirement.matches($0) && !$0.isAvailable }
                missing.append(unavailable
                    ? "Tus \(requirement.phrase) están marcados como no disponibles."
                    : "No encontré \(requirement.phrase) en tu armario; propongo alternativas con lo que tienes.")
                continue
            }
            if let existing = locked[requirement.slot] {
                let intersection = existing.filter { item in matches.contains { $0.id == item.id } }
                locked[requirement.slot] = intersection.isEmpty ? existing : intersection
            } else {
                locked[requirement.slot] = matches
            }
        }

        func candidates(_ slot: OutfitSlot, limit: Int? = nil) -> [GarmentSnapshot] {
            let source = locked[slot] ?? pool.filter { $0.slot == slot }
            let sorted = source.sorted { context.itemScore($0) > context.itemScore($1) }
            return Array(sorted.prefix(limit ?? candidatesPerSlot))
        }

        let tops = candidates(.top)
        let bottoms = candidates(.bottom)
        let dresses = candidates(.onePiece)
        let shoes = candidates(.shoes, limit: 5)

        let wantsSeparates = locked[.top] != nil || locked[.bottom] != nil
        let wantsDress = locked[.onePiece] != nil
        let canSeparates = !tops.isEmpty && !bottoms.isEmpty && !wantsDress
        let canDress = !dresses.isEmpty && !wantsSeparates

        if !canSeparates && !canDress {
            if tops.isEmpty && dresses.isEmpty {
                missing.append("Para armar un look completo necesitas al menos una prenda superior (blusa, top, camisa…) o un vestido.")
            } else if bottoms.isEmpty && dresses.isEmpty {
                missing.append("Para armar un look completo necesitas al menos una prenda inferior (jeans, pantalón, falda…) o un vestido.")
            } else if wantsDress {
                missing.append("No hay vestidos disponibles para esta solicitud.")
            } else {
                missing.append("No hay suficientes prendas compatibles para completar un look.")
            }
            return RecommendationResult(suggestions: [], missing: missing, request: request)
        }

        let shoeOptions: [GarmentSnapshot?] = shoes.isEmpty ? [nil] : shoes.map { Optional($0) }
        if shoes.isEmpty {
            missing.append(pool.contains { $0.slot == .shoes } || wardrobe.contains { $0.slot == .shoes }
                ? "No encontré calzado compatible con esta solicitud; los looks no incluyen zapatos."
                : "Agrega calzado a tu armario para completar los looks.")
        }

        // Base combinations.
        var bases: [[GarmentSnapshot]] = []
        if canSeparates {
            for top in tops {
                for bottom in bottoms {
                    for shoe in shoeOptions {
                        bases.append([top, bottom] + (shoe.map { [$0] } ?? []))
                    }
                }
            }
        }
        if canDress {
            for dress in dresses {
                for shoe in shoeOptions {
                    bases.append([dress] + (shoe.map { [$0] } ?? []))
                }
            }
        }

        let scoredBases = bases
            .map { ($0, context.outfitScore($0)) }
            .sorted { $0.1 > $1.1 }
            .prefix(80)

        // Optional layers and complements.
        let outerwear = candidates(.outerwear, limit: 4)
        let bags = candidates(.bag, limit: 4)
        let accessories = candidates(.accessory, limit: 4)
        let needsLayer = locked[.outerwear] != nil || request.weather == .cool || request.seasons.contains(where: \.isCool)

        var complete: [(items: [GarmentSnapshot], score: Double)] = []
        for (base, baseScore) in scoredBases {
            var items = base
            var score = baseScore
            if let layer = bestAddition(from: outerwear, to: items, context: context),
               needsLayer || layer.delta > 1.5 || (request.occasion == .trabajo && layer.delta > 0) {
                items.append(layer.garment)
                score += layer.delta
            }
            if let bag = bestAddition(from: bags, to: items, context: context), locked[.bag] != nil || bag.delta > -1 {
                items.append(bag.garment)
                score += max(bag.delta, 0)
            }
            if let accessory = bestAddition(from: accessories, to: items, context: context), locked[.accessory] != nil || accessory.delta > 0 {
                items.append(accessory.garment)
                score += accessory.delta
            }
            complete.append((items: items, score: score))
        }

        // Varied selection: avoid outfits that share most of their pieces.
        let ranked = complete.sorted { $0.score > $1.score }
        var selected: [(items: [GarmentSnapshot], score: Double)] = []
        var seen = excludingSignatures
        for maxShared in [1, 2, 3] {
            for candidate in ranked where selected.count < maxSuggestions {
                let signature = Self.signature(candidate.items)
                guard !seen.contains(signature) else { continue }
                let core = Set(candidate.items.filter { Self.coreSlots.contains($0.slot) }.map(\.id))
                let tooSimilar = selected.contains { other in
                    let otherCore = Set(other.items.filter { Self.coreSlots.contains($0.slot) }.map(\.id))
                    return core.intersection(otherCore).count > maxShared
                }
                if tooSimilar { continue }
                selected.append(candidate)
                seen.insert(signature)
            }
            if selected.count >= maxSuggestions { break }
        }

        let suggestions = selected.map { makeSuggestion(items: $0.items, score: $0.score, context: context) }
        if suggestions.count < 3, !suggestions.isEmpty {
            missing.append("Con las prendas actuales solo hay \(suggestions.count) combinación(es) distinta(s). Agrega más prendas para obtener más variedad.")
        }
        return RecommendationResult(suggestions: suggestions, missing: missing, request: request)
    }

    /// Ranked replacements for one slot of an outfit, considering the other pieces.
    func alternatives(
        for slot: OutfitSlot,
        in suggestion: OutfitSuggestion,
        wardrobe: [GarmentSnapshot],
        request: OutfitRequest,
        preferences: UserPreferences = UserPreferences(),
        limit: Int = 12
    ) -> [GarmentSnapshot] {
        let context = ScoringContext(request: request, preferences: preferences, seed: 0)
        let current = suggestion.item(in: slot)
        let others = suggestion.items.filter { $0.slot != slot }
        let inOutfit = Set(suggestion.garmentIDs)
        return wardrobe
            .filter { $0.isAvailable && $0.slot == slot && $0.id != current?.id && !inOutfit.contains($0.id) }
            .map { (garment: $0, score: context.outfitScore(others + [$0])) }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.garment }
    }

    /// Rebuilds a suggestion after the user swaps, adds or removes a garment.
    func rebuild(
        _ suggestion: OutfitSuggestion,
        items: [GarmentSnapshot],
        request: OutfitRequest,
        preferences: UserPreferences = UserPreferences()
    ) -> OutfitSuggestion {
        let context = ScoringContext(request: request, preferences: preferences, seed: 0)
        var rebuilt = makeSuggestion(items: items, score: context.outfitScore(items), context: context)
        rebuilt.id = suggestion.id
        return rebuilt
    }

    // MARK: Building blocks

    static let coreSlots: Set<OutfitSlot> = [.top, .bottom, .onePiece, .shoes]

    static func signature(_ items: [GarmentSnapshot]) -> String {
        items.map(\.id.uuidString).sorted().joined(separator: "|")
    }

    private func eligiblePool(wardrobe: [GarmentSnapshot], request: OutfitRequest, preferences: UserPreferences) -> [GarmentSnapshot] {
        let requestedIDs = Set(request.requirements.compactMap(\.garmentID))
        let requestedColors = Set(request.requirements.flatMap(\.colors) + request.paletteColors)
        let avoidHeels = request.excludeHeels || (preferences.avoidHeels && !request.requirements.contains { $0.requiresHeel })
        return wardrobe.filter { garment in
            guard garment.isAvailable else { return false }
            if requestedIDs.contains(garment.id) { return true }
            if request.excludedCategories.contains(garment.category) { return false }
            if request.excludedColors.contains(garment.primaryColor) { return false }
            if avoidHeels && garment.isHeel { return false }
            // Avoided colors are skipped unless the user explicitly asked for them.
            if preferences.avoidedColors.contains(garment.primaryColor) && !requestedColors.contains(garment.primaryColor) {
                return false
            }
            return true
        }
    }

    private func bestAddition(from options: [GarmentSnapshot], to items: [GarmentSnapshot], context: ScoringContext) -> (garment: GarmentSnapshot, delta: Double)? {
        guard !options.isEmpty else { return nil }
        let base = context.outfitScore(items)
        return options
            .map { (garment: $0, delta: context.outfitScore(items + [$0]) - base) }
            .max { $0.delta < $1.delta }
    }

    private func makeSuggestion(items: [GarmentSnapshot], score: Double, context: ScoringContext) -> OutfitSuggestion {
        let ordered = items.sorted { $0.slot.sortOrder < $1.slot.sortOrder }
        let style = context.dominantStyle(of: ordered)
        let (reasons, warnings) = context.explanation(for: ordered, style: style)
        return OutfitSuggestion(
            name: Self.name(for: ordered, style: style),
            items: ordered,
            style: style,
            occasion: context.request.occasion,
            reasons: reasons,
            warnings: warnings,
            score: score
        )
    }

    static func name(for items: [GarmentSnapshot], style: FashionStyle?) -> String {
        let mainColors = items
            .filter { coreSlots.contains($0.slot) || $0.slot == .outerwear }
            .map(\.primaryColor)
            .reduce(into: [FashionColor]()) { if !$0.contains($1) { $0.append($1) } }
        // Accents first: they define the look.
        let ordered = mainColors.filter { !$0.isNeutral } + mainColors.filter(\.isNeutral)
        let colorTitle: String
        switch ordered.count {
        case 0: colorTitle = "Look"
        case 1: colorTitle = "Total \(ordered[0].adjective)"
        default: colorTitle = "\(ordered[0].displayName) y \(ordered[1].adjective)"
        }
        if let style {
            return "\(colorTitle) · \(style.displayName)"
        }
        return colorTitle
    }
}

/// Scoring rules shared by the engine. Each component is explainable.
struct ScoringContext {
    let request: OutfitRequest
    let preferences: UserPreferences
    let seed: Int

    var targetStyles: Set<FashionStyle> {
        if !request.styles.isEmpty { return Set(request.styles) }
        if let occasion = request.occasion { return occasion.suggestedStyles }
        return Set(preferences.favoriteStyles)
    }

    var targetFormality: Double {
        if let target = request.formalityTarget { return Double(target) }
        var values: [Double] = []
        if let occasion = request.occasion { values.append(Double(occasion.typicalFormality)) }
        if !request.styles.isEmpty {
            values.append(request.styles.map { Double($0.typicalFormality) }.reduce(0, +) / Double(request.styles.count))
        }
        if values.isEmpty { return Double(preferences.usualFormality) }
        return values.reduce(0, +) / Double(values.count)
    }

    var requestedColors: Set<FashionColor> {
        Set(request.requirements.flatMap(\.colors) + request.paletteColors)
    }

    var prefersComfort: Bool {
        request.prefersComfort || preferences.comfortLevel <= 2
    }

    /// Score of a garment on its own for this request.
    func itemScore(_ garment: GarmentSnapshot) -> Double {
        var score = 0.0
        let styles = Set(garment.styles)
        let targets = targetStyles

        if !targets.isEmpty, !styles.isEmpty {
            let related = targets.reduce(into: Set<FashionStyle>()) { result, style in result.formUnion(style.relatedStyles) }
            if !styles.isDisjoint(with: targets) {
                score += 3
            } else if !styles.isDisjoint(with: related) {
                score += 1.5
            } else {
                score -= 1
            }
        }
        if !styles.isDisjoint(with: preferences.favoriteStyles) { score += 1 }

        if let occasion = request.occasion, !garment.occasions.isEmpty {
            score += garment.occasions.contains(occasion) ? 2 : -0.5
        }

        // Accessories and bags matter less for formality.
        let formalityWeight: Double = [.bag, .accessory].contains(garment.slot) ? 0.5 : 1.2
        score -= abs(Double(garment.formality) - targetFormality) * formalityWeight

        if !request.seasons.isEmpty, !garment.seasons.isEmpty {
            score += Set(garment.seasons).isDisjoint(with: request.seasons) ? -2 : 1
        } else if request.seasons.isEmpty, !preferences.seasons.isEmpty, !garment.seasons.isEmpty {
            score += Set(garment.seasons).isDisjoint(with: preferences.seasons) ? -0.5 : 0.3
        }

        switch request.weather {
        case .some(.cool):
            if [.sueteres, .chamarras, .abrigos, .jeans, .pantalones].contains(garment.category) { score += 1 }
            if [.shorts, .sandalias].contains(garment.category) { score -= 3 }
        case .some(.warm):
            if [.sueteres, .abrigos].contains(garment.category) { score -= 2.5 }
            if [.shorts, .sandalias, .vestidos, .faldas, .tops].contains(garment.category) { score += 1 }
        case .none:
            break
        }

        let colors = Set(garment.colors)
        if !colors.isDisjoint(with: requestedColors) { score += 2 }
        if colors.contains(where: { preferences.favoriteColors.contains($0) }) { score += 1 }
        if colors.contains(where: { preferences.avoidedColors.contains($0) }) && colors.isDisjoint(with: requestedColors) { score -= 4 }

        if prefersComfort {
            if [.tenis, .sandalias].contains(garment.category) { score += 1.5 }
            if garment.isHeel { score -= 3 }
        }
        if preferences.preferredShoes.contains(garment.category) { score += 1 }
        if garment.isFavorite || preferences.favoriteGarmentIDs.contains(garment.id) { score += 0.7 }
        if preferences.silhouettePreferences.contains(garment.silhouette) { score += 0.5 }
        if request.feminine {
            if [.blusas, .faldas, .vestidos, .tops].contains(garment.category) { score += 1 }
            if garment.primaryColor.family == .pink { score += 0.5 }
        }
        if garment.wearCount == 0 { score += 0.3 }
        score += jitter(for: garment.id)
        return score
    }

    /// Score of a whole combination.
    func outfitScore(_ items: [GarmentSnapshot]) -> Double {
        var score = items.reduce(0) { $0 + itemScore($1) }
        let main = items.filter { $0.slot != .accessory && $0.slot != .bag }

        score += ColorHarmony.evaluate(main.map(\.primaryColor)).score * 1.5

        let patterned = main.filter { $0.pattern != .liso }
        if patterned.count >= 2 { score -= 2.5 }

        let formalities = main.map(\.formality)
        if let minF = formalities.min(), let maxF = formalities.max() {
            let spread = maxF - minF
            if spread >= 3 { score -= 3 } else if spread == 2 { score -= 1 }
        }

        // Shared style across pieces makes the look coherent.
        let styleSets = main.map { Set($0.styles) }.filter { !$0.isEmpty }
        if styleSets.count >= 2 {
            let shared = styleSets.dropFirst().reduce(styleSets[0]) { $0.intersection($1) }
            if !shared.isEmpty { score += 1.5 }
        }

        // The same accent repeated in a bag or accessory ties the look together.
        let accents = Set(main.map(\.primaryColor).filter { !$0.isNeutral })
        for complement in items where complement.slot == .bag || complement.slot == .accessory {
            if complement.primaryColor.isNeutral || accents.contains(complement.primaryColor) {
                score += 0.8
            } else if !accents.isEmpty {
                score -= 1
            }
        }
        return score
    }

    func dominantStyle(of items: [GarmentSnapshot]) -> FashionStyle? {
        var counts: [FashionStyle: Int] = [:]
        for item in items {
            for style in item.styles { counts[style, default: 0] += 1 }
        }
        let requested = request.styles
        if let match = requested.max(by: { (counts[$0] ?? 0) < (counts[$1] ?? 0) }), counts[match] != nil {
            return match
        }
        if let first = requested.first { return first }
        if let top = counts.max(by: { $0.value == $1.value ? $0.key.rawValue > $1.key.rawValue : $0.value < $1.value }) {
            return top.key
        }
        let average = items.isEmpty ? 2 : Double(items.map(\.formality).reduce(0, +)) / Double(items.count)
        switch average {
        case ..<2.5: return .casual
        case ..<3.5: return .casualChic
        default: return .elegante
        }
    }

    func explanation(for items: [GarmentSnapshot], style: FashionStyle?) -> (reasons: [String], warnings: [String]) {
        var reasons: [String] = []
        var warnings: [String] = []
        let main = items.filter { $0.slot != .accessory && $0.slot != .bag }

        for requirement in request.requirements {
            if let item = items.first(where: requirement.matches) {
                reasons.append("Incluye \(item.name.isEmpty ? requirement.phrase : item.name), como pediste.")
            }
        }

        let harmony = ColorHarmony.evaluate(main.map(\.primaryColor))
        if harmony.isClash {
            warnings.append(harmony.description)
        } else {
            reasons.append(harmony.description)
        }

        if let style, targetStyles.contains(style) || request.styles.contains(style) {
            reasons.append("Estilo \(style.displayName.lowercased()), acorde a lo que buscas.")
        } else if let style {
            reasons.append("Las prendas comparten un aire \(style.displayName.lowercased()).")
        }

        if let occasion = request.occasion {
            reasons.append("Pensado para: \(occasion.displayName.lowercased()).")
        }

        let formalities = main.map(\.formality)
        if let minF = formalities.min(), let maxF = formalities.max() {
            if maxF - minF <= 1 {
                let average = Int((Double(formalities.reduce(0, +)) / Double(formalities.count)).rounded())
                reasons.append("Todas las prendas tienen una formalidad similar (\(Formality.label(for: average).lowercased())).")
            } else if maxF - minF >= 3 {
                warnings.append("Mezcla prendas muy casuales con otras muy formales.")
            }
        }

        let patterned = main.filter { $0.pattern != .liso }
        if patterned.count == 1, let piece = patterned.first {
            reasons.append("Solo \(piece.name.isEmpty ? piece.category.singularName : piece.name) lleva estampado, así el look no se satura.")
        } else if patterned.count >= 2 {
            warnings.append("Combina dos estampados; puede verse cargado.")
        }

        if request.weather == .cool, let layer = items.first(where: { $0.slot == .outerwear || $0.category == .sueteres }) {
            reasons.append("\(layer.name.isEmpty ? layer.category.singularName.capitalized : layer.name) abriga para el clima fresco.")
        }
        if prefersComfort, let shoe = items.first(where: { $0.slot == .shoes }), !shoe.isHeel {
            reasons.append("Calzado cómodo: \(shoe.name.isEmpty ? shoe.category.singularName : shoe.name).")
        }
        if let underused = items.first(where: { $0.wearCount == 0 }), items.count > 1 {
            reasons.append("Aprovecha \(underused.name.isEmpty ? underused.category.singularName : underused.name), que aún no has usado.")
        }
        if !items.contains(where: { $0.slot == .shoes }) {
            warnings.append("Este look no incluye calzado de tu armario.")
        }
        return (reasons, warnings)
    }

    /// Small deterministic variation so "Generar alternativas" explores other combinations.
    private func jitter(for id: UUID) -> Double {
        guard seed != 0 else { return 0 }
        var hash: UInt64 = 1469598103934665603
        for byte in id.uuidString.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1099511628211
        }
        hash = (hash ^ UInt64(truncatingIfNeeded: seed)) &* 1099511628211
        return Double(hash % 1000) / 1000.0 * 1.5
    }
}
