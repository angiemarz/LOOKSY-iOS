import XCTest
@testable import LOOKSY

final class StorageAndModelTests: XCTestCase {
    func testImageStorageSaveLoadDelete() async throws {
        let storage = ImageStorageService(directory: TestSupport.temporaryDirectory())
        let files = try storage.savePhoto(TestSupport.solidImage(.blue, size: CGSize(width: 3000, height: 2000)))
        XCTAssertTrue(storage.fileExists(files.original))
        XCTAssertTrue(storage.fileExists(files.thumbnail))
        storage.clearCache()

        let loaded = await storage.loadImage(files.original)
        let image = try XCTUnwrap(loaded)
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height) * image.scale, ImageStorageService.maxOriginalDimension + 1)

        storage.delete(files.original)
        XCTAssertFalse(storage.fileExists(files.original))
        XCTAssertEqual(storage.removeOrphans(referenced: []), 1)
    }

    func testCollageZOrderOperations() {
        let a = CollageItem(garmentID: UUID(), centerX: 0.5, centerY: 0.5, width: 0.3, zIndex: 0)
        let b = CollageItem(garmentID: UUID(), centerX: 0.5, centerY: 0.5, width: 0.3, zIndex: 1)
        let c = CollageItem(garmentID: UUID(), centerX: 0.5, centerY: 0.5, width: 0.3, zIndex: 2)
        var composition = CollageComposition(items: [a, b, c])

        composition.bringToFront(a.id)
        XCTAssertEqual(composition.sortedItems.map(\.id), [b.id, c.id, a.id])
        composition.sendToBack(c.id)
        XCTAssertEqual(composition.sortedItems.map(\.id), [c.id, b.id, a.id])
        composition.moveForward(c.id)
        XCTAssertEqual(composition.sortedItems.map(\.id), [b.id, c.id, a.id])
        composition.moveBackward(a.id)
        XCTAssertEqual(composition.sortedItems.map(\.id), [b.id, a.id, c.id])
        composition.remove(b.id)
        XCTAssertEqual(composition.sortedItems.map(\.zIndex), [0, 1])
    }

    func testCollageCompositionCodable() throws {
        var composition = CollageComposition()
        composition.backgroundHex = "#FFFFFF"
        composition.items = [CollageItem(garmentID: UUID(), centerX: 0.2, centerY: 0.8, width: 0.25, rotation: -15, zIndex: 3)]
        let data = try JSONEncoder().encode(composition)
        let decoded = try JSONDecoder().decode(CollageComposition.self, from: data)
        XCTAssertEqual(decoded, composition)
    }

    func testPreferencesTolerantDecoding() throws {
        let json = #"{"displayName":"Ana","favoriteColors":["rosa","colorInexistente"],"comfortLevel":2}"#
        let prefs = try JSONDecoder().decode(UserPreferences.self, from: Data(json.utf8))
        XCTAssertEqual(prefs.displayName, "Ana")
        XCTAssertEqual(prefs.favoriteColors, [.rosa])
        XCTAssertEqual(prefs.comfortLevel, 2)
        XCTAssertEqual(prefs.usualFormality, 2)
    }

    func testPreferencesServicePersists() throws {
        let url = TestSupport.temporaryDirectory().appendingPathComponent("prefs.json")
        let service = PreferencesService(fileURL: url)
        service.preferences.displayName = "Angie"
        service.preferences.favoriteStyles = [.coquette]
        let reloaded = PreferencesService(fileURL: url)
        XCTAssertEqual(reloaded.preferences.displayName, "Angie")
        XCTAssertEqual(reloaded.preferences.favoriteStyles, [.coquette])
    }

    func testSearchNormalization() {
        XCTAssertEqual("Suéter ROSA".normalizedForSearch, "sueter rosa")
        XCTAssertEqual("¡Jeans, negros!".searchTokens, ["jeans", "negros"])
    }

    @MainActor
    func testWardrobeFilters() {
        let jeans = Garment(name: "Jeans negros", category: .jeans, primaryColor: .negro)
        let blouse = Garment(name: "Blusa rosa", category: .blusas, primaryColor: .rosa)
        blouse.isFavorite = true
        blouse.tags = ["oficina"]
        let viewModel = WardrobeViewModel()

        viewModel.searchText = "rosa"
        XCTAssertEqual(viewModel.apply(to: [jeans, blouse]).map(\.name), ["Blusa rosa"])

        viewModel.searchText = ""
        viewModel.selectedCategories = [.jeans]
        XCTAssertEqual(viewModel.apply(to: [jeans, blouse]).map(\.name), ["Jeans negros"])

        viewModel.resetFilters()
        viewModel.onlyFavorites = true
        XCTAssertEqual(viewModel.apply(to: [jeans, blouse]).map(\.name), ["Blusa rosa"])

        viewModel.resetFilters()
        viewModel.tagFilter = "ofi"
        XCTAssertEqual(viewModel.apply(to: [jeans, blouse]).count, 1)
    }
}
