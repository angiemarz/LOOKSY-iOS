import XCTest
@testable import LOOKSY

final class ColorTests: XCTestCase {
    func testHexRoundTrip() {
        let color = RGBColor(hex: "#D8A7B1")
        XCTAssertEqual(color?.hexString, "#D8A7B1")
        XCTAssertNil(RGBColor(hex: "nope"))
    }

    func testNearestNamedColor() {
        XCTAssertEqual(FashionColor.nearest(to: RGBColor(rgb: 0x000000)), .negro)
        XCTAssertEqual(FashionColor.nearest(to: RGBColor(rgb: 0xFFFFFF)), .blanco)
        XCTAssertEqual(FashionColor.nearest(to: RGBColor(rgb: 0xD00000)), .rojo)
        XCTAssertEqual(FashionColor.nearest(to: RGBColor(rgb: 0x1E2B48)), .azulMarino)
    }

    func testEveryNamedColorMapsToItself() {
        for color in FashionColor.allCases where color != .multicolor {
            XCTAssertEqual(FashionColor.nearest(to: color.rgb), color, "\(color) should map to itself")
        }
    }

    func testNeutralsAndFamilies() {
        XCTAssertTrue(FashionColor.mezclilla.isNeutral)
        XCTAssertFalse(FashionColor.rosa.isNeutral)
        XCTAssertEqual(FashionColor.celeste.family, FashionColor.azulMarino.family)
    }

    func testColorAnalysisIgnoresBackground() throws {
        let image = TestSupport.garmentPhoto(UIColor(red: 0.85, green: 0.1, blue: 0.1, alpha: 1))
        let analysis = try XCTUnwrap(ImageProcessingService.analyzeColors(of: image))
        XCTAssertEqual(analysis.primary, .rojo)
    }

    func testColorAnalysisOfSolidImage() throws {
        let image = TestSupport.solidImage(UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1))
        let analysis = try XCTUnwrap(ImageProcessingService.analyzeColors(of: image))
        XCTAssertEqual(analysis.primary, .negro)
    }
}
