import XCTest
@testable import LOOKSY

final class PinterestAndCollageTests: XCTestCase {
    func testSearchURLIsAuthenticPinterestSearch() {
        let url = PinterestSearchService.searchURL(for: "pink blouse blue jeans outfit")
        XCTAssertEqual(url.host, "www.pinterest.com")
        XCTAssertEqual(url.path, "/search/pins")
        XCTAssertTrue(url.absoluteString.contains("q=pink%20blouse%20blue%20jeans%20outfit"))
    }

    func testQueriesForGarmentsInBothLanguages() {
        let blouse = GarmentSnapshot(id: UUID(), name: "Blusa", category: .blusas, primaryColor: .rosa)
        let jeans = GarmentSnapshot(id: UUID(), name: "Jeans", category: .jeans, primaryColor: .mezclilla)
        let sneakers = GarmentSnapshot(id: UUID(), name: "Tenis", category: .tenis, primaryColor: .blanco)
        let queries = PinterestSearchService.queries(for: [blouse, jeans, sneakers], style: .casual, feminine: true)
        let texts = queries.map(\.text)
        XCTAssertTrue(texts.contains("pink blouse blue jeans outfit"))
        XCTAssertTrue(texts.contains("blusa rosa jeans outfit"))
        XCTAssertTrue(texts.contains("casual feminine pink outfit"))
        XCTAssertTrue(texts.contains("pink blouse sneakers pinterest aesthetic"))
        XCTAssertTrue(queries.contains { $0.language == .spanish })
        XCTAssertEqual(texts.count, Set(texts).count)
    }

    func testPinterestURLValidation() {
        XCTAssertTrue(PinterestSearchService.isPinterestURL(URL(string: "https://pin.it/abc123")!))
        XCTAssertTrue(PinterestSearchService.isPinterestURL(URL(string: "https://mx.pinterest.com/pin/123/")!))
        XCTAssertFalse(PinterestSearchService.isPinterestURL(URL(string: "https://example.com")!))
        XCTAssertEqual(PinterestSearchService.normalizedURL(from: "pin.it/xyz")?.absoluteString, "https://pin.it/xyz")
        XCTAssertNil(PinterestSearchService.normalizedURL(from: "   "))
    }

    func testSpanishAgreement() {
        XCTAssertEqual(SpanishGrammar.phrase(.jeans, .negro), "jeans negros")
        XCTAssertEqual(SpanishGrammar.phrase(.blusas, .blanco), "blusa blanca")
        XCTAssertEqual(SpanishGrammar.phrase(.sandalias, .dorado), "sandalias doradas")
        XCTAssertEqual(SpanishGrammar.phrase(.tenis, .rosa), "tenis rosa")
    }

    func testFlatLayLayoutOrder() {
        let top = CollageLayoutEngine.Input(garmentID: UUID(), slot: .top, imageAspect: 1.1)
        let bottom = CollageLayoutEngine.Input(garmentID: UUID(), slot: .bottom, imageAspect: 1.5)
        let shoes = CollageLayoutEngine.Input(garmentID: UUID(), slot: .shoes, imageAspect: 0.6)
        let bag = CollageLayoutEngine.Input(garmentID: UUID(), slot: .bag, imageAspect: 1)
        for aspect in CollageAspect.allCases {
            let items = CollageLayoutEngine.layout([top, bottom, shoes, bag], aspect: aspect)
            XCTAssertEqual(items.count, 4)
            let byID = Dictionary(uniqueKeysWithValues: items.map { ($0.garmentID, $0) })
            XCTAssertLessThan(byID[top.garmentID]!.centerY, byID[bottom.garmentID]!.centerY)
            XCTAssertLessThan(byID[bottom.garmentID]!.centerY, byID[shoes.garmentID]!.centerY)
            XCTAssertGreaterThan(byID[bag.garmentID]!.centerX, byID[top.garmentID]!.centerX)
            for item in items {
                XCTAssertTrue((0...1).contains(item.centerX) && (0...1).contains(item.centerY))
                let height = CollageLayoutEngine.heightFraction(of: item, imageAspect: 1.5, canvasAspect: aspect)
                XCTAssertGreaterThan(height, 0)
            }
            XCTAssertEqual(Set(items.map(\.zIndex)).count, items.count)
        }
    }

    func testLayoutFitsTallImagesInsideBox() {
        let tall = CollageLayoutEngine.Input(garmentID: UUID(), slot: .bottom, imageAspect: 3)
        let item = CollageLayoutEngine.layout([tall], aspect: .square)[0]
        let height = CollageLayoutEngine.heightFraction(of: item, imageAspect: 3, canvasAspect: .square)
        XCTAssertLessThanOrEqual(height, 0.41)
    }
}
