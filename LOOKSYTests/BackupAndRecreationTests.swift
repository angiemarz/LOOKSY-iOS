import XCTest
import SwiftData
@testable import LOOKSY

@MainActor
final class BackupAndRecreationTests: XCTestCase {
    private func makeService() -> (BackupService, ModelContext, ImageStorageService) {
        let context = TestSupport.makeContext()
        let images = ImageStorageService(directory: TestSupport.temporaryDirectory())
        let preferences = PreferencesService(fileURL: TestSupport.temporaryDirectory().appendingPathComponent("p.json"))
        return (BackupService(context: context, images: images, preferences: preferences), context, images)
    }

    private func populate(_ context: ModelContext, images: ImageStorageService) throws -> Garment {
        let service = WardrobeService(context: context, images: images)
        let garment = try service.createGarment(image: TestSupport.garmentPhoto(.systemPink), input: .init(name: "Blusa rosa", category: .blusas, primaryColor: .rosa))
        let look = Look(name: "Café", garmentIDs: [garment.id])
        look.composition = CollageComposition(items: [CollageItem(garmentID: garment.id, centerX: 0.5, centerY: 0.3, width: 0.4)])
        context.insert(look)
        let collection = LookCollection(name: "Favoritos", lookIDs: [look.id])
        context.insert(collection)
        context.insert(PlannedOutfit(day: Date(), lookID: look.id))
        let reference = InspirationReference(title: "Pin", urlString: "https://pin.it/abc")
        reference.colors = [.rosa]
        context.insert(reference)
        try context.save()
        return garment
    }

    func testExportAndReplaceRestore() throws {
        let (source, sourceContext, sourceImages) = makeService()
        _ = try populate(sourceContext, images: sourceImages)
        source.preferences.preferences.displayName = "Angie"
        let data = try source.exportData()

        let (target, targetContext, targetImages) = makeService()
        let report = try target.importData(data, mode: .replace)
        XCTAssertEqual(report.garmentsAdded, 1)
        XCTAssertEqual(report.looksAdded, 1)
        XCTAssertEqual(report.collectionsAdded, 1)
        XCTAssertEqual(report.plansAdded, 1)
        XCTAssertEqual(report.referencesAdded, 1)
        XCTAssertEqual(report.invalidFiles, 0)
        XCTAssertEqual(report.missingFiles, 0)

        let garment = try XCTUnwrap(try targetContext.fetch(FetchDescriptor<Garment>()).first)
        XCTAssertEqual(garment.name, "Blusa rosa")
        XCTAssertTrue(targetImages.fileExists(garment.imageFileName))
        let look = try XCTUnwrap(try targetContext.fetch(FetchDescriptor<Look>()).first)
        XCTAssertEqual(look.composition?.items.first?.garmentID, garment.id)
        XCTAssertEqual(target.preferences.preferences.displayName, "Angie")
    }

    func testMergeSkipsDuplicateIDs() throws {
        let (service, context, images) = makeService()
        _ = try populate(context, images: images)
        let data = try service.exportData()
        let report = try service.importData(data, mode: .merge)
        XCTAssertEqual(report.garmentsAdded, 0)
        XCTAssertEqual(report.duplicatesSkipped, 5)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Garment>()).count, 1)
    }

    func testTamperedImageIsRejected() throws {
        let (service, context, images) = makeService()
        _ = try populate(context, images: images)
        var archive = try service.makeArchive()
        archive.files[0].data = Data("tampered".utf8)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(archive)

        let (target, _, _) = makeService()
        let report = try target.importData(data, mode: .replace)
        XCTAssertEqual(report.invalidFiles, 1)
        XCTAssertGreaterThanOrEqual(report.missingFiles, 1, "Records pointing to a rejected file lose the reference")
    }

    func testRejectsNewerFormatAndGarbage() throws {
        var archive = BackupArchive()
        archive.formatVersion = BackupArchive.currentFormatVersion + 1
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(archive)
        XCTAssertThrowsError(try BackupService.decode(data))
        XCTAssertThrowsError(try BackupService.decode(Data("{}".utf8)))
        XCTAssertThrowsError(try BackupService.decode(Data("no json".utf8)))
    }

    func testUnsafeFileNames() {
        XCTAssertFalse(BackupService.isSafeFileName("../evil.png"))
        XCTAssertFalse(BackupService.isSafeFileName(".hidden"))
        XCTAssertTrue(BackupService.isSafeFileName("ABC-thumb-1.jpg"))
    }

    func testRecreationVariants() {
        let wardrobe = [
            GarmentSnapshot(id: UUID(), name: "Blusa blanca", category: .blusas, primaryColor: .blanco, styles: [.minimalista]),
            GarmentSnapshot(id: UUID(), name: "Top crema", category: .tops, primaryColor: .crema),
            GarmentSnapshot(id: UUID(), name: "Jeans azules", category: .jeans, primaryColor: .mezclilla),
            GarmentSnapshot(id: UUID(), name: "Falda negra", category: .faldas, primaryColor: .negro),
            GarmentSnapshot(id: UUID(), name: "Tenis blancos", category: .tenis, primaryColor: .blanco),
            GarmentSnapshot(id: UUID(), name: "Sandalias", category: .sandalias, primaryColor: .camel)
        ]
        let target = RecreationTarget(
            pieces: [
                TargetPiece(slot: .top, category: .blusas, color: .blanco),
                TargetPiece(slot: .bottom, category: .faldas, color: .rojo),
                TargetPiece(slot: .bag, category: .bolsos, color: .negro)
            ],
            colors: [.blanco, .rojo],
            style: .minimalista,
            formality: 2
        )
        let results = RecreationService().recreate(target: target, wardrobe: wardrobe)
        XCTAssertEqual(results.map(\.kind), [.closest, .wardrobeOnly, .creative])
        let ids = Set(wardrobe.map(\.id))

        let closest = results[0]
        XCTAssertTrue(closest.items.contains { $0.name == "Blusa blanca" })
        XCTAssertFalse(closest.items.contains { $0.name == "Falda negra" }, "A black skirt is not close to a red one")
        XCTAssertTrue(closest.notes.contains { $0.hasPrefix("Falta") })

        let own = results[1]
        XCTAssertTrue(own.items.contains { $0.slot == .bottom })
        XCTAssertTrue(own.items.contains { $0.slot == .shoes }, "Wardrobe-only version is completed with shoes")
        for result in results {
            XCTAssertTrue(Set(result.items.map(\.id)).isSubset(of: ids))
        }
        XCTAssertTrue(closest.criteria.contains { $0.title == "Prendas equivalentes" && $0.status == .partial })
    }
}
