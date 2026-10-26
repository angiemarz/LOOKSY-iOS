import SwiftUI
import SwiftData
import Observation

/// Drives "Crear outfit": parsing, recommendations, swaps and saving.
@MainActor
@Observable
final class StylistViewModel {
    var text = ""
    var seedGarmentID: UUID?
    var isGenerating = false
    var request: OutfitRequest?
    var suggestions: [OutfitSuggestion] = []
    var missing: [String] = []
    var infoMessage: String?
    var savedLookIDs: [UUID: UUID] = [:]

    /// Edited collages per suggestion.
    var compositions: [UUID: CollageComposition] = [:]
    /// Loaded images per garment.
    private(set) var pieces: [UUID: CollagePiece] = [:]

    private var shownSignatures: Set<String> = []
    private var seed = 0
    private var wardrobe: [GarmentSnapshot] = []

    static let examples = [
        "Quiero un outfit femenino y casual con jeans negros para ir a tomar café",
        "Arma un outfit casual con mis jeans negros",
        "Quiero algo elegante para trabajar",
        "Combina mi blusa rosa con tenis blancos",
        "Quiero algo estilo Pinterest para una cita",
        "Necesito un outfit femenino para clima fresco",
        "Quiero verme arreglada sin usar tacones"
    ]

    private let engine = OutfitRecommendationService()

    var canGenerate: Bool {
        !text.trimmed.isEmpty || seedGarmentID != nil
    }

    var pinterestQueries: [PinterestQuery] {
        guard let request else { return [] }
        return PinterestSearchService.queries(for: request)
    }

    // MARK: Generation

    func generate(garments: [Garment], preferences: UserPreferences) async {
        wardrobe = garments.map { GarmentSnapshot($0) }
        var parsed = OutfitRequestParser(wardrobe: wardrobe).parse(text)
        if let seedGarmentID, let seed = wardrobe.first(where: { $0.id == seedGarmentID }),
           !parsed.requirements.contains(where: { $0.garmentID == seedGarmentID }) {
            parsed.requirements.removeAll { $0.slot == seed.slot && $0.garmentID == nil }
            parsed.requirements.append(ItemRequirement(category: seed.category, slot: seed.slot, garmentID: seed.id, phrase: seed.name))
        }
        request = parsed
        shownSignatures = []
        seed = 0
        compositions = [:]
        savedLookIDs = [:]
        await run(parsed, preferences: preferences)
    }

    /// New set of combinations that were not shown yet.
    func generateAlternatives(preferences: UserPreferences) async {
        guard let request else { return }
        seed += 1
        await run(request, preferences: preferences)
    }

    /// Replaces one card with a different combination.
    func alternative(to suggestion: OutfitSuggestion, preferences: UserPreferences) async {
        guard let request, let index = suggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
        seed += 1
        let engine = self.engine
        let wardrobe = self.wardrobe
        let excluded = shownSignatures
        let seed = self.seed
        let result = await Task.detached(priority: .userInitiated) {
            engine.recommend(request: request, wardrobe: wardrobe, preferences: preferences, excludingSignatures: excluded, variationSeed: seed)
        }.value
        guard let replacement = result.suggestions.first else {
            infoMessage = "No hay otra combinación distinta para este look con tu armario actual."
            return
        }
        shownSignatures.insert(replacement.signature)
        compositions[suggestion.id] = nil
        await loadPieces(for: replacement.items)
        withAnimation { suggestions[index] = replacement }
    }

    private func run(_ request: OutfitRequest, preferences: UserPreferences) async {
        isGenerating = true
        infoMessage = nil
        let engine = self.engine
        let wardrobe = self.wardrobe
        let excluded = shownSignatures
        let seed = self.seed
        let result = await Task.detached(priority: .userInitiated) {
            engine.recommend(request: request, wardrobe: wardrobe, preferences: preferences, excludingSignatures: excluded, variationSeed: seed)
        }.value
        missing = result.missing
        if result.suggestions.isEmpty && !suggestions.isEmpty && seed > 0 {
            infoMessage = "Ya viste todas las combinaciones distintas para esta solicitud."
        } else {
            for suggestion in result.suggestions { shownSignatures.insert(suggestion.signature) }
            await loadPieces(for: result.suggestions.flatMap(\.items))
            withAnimation(.easeInOut) {
                suggestions = result.suggestions
            }
        }
        isGenerating = false
        AppLogger.stylist.info("Generated \(result.suggestions.count) suggestions")
    }

    // MARK: Editing

    func alternatives(for slot: OutfitSlot, in suggestion: OutfitSuggestion, preferences: UserPreferences) -> [GarmentSnapshot] {
        engine.alternatives(for: slot, in: suggestion, wardrobe: wardrobe, request: request ?? OutfitRequest(), preferences: preferences)
    }

    func swap(_ slot: OutfitSlot, in suggestion: OutfitSuggestion, with garment: GarmentSnapshot, preferences: UserPreferences) async {
        guard let index = suggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
        var items = suggestion.items.filter { $0.slot != slot }
        // A dress replaces top + bottom and vice versa.
        if garment.slot == .onePiece { items.removeAll { $0.slot == .top || $0.slot == .bottom } }
        if garment.slot == .top || garment.slot == .bottom { items.removeAll { $0.slot == .onePiece } }
        items.append(garment)
        await loadPieces(for: [garment])
        let rebuilt = engine.rebuild(suggestion, items: items, request: request ?? OutfitRequest(), preferences: preferences)
        compositions[suggestion.id] = nil
        savedLookIDs[suggestion.id] = nil
        withAnimation { suggestions[index] = rebuilt }
    }

    /// Applies an edited collage; the outfit follows the garments on the canvas.
    func applyEditedCollage(_ composition: CollageComposition, newPieces: [CollagePiece], to suggestion: OutfitSuggestion, preferences: UserPreferences) {
        for piece in newPieces { pieces[piece.id] = piece }
        guard let index = suggestions.firstIndex(where: { $0.id == suggestion.id }) else { return }
        let ids = composition.garmentIDs
        let items = ids.compactMap { id in pieces[id]?.garment }
        if Set(items.map(\.id)) != Set(suggestion.garmentIDs) {
            suggestions[index] = engine.rebuild(suggestion, items: items, request: request ?? OutfitRequest(), preferences: preferences)
        }
        compositions[suggestion.id] = composition
        savedLookIDs[suggestion.id] = nil
    }

    func composition(for suggestion: OutfitSuggestion) -> CollageComposition {
        if let edited = compositions[suggestion.id] { return edited }
        return CollageService.automaticComposition(for: collagePieces(for: suggestion))
    }

    func collagePieces(for suggestion: OutfitSuggestion) -> [CollagePiece] {
        suggestion.items.map { pieces[$0.id] ?? CollagePiece(garment: $0, image: nil) }
    }

    private func loadPieces(for items: [GarmentSnapshot]) async {
        for item in items where pieces[item.id]?.image == nil {
            var image: UIImage?
            if let file = fileName(for: item.id) {
                image = await ImageStorageService.shared.loadImage(file)
            }
            pieces[item.id] = CollagePiece(garment: item, image: image)
        }
    }

    /// File names are resolved through the latest garments list.
    var collageFileNames: [UUID: String] = [:]

    private func fileName(for id: UUID) -> String? {
        collageFileNames[id]
    }

    func updateFileNames(from garments: [Garment]) {
        collageFileNames = Dictionary(garments.compactMap { garment in
            garment.collageImageFileName.map { (garment.id, $0) }
        }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Saving

    func save(_ suggestion: OutfitSuggestion, context: ModelContext) {
        guard savedLookIDs[suggestion.id] == nil else { return }
        let composition = composition(for: suggestion)
        do {
            let look = try LookService(context: context).saveLook(
                name: suggestion.name,
                garmentIDs: suggestion.garmentIDs,
                composition: composition,
                pieces: collagePieces(for: suggestion),
                style: suggestion.style,
                occasion: suggestion.occasion,
                explanation: suggestion.reasons.joined(separator: "\n")
            )
            savedLookIDs[suggestion.id] = look.id
            infoMessage = "“\(suggestion.name)” se guardó en Mis looks."
        } catch {
            infoMessage = "No se pudo guardar el look."
        }
    }
}
