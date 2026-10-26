import XCTest
@testable import LOOKSY

final class OutfitRequestParserTests: XCTestCase {
    private let parser = OutfitRequestParser()

    func testCoffeeRequestWithBlackJeans() {
        let request = parser.parse("Quiero un outfit femenino y casual con jeans negros para ir a tomar café")
        XCTAssertEqual(request.occasion, .cafe)
        XCTAssertTrue(request.feminine)
        XCTAssertTrue(request.styles.contains(.casual))
        XCTAssertEqual(request.requirements.count, 1)
        XCTAssertEqual(request.requirements.first?.category, .jeans)
        XCTAssertEqual(request.requirements.first?.colors, [.negro])
        XCTAssertFalse(request.paletteColors.contains(.cafe), "'café' here is the occasion, not a color")
    }

    func testBrownBootsAreAColorNotACoffee() {
        let request = parser.parse("algo con mis botas café")
        XCTAssertEqual(request.requirements.first?.category, .zapatos)
        XCTAssertEqual(request.requirements.first?.colors, [.cafe])
        XCTAssertNil(request.occasion)
    }

    func testTwoGarmentsWithColors() {
        let request = parser.parse("Combina mi blusa rosa con tenis blancos")
        XCTAssertEqual(request.requirements.map(\.category), [.blusas, .tenis])
        XCTAssertEqual(request.requirements.map(\.colors), [[.rosa], [.blanco]])
    }

    func testElegantWorkRequest() {
        let request = parser.parse("Quiero algo elegante para trabajar")
        XCTAssertEqual(request.occasion, .trabajo)
        XCTAssertTrue(request.styles.contains(.elegante))
        XCTAssertTrue(request.requirements.isEmpty)
    }

    func testNoHeelsRestriction() {
        let request = parser.parse("Quiero verme arreglada sin usar tacones")
        XCTAssertTrue(request.excludeHeels)
        XCTAssertTrue(request.requirements.isEmpty, "Negated garments are restrictions, not requirements")
        XCTAssertGreaterThanOrEqual(request.formalityTarget ?? 0, 3)
    }

    func testCoolWeather() {
        let request = parser.parse("Necesito un outfit femenino para clima fresco")
        XCTAssertEqual(request.weather, .cool)
        XCTAssertTrue(request.feminine)
        XCTAssertTrue(request.seasons.contains(.otono))
    }

    func testPinterestDate() {
        let request = parser.parse("Quiero algo estilo Pinterest para una cita")
        XCTAssertEqual(request.occasion, .cita)
        XCTAssertTrue(request.styles.contains(.pinterestAesthetic))
    }

    func testCasualChicIsNotPlainCasual() {
        let request = parser.parse("un look casual chic")
        XCTAssertEqual(request.styles, [.casualChic])
    }

    func testExcludedColorAndCategory() {
        let request = parser.parse("algo sin negro y sin falda")
        XCTAssertTrue(request.excludedColors.contains(.negro))
        XCTAssertTrue(request.excludedCategories.contains(.faldas))
        XCTAssertTrue(request.requirements.isEmpty)
    }

    func testMultiWordColor() {
        let request = parser.parse("pantalón azul marino")
        XCTAssertEqual(request.requirements.first?.category, .pantalones)
        XCTAssertEqual(request.requirements.first?.colors, [.azulMarino])
    }

    func testNamedGarmentIsRecognized() {
        let linen = GarmentSnapshot(id: UUID(), name: "Blusa de lino", category: .blusas, primaryColor: .blanco)
        let request = OutfitRequestParser(wardrobe: [linen]).parse("quiero usar mi blusa de lino")
        XCTAssertEqual(request.requirements.first?.garmentID, linen.id)
    }

    func testDenimJacketIsNotJeans() {
        let request = parser.parse("chamarra de mezclilla")
        XCTAssertEqual(request.requirements.map(\.category), [.chamarras])
    }
}
