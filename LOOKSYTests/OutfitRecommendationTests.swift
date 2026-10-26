import XCTest
@testable import LOOKSY

final class OutfitRecommendationTests: XCTestCase {
    private func garment(_ name: String, _ category: GarmentCategory, _ color: FashionColor, styles: [FashionStyle] = [], formality: Int? = nil, tags: [String] = [], available: Bool = true) -> GarmentSnapshot {
        GarmentSnapshot(
            id: UUID(), name: name, category: category, primaryColor: color,
            styles: styles, formality: formality ?? category.defaultFormality, tags: tags, isAvailable: available
        )
    }

    private lazy var wardrobe: [GarmentSnapshot] = [
        garment("Blusa rosa", .blusas, .rosa, styles: [.casualChic, .romantico]),
        garment("Blusa blanca", .blusas, .blanco, styles: [.minimalista, .oficina], formality: 3),
        garment("Top negro", .tops, .negro, styles: [.casual]),
        garment("Camisa celeste", .camisas, .celeste, styles: [.oficina], formality: 4),
        garment("Jeans negros", .jeans, .negro, styles: [.casual, .casualChic]),
        garment("Jeans azules", .jeans, .mezclilla, styles: [.casual]),
        garment("Pantalón beige", .pantalones, .beige, styles: [.oficina, .oldMoney], formality: 4),
        garment("Falda verde", .faldas, .verde, styles: [.romantico]),
        garment("Tenis blancos", .tenis, .blanco, styles: [.casual]),
        garment("Zapatos negros", .zapatos, .negro, styles: [.oficina], formality: 4),
        garment("Tacones nude", .zapatos, .beige, styles: [.elegante], formality: 4, tags: ["tacones"]),
        garment("Bolso camel", .bolsos, .camel),
        garment("Blazer negro", .chamarras, .negro, styles: [.oficina], formality: 4)
    ]

    private let engine = OutfitRecommendationService()

    func testNeverInventsGarments() {
        let ids = Set(wardrobe.map(\.id))
        let result = engine.recommend(request: OutfitRequest(), wardrobe: wardrobe)
        XCTAssertFalse(result.suggestions.isEmpty)
        for suggestion in result.suggestions {
            XCTAssertTrue(Set(suggestion.garmentIDs).isSubset(of: ids))
        }
    }

    func testGeneratesBetweenThreeAndSixCompleteOutfits() {
        let result = engine.recommend(request: OutfitRequest(), wardrobe: wardrobe)
        XCTAssertGreaterThanOrEqual(result.suggestions.count, 3)
        XCTAssertLessThanOrEqual(result.suggestions.count, 6)
        for suggestion in result.suggestions {
            let slots = Set(suggestion.items.map(\.slot))
            XCTAssertTrue(slots.contains(.onePiece) || (slots.contains(.top) && slots.contains(.bottom)), "Outfit must be complete")
            XCTAssertTrue(slots.contains(.shoes))
            XCTAssertEqual(suggestion.items.count, Set(suggestion.items.map(\.slot)).count, "One garment per slot")
            XCTAssertFalse(suggestion.reasons.isEmpty)
        }
    }

    func testNoDuplicateOutfits() {
        let result = engine.recommend(request: OutfitRequest(), wardrobe: wardrobe)
        let signatures = result.suggestions.map(\.signature)
        XCTAssertEqual(signatures.count, Set(signatures).count)
    }

    func testRequiredGarmentIsAlwaysIncluded() {
        let request = OutfitRequestParser().parse("algo casual con mis jeans negros para un café")
        let result = engine.recommend(request: request, wardrobe: wardrobe)
        let jeansID = wardrobe.first { $0.name == "Jeans negros" }!.id
        XCTAssertFalse(result.suggestions.isEmpty)
        for suggestion in result.suggestions {
            XCTAssertTrue(suggestion.garmentIDs.contains(jeansID))
        }
    }

    func testTwoRequiredPieces() {
        let request = OutfitRequestParser().parse("Combina mi blusa rosa con tenis blancos")
        let result = engine.recommend(request: request, wardrobe: wardrobe)
        XCTAssertFalse(result.suggestions.isEmpty)
        for suggestion in result.suggestions {
            XCTAssertTrue(suggestion.items.contains { $0.name == "Blusa rosa" })
            XCTAssertTrue(suggestion.items.contains { $0.name == "Tenis blancos" })
        }
    }

    func testExcludesHeels() {
        let request = OutfitRequestParser().parse("quiero verme arreglada sin usar tacones")
        let result = engine.recommend(request: request, wardrobe: wardrobe)
        XCTAssertFalse(result.suggestions.isEmpty)
        XCTAssertFalse(result.suggestions.flatMap(\.items).contains { $0.name == "Tacones nude" })
    }

    func testAvoidedColorsArePrunedUnlessRequested() {
        var preferences = UserPreferences()
        preferences.avoidedColors = [.verde]
        let result = engine.recommend(request: OutfitRequest(), wardrobe: wardrobe, preferences: preferences)
        XCTAssertFalse(result.suggestions.flatMap(\.items).contains { $0.primaryColor == .verde })

        let explicit = OutfitRequestParser().parse("con mi falda verde")
        let explicitResult = engine.recommend(request: explicit, wardrobe: wardrobe, preferences: preferences)
        XCTAssertTrue(explicitResult.suggestions.allSatisfy { $0.items.contains { $0.name == "Falda verde" } })
    }

    func testUnavailableGarmentsAreSkipped() {
        var items = wardrobe
        let index = items.firstIndex { $0.name == "Tenis blancos" }!
        items[index].isAvailable = false
        let result = engine.recommend(request: OutfitRequest(), wardrobe: items)
        XCTAssertFalse(result.suggestions.flatMap(\.items).contains { $0.name == "Tenis blancos" })
    }

    func testMissingRequirementIsExplained() {
        let request = OutfitRequestParser().parse("con mi vestido rojo")
        let result = engine.recommend(request: request, wardrobe: wardrobe)
        XCTAssertTrue(result.missing.contains { $0.contains("vestido") })
    }

    func testIncompleteWardrobeReturnsNoOutfitAndExplains() {
        let tops = [garment("Blusa", .blusas, .blanco), garment("Top", .tops, .negro)]
        let result = engine.recommend(request: OutfitRequest(), wardrobe: tops)
        XCTAssertTrue(result.suggestions.isEmpty)
        XCTAssertFalse(result.missing.isEmpty)
    }

    func testEmptyWardrobe() {
        let result = engine.recommend(request: OutfitRequest(), wardrobe: [])
        XCTAssertTrue(result.suggestions.isEmpty)
        XCTAssertFalse(result.missing.isEmpty)
    }

    func testAlternativesExcludePreviousSignatures() {
        let first = engine.recommend(request: OutfitRequest(), wardrobe: wardrobe)
        let shown = Set(first.suggestions.map(\.signature))
        let second = engine.recommend(request: OutfitRequest(), wardrobe: wardrobe, excludingSignatures: shown, variationSeed: 1)
        XCTAssertTrue(second.suggestions.allSatisfy { !shown.contains($0.signature) })
    }

    func testCoolWeatherAddsLayer() {
        let request = OutfitRequestParser().parse("outfit para clima frío")
        let result = engine.recommend(request: request, wardrobe: wardrobe)
        XCTAssertTrue(result.suggestions.contains { $0.items.contains { $0.slot == .outerwear } })
    }

    func testDeterministic() {
        let a = engine.recommend(request: OutfitRequest(), wardrobe: wardrobe).suggestions.map(\.signature)
        let b = engine.recommend(request: OutfitRequest(), wardrobe: wardrobe).suggestions.map(\.signature)
        XCTAssertEqual(a, b)
    }

    func testSwapAlternativesStayInSlotAndExist() {
        let result = engine.recommend(request: OutfitRequest(), wardrobe: wardrobe)
        let suggestion = try! XCTUnwrap(result.suggestions.first)
        let options = engine.alternatives(for: .shoes, in: suggestion, wardrobe: wardrobe, request: OutfitRequest())
        XCTAssertFalse(options.isEmpty)
        XCTAssertTrue(options.allSatisfy { $0.slot == .shoes && !suggestion.garmentIDs.contains($0.id) })
    }

    func testColorHarmonyRules() {
        XCTAssertGreaterThan(ColorHarmony.evaluate([.rosa, .negro, .blanco]).score, 0)
        XCTAssertGreaterThan(ColorHarmony.evaluate([.negro, .blanco, .beige]).score, 0)
        XCTAssertLessThan(ColorHarmony.evaluate([.rojo, .verde, .morado, .amarillo]).score, 0)
        XCTAssertEqual(ColorHarmony.hueDistance(350, 10), 20, accuracy: 0.001)
    }
}
