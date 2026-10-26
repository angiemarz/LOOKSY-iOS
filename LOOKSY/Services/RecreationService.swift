import Foundation

/// A garment the user identified in a reference look.
struct TargetPiece: Codable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var slot: OutfitSlot
    var category: GarmentCategory?
    var color: FashionColor?

    var description: String {
        let name = category?.singularName ?? slot.displayName.lowercased()
        guard let color else { return name }
        if let category { return SpanishGrammar.phrase(category, color) }
        return "\(name) \(color.adjective)"
    }
}

/// What the user described about the reference outfit.
struct RecreationTarget: Codable, Hashable, Sendable {
    var pieces: [TargetPiece] = []
    var colors: [FashionColor] = []
    var style: FashionStyle?
    var formality: Int = 2

    var isEmpty: Bool { pieces.isEmpty && colors.isEmpty && style == nil }
}

/// One explainable comparison point (no invented percentages).
struct ComparisonCriterion: Hashable, Identifiable, Sendable {
    enum Status: Sendable { case match, partial, miss, unknown }
    var id: String { title }
    var title: String
    var detail: String
    var status: Status
}

struct Recreation: Identifiable, Sendable {
    enum Kind: String, CaseIterable, Sendable {
        case closest
        case wardrobeOnly
        case creative

        var title: String {
            switch self {
            case .closest: return "Recreación más parecida"
            case .wardrobeOnly: return "Solo con mi armario"
            case .creative: return "Interpretación creativa"
            }
        }

        var subtitle: String {
            switch self {
            case .closest: return "Usa solo prendas muy parecidas y te dice qué falta."
            case .wardrobeOnly: return "Completa el look con tus sustitutos más cercanos."
            case .creative: return "Mismo estilo y formalidad, con libertad de color."
            }
        }
    }

    var kind: Kind
    var items: [GarmentSnapshot]
    var notes: [String]
    var criteria: [ComparisonCriterion]
    var id: String { kind.rawValue }
}

/// Matches a described reference look against the wardrobe.
struct RecreationService {
    /// Similarity of a garment to a target piece. Higher is better.
    static func similarity(_ garment: GarmentSnapshot, to piece: TargetPiece, target: RecreationTarget) -> Double {
        var score = 0.0
        if let category = piece.category {
            if garment.category == category { score += 3 } else if garment.slot == piece.slot { score += 1.5 } else { return -100 }
        } else if garment.slot == piece.slot {
            score += 2
        } else {
            return -100
        }
        if let color = piece.color {
            if garment.colors.contains(color) {
                score += garment.primaryColor == color ? 3 : 2
            } else if garment.colors.contains(where: { $0.family == color.family }) {
                score += 2
            } else if garment.primaryColor.isNeutral && color.isNeutral {
                score += 0.5
            } else {
                score -= 1
            }
        }
        if let style = target.style, garment.styles.contains(style) { score += 1 }
        score -= abs(Double(garment.formality - target.formality)) * 0.5
        return score
    }

    /// Strong match: right slot and same color family when a color was given.
    static func isClose(_ garment: GarmentSnapshot, to piece: TargetPiece) -> Bool {
        guard garment.slot == piece.slot else { return false }
        if let category = piece.category, garment.category != category {
            // Close categories in the same slot (blusa ↔ top) are accepted only with the same color family.
            guard piece.color != nil else { return false }
        }
        guard let color = piece.color else { return true }
        return garment.colors.contains { $0 == color || $0.family == color.family }
    }

    func recreate(target: RecreationTarget, wardrobe: [GarmentSnapshot], preferences: UserPreferences = UserPreferences()) -> [Recreation] {
        let available = wardrobe.filter(\.isAvailable)
        var results: [Recreation] = []

        // 1. Closest: only strong matches.
        var used = Set<UUID>()
        var closestItems: [GarmentSnapshot] = []
        var closestNotes: [String] = []
        for piece in target.pieces {
            let best = available
                .filter { !used.contains($0.id) && Self.isClose($0, to: piece) }
                .max { Self.similarity($0, to: piece, target: target) < Self.similarity($1, to: piece, target: target) }
            if let best {
                closestItems.append(best)
                used.insert(best.id)
                closestNotes.append("\(piece.description.capitalizedFirst) → \(best.name)")
            } else {
                closestNotes.append("Falta: \(piece.description) (no hay una prenda parecida en tu armario).")
            }
        }
        results.append(Recreation(kind: .closest, items: closestItems, notes: closestNotes, criteria: Self.criteria(target: target, items: closestItems, style: nil)))

        // 2. Wardrobe only: always the nearest substitute, then complete the outfit.
        used = []
        var ownItems: [GarmentSnapshot] = []
        var ownNotes: [String] = []
        for piece in target.pieces {
            let best = available
                .filter { !used.contains($0.id) && $0.slot == piece.slot }
                .max { Self.similarity($0, to: piece, target: target) < Self.similarity($1, to: piece, target: target) }
            if let best {
                ownItems.append(best)
                used.insert(best.id)
                if Self.isClose(best, to: piece) {
                    ownNotes.append("\(piece.description.capitalizedFirst) → \(best.name)")
                } else {
                    ownNotes.append("Sustituí \(piece.description) por \(best.name).")
                }
            } else {
                ownNotes.append("No tienes ninguna prenda de tipo \(piece.slot.displayName.lowercased()).")
            }
        }
        ownItems = complete(ownItems, available: available, target: target, preferences: preferences, notes: &ownNotes)
        results.append(Recreation(kind: .wardrobeOnly, items: ownItems, notes: ownNotes, criteria: Self.criteria(target: target, items: ownItems, style: nil)))

        // 3. Creative: same style/formality, palette as inspiration, via the outfit engine.
        var request = OutfitRequest()
        if let style = target.style { request.styles = [style] }
        request.formalityTarget = target.formality
        request.paletteColors = Array((target.colors + target.pieces.compactMap(\.color)).prefix(2))
        let exclude: Set<String> = [OutfitRecommendationService.signature(closestItems), OutfitRecommendationService.signature(ownItems)]
        let engineResult = OutfitRecommendationService(maxSuggestions: 1).recommend(request: request, wardrobe: available, preferences: preferences, excludingSignatures: exclude, variationSeed: 7)
        if let creative = engineResult.suggestions.first {
            results.append(Recreation(kind: .creative, items: creative.items, notes: creative.reasons, criteria: Self.criteria(target: target, items: creative.items, style: creative.style)))
        } else {
            results.append(Recreation(kind: .creative, items: [], notes: engineResult.missing.isEmpty ? ["No hay suficientes prendas para una versión distinta."] : engineResult.missing, criteria: []))
        }
        return results
    }

    /// Adds the missing essentials (top/bottom or dress, shoes) using the best harmonizing garments.
    private func complete(_ items: [GarmentSnapshot], available: [GarmentSnapshot], target: RecreationTarget, preferences: UserPreferences, notes: inout [String]) -> [GarmentSnapshot] {
        var result = items
        let context = ScoringContext(
            request: OutfitRequest(styles: target.style.map { [$0] } ?? [], formalityTarget: target.formality),
            preferences: preferences,
            seed: 0
        )
        let slots = Set(result.map(\.slot))
        var needed: [OutfitSlot] = []
        if !slots.contains(.onePiece) {
            if !slots.contains(.top) { needed.append(.top) }
            if !slots.contains(.bottom) { needed.append(.bottom) }
        }
        if !slots.contains(.shoes) { needed.append(.shoes) }
        for slot in needed {
            let used = Set(result.map(\.id))
            let options = available.filter { $0.slot == slot && !used.contains($0.id) }
            if let best = options.max(by: { context.outfitScore(result + [$0]) < context.outfitScore(result + [$1]) }) {
                result.append(best)
                notes.append("Añadí \(best.name) para completar el look.")
            }
        }
        return result.sorted { $0.slot.sortOrder < $1.slot.sortOrder }
    }

    /// Explainable comparison between a reference and an outfit.
    static func criteria(target: RecreationTarget, items: [GarmentSnapshot], style: FashionStyle?) -> [ComparisonCriterion] {
        var criteria: [ComparisonCriterion] = []
        if !target.pieces.isEmpty {
            var used = Set<UUID>()
            var covered = 0
            for piece in target.pieces {
                if let match = items.first(where: { !used.contains($0.id) && isClose($0, to: piece) }) {
                    covered += 1
                    used.insert(match.id)
                }
            }
            let status: ComparisonCriterion.Status = covered == target.pieces.count ? .match : (covered == 0 ? .miss : .partial)
            criteria.append(ComparisonCriterion(title: "Prendas equivalentes", detail: "\(covered) de \(target.pieces.count) prendas de la referencia tienen un equivalente cercano.", status: status))
        }
        let targetColors = Array(Set(target.colors + target.pieces.compactMap(\.color)))
        if !targetColors.isEmpty {
            let outfitColors = items.flatMap(\.colors)
            let matched = targetColors.filter { color in outfitColors.contains { $0 == color || $0.family == color.family } }
            let status: ComparisonCriterion.Status = matched.count == targetColors.count ? .match : (matched.isEmpty ? .miss : .partial)
            criteria.append(ComparisonCriterion(
                title: "Colores",
                detail: "\(matched.count) de \(targetColors.count) colores de la referencia aparecen en tu look\(matched.isEmpty ? "" : " (\(matched.map(\.adjective).joined(separator: ", ")))").",
                status: status
            ))
        }
        if let targetStyle = target.style {
            let outfitStyles = Set(items.flatMap(\.styles) + (style.map { [$0] } ?? []))
            if outfitStyles.isEmpty {
                criteria.append(ComparisonCriterion(title: "Estilo", detail: "Tus prendas no tienen estilo asignado; no se puede comparar.", status: .unknown))
            } else if outfitStyles.contains(targetStyle) {
                criteria.append(ComparisonCriterion(title: "Estilo", detail: "Ambos son \(targetStyle.displayName.lowercased()).", status: .match))
            } else if !outfitStyles.isDisjoint(with: targetStyle.relatedStyles) {
                criteria.append(ComparisonCriterion(title: "Estilo", detail: "Estilo cercano a \(targetStyle.displayName.lowercased()).", status: .partial))
            } else {
                criteria.append(ComparisonCriterion(title: "Estilo", detail: "Tu look tiene otro estilo.", status: .miss))
            }
        }
        if !items.isEmpty {
            let average = Double(items.map(\.formality).reduce(0, +)) / Double(items.count)
            let difference = abs(average - Double(target.formality))
            let status: ComparisonCriterion.Status = difference <= 0.75 ? .match : (difference <= 1.5 ? .partial : .miss)
            criteria.append(ComparisonCriterion(
                title: "Formalidad",
                detail: "Referencia: \(Formality.label(for: target.formality).lowercased()); tu look: \(Formality.label(for: Int(average.rounded())).lowercased()).",
                status: status
            ))
        }
        return criteria
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
