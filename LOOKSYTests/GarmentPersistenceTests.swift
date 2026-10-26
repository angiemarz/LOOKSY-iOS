import XCTest
import SwiftData
@testable import LOOKSY

@MainActor
final class GarmentPersistenceTests: XCTestCase {
    func testCreateGarmentPersistsAttributes() throws {
        let context = TestSupport.makeContext()
        let garment = Garment(name: "Jeans negros", category: .jeans, primaryColor: .negro)
        garment.styles = [.casual, .casualChic]
        garment.seasons = [.otono]
        garment.tags = ["básico"]
        context.insert(garment)
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Garment>())
        XCTAssertEqual(fetched.count, 1)
        let stored = try XCTUnwrap(fetched.first)
        XCTAssertEqual(stored.name, "Jeans negros")
        XCTAssertEqual(stored.category, .jeans)
        XCTAssertEqual(stored.category.slot, .bottom)
        XCTAssertEqual(stored.primaryColor, .negro)
        XCTAssertEqual(stored.styles, [.casual, .casualChic])
        XCTAssertEqual(stored.seasons, [.otono])
        XCTAssertEqual(stored.tags, ["básico"])
        XCTAssertTrue(stored.isAvailable)
    }

    func testUpdateGarmentWithDraft() throws {
        let context = TestSupport.makeContext()
        let garment = Garment(name: "Blusa", category: .blusas, primaryColor: .blanco)
        context.insert(garment)
        try context.save()

        var draft = GarmentDraft(garment: garment)
        draft.name = "  Blusa rosa  "
        draft.primaryColor = .rosa
        draft.secondaryColors = [.rosa, .blanco]
        draft.formality = 9
        draft.isFavorite = true
        draft.apply(to: garment)
        try context.save()

        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<Garment>()).first)
        XCTAssertEqual(stored.name, "Blusa rosa")
        XCTAssertEqual(stored.primaryColor, .rosa)
        XCTAssertEqual(stored.secondaryColors, [.blanco], "Primary color must not repeat as secondary")
        XCTAssertEqual(stored.formality, 5, "Formality is clamped to 1...5")
        XCTAssertTrue(stored.isFavorite)
    }

    func testDeleteGarmentKeepsLookReferenceForWarning() throws {
        let context = TestSupport.makeContext()
        let garment = Garment(name: "Falda", category: .faldas, primaryColor: .beige)
        context.insert(garment)
        let look = Look(name: "Look", garmentIDs: [garment.id])
        context.insert(look)
        try context.save()

        let service = WardrobeService(context: context, images: ImageStorageService(directory: TestSupport.temporaryDirectory()))
        XCTAssertEqual(service.looksUsing(garment).count, 1)
        try service.delete(garment)

        XCTAssertEqual(try context.fetch(FetchDescriptor<Garment>()).count, 0)
        let storedLook = try XCTUnwrap(try context.fetch(FetchDescriptor<Look>()).first)
        XCTAssertEqual(storedLook.garmentIDs.count, 1, "The look keeps the dangling ID so the UI can warn")
    }

    func testCreateGarmentWithPhotoStoresFiles() throws {
        let context = TestSupport.makeContext()
        let images = ImageStorageService(directory: TestSupport.temporaryDirectory())
        let service = WardrobeService(context: context, images: images)
        let garment = try service.createGarment(
            image: TestSupport.garmentPhoto(.red),
            input: .init(name: "Top rojo", category: .tops, primaryColor: .rojo)
        )
        XCTAssertTrue(images.fileExists(garment.imageFileName))
        XCTAssertTrue(images.fileExists(garment.thumbnailFileName))

        try service.delete(garment)
        XCTAssertFalse(images.fileExists(garment.imageFileName))
        XCTAssertEqual(images.allFileNames().count, 0)
    }

    func testLookCompositionRoundTrip() throws {
        let context = TestSupport.makeContext()
        let garmentID = UUID()
        let look = Look(name: "Café", garmentIDs: [garmentID])
        var composition = CollageComposition()
        composition.aspect = .story
        composition.items = [CollageItem(garmentID: garmentID, centerX: 0.5, centerY: 0.4, width: 0.3, rotation: 12, zIndex: 0)]
        look.composition = composition
        context.insert(look)
        try context.save()

        let stored = try XCTUnwrap(try context.fetch(FetchDescriptor<Look>()).first)
        XCTAssertEqual(stored.composition, composition)
    }
}
