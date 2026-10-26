import Foundation
import SwiftData
import CryptoKit
import UIKit

/// Portable LOOKSY backup (single JSON file). Images are embedded with a
/// SHA-256 checksum so imports can verify integrity.
struct BackupArchive: Codable {
    static let formatIdentifier = "LOOKSY-backup"
    static let currentFormatVersion = 1

    var format: String = BackupArchive.formatIdentifier
    var formatVersion: Int = BackupArchive.currentFormatVersion
    var createdAt: Date = Date()
    var appVersion: String = ""
    var garments: [GarmentRecord] = []
    var looks: [LookRecord] = []
    var collections: [CollectionRecord] = []
    var plans: [PlanRecord] = []
    var references: [ReferenceRecord] = []
    var preferences: UserPreferences = UserPreferences()
    var files: [FileRecord] = []

    struct FileRecord: Codable {
        var name: String
        var sha256: String
        var data: Data
    }

    struct GarmentRecord: Codable {
        var id: UUID
        var name: String
        var imageFileName: String?
        var cutoutFileName: String?
        var thumbnailFileName: String?
        var usesCutout: Bool
        var category: String
        var primaryColor: String
        var secondaryColors: [String]
        var detectedColorHex: String?
        var material: String
        var pattern: String
        var styles: [String]
        var silhouette: String
        var seasons: [String]
        var formality: Int
        var occasions: [String]
        var tags: [String]
        var notes: String
        var isAvailable: Bool
        var isFavorite: Bool
        var wearCount: Int
        var lastWornAt: Date?
        var createdAt: Date
        var updatedAt: Date
    }

    struct LookRecord: Codable {
        var id: UUID
        var name: String
        var garmentIDs: [UUID]
        var composition: CollageComposition?
        var exportedImageFileName: String?
        var style: String?
        var occasion: String?
        var tags: [String]
        var notes: String
        var explanation: String
        var pinterestURLs: [String]
        var referenceIDs: [UUID]
        var isFavorite: Bool
        var createdAt: Date
        var updatedAt: Date
        var lastWornAt: Date?
    }

    struct CollectionRecord: Codable {
        var id: UUID
        var name: String
        var lookIDs: [UUID]
        var createdAt: Date
    }

    struct PlanRecord: Codable {
        var id: UUID
        var day: Date
        var lookID: UUID
        var note: String
        var markedAsWorn: Bool
    }

    struct ReferenceRecord: Codable {
        var id: UUID
        var title: String
        var urlString: String?
        var searchQuery: String?
        var imageFileName: String?
        var colors: [String]
        var style: String?
        var notes: String
        var isFavorite: Bool
        var linkedLookIDs: [UUID]
        var linkedGarmentIDs: [UUID]
        var target: RecreationTarget?
        var formality: Int
        var createdAt: Date
    }
}

struct BackupImportReport: Equatable {
    var garmentsAdded = 0
    var looksAdded = 0
    var collectionsAdded = 0
    var plansAdded = 0
    var referencesAdded = 0
    var duplicatesSkipped = 0
    var filesRestored = 0
    var invalidFiles = 0
    var missingFiles = 0

    var summary: String {
        var lines = ["Prendas: \(garmentsAdded)", "Looks: \(looksAdded)", "Colecciones: \(collectionsAdded)", "Planificaciones: \(plansAdded)", "Referencias: \(referencesAdded)", "Fotos restauradas: \(filesRestored)"]
        if duplicatesSkipped > 0 { lines.append("Registros duplicados omitidos: \(duplicatesSkipped)") }
        if invalidFiles > 0 { lines.append("Archivos dañados descartados: \(invalidFiles)") }
        if missingFiles > 0 { lines.append("Fotos faltantes en el respaldo: \(missingFiles)") }
        return lines.joined(separator: "\n")
    }
}

@MainActor
struct BackupService {
    enum BackupError: LocalizedError {
        case invalidFile
        case newerVersion(Int)
        case unreadable

        var errorDescription: String? {
            switch self {
            case .invalidFile: return "El archivo no es un respaldo válido de LOOKSY."
            case .newerVersion(let version): return "Este respaldo se creó con una versión más nueva de LOOKSY (formato \(version)). Actualiza la app para restaurarlo."
            case .unreadable: return "No se pudo leer el archivo de respaldo."
            }
        }
    }

    enum ImportMode {
        /// Keeps current data and adds records whose IDs are new.
        case merge
        /// Deletes current data and restores the backup.
        case replace
    }

    let context: ModelContext
    var images: ImageStorageService = .shared
    var preferences: PreferencesService

    // MARK: Export

    func makeArchive() throws -> BackupArchive {
        var archive = BackupArchive()
        archive.appVersion = Bundle.main.appVersionDescription
        archive.preferences = preferences.preferences

        let garments = try context.fetch(FetchDescriptor<Garment>())
        let looks = try context.fetch(FetchDescriptor<Look>())
        let collections = try context.fetch(FetchDescriptor<LookCollection>())
        let plans = try context.fetch(FetchDescriptor<PlannedOutfit>())
        let references = try context.fetch(FetchDescriptor<InspirationReference>())

        archive.garments = garments.map { g in
            BackupArchive.GarmentRecord(
                id: g.id, name: g.name, imageFileName: g.imageFileName, cutoutFileName: g.cutoutFileName,
                thumbnailFileName: g.thumbnailFileName, usesCutout: g.usesCutout, category: g.categoryRaw,
                primaryColor: g.primaryColorRaw, secondaryColors: g.secondaryColorRaws, detectedColorHex: g.detectedColorHex,
                material: g.materialRaw, pattern: g.patternRaw, styles: g.styleRaws, silhouette: g.silhouetteRaw,
                seasons: g.seasonRaws, formality: g.formality, occasions: g.occasionRaws, tags: g.tags, notes: g.notes,
                isAvailable: g.isAvailable, isFavorite: g.isFavorite, wearCount: g.wearCount, lastWornAt: g.lastWornAt,
                createdAt: g.createdAt, updatedAt: g.updatedAt
            )
        }
        archive.looks = looks.map { l in
            BackupArchive.LookRecord(
                id: l.id, name: l.name, garmentIDs: l.garmentIDs, composition: l.composition,
                exportedImageFileName: l.exportedImageFileName, style: l.styleRaw, occasion: l.occasionRaw,
                tags: l.tags, notes: l.notes, explanation: l.explanation, pinterestURLs: l.pinterestURLs,
                referenceIDs: l.referenceIDs, isFavorite: l.isFavorite, createdAt: l.createdAt,
                updatedAt: l.updatedAt, lastWornAt: l.lastWornAt
            )
        }
        archive.collections = collections.map { BackupArchive.CollectionRecord(id: $0.id, name: $0.name, lookIDs: $0.lookIDs, createdAt: $0.createdAt) }
        archive.plans = plans.map { BackupArchive.PlanRecord(id: $0.id, day: $0.day, lookID: $0.lookID, note: $0.note, markedAsWorn: $0.markedAsWorn) }
        archive.references = references.map { r in
            BackupArchive.ReferenceRecord(
                id: r.id, title: r.title, urlString: r.urlString, searchQuery: r.searchQuery, imageFileName: r.imageFileName,
                colors: r.colorRaws, style: r.styleRaw, notes: r.notes, isFavorite: r.isFavorite,
                linkedLookIDs: r.linkedLookIDs, linkedGarmentIDs: r.linkedGarmentIDs, target: r.target,
                formality: r.formality, createdAt: r.createdAt
            )
        }

        var fileNames = Set<String>()
        garments.forEach { fileNames.formUnion($0.allImageFileNames) }
        looks.compactMap(\.exportedImageFileName).forEach { fileNames.insert($0) }
        references.compactMap(\.imageFileName).forEach { fileNames.insert($0) }
        archive.files = fileNames.sorted().compactMap { name in
            guard let data = images.data(for: name) else { return nil }
            return BackupArchive.FileRecord(name: name, sha256: Self.sha256(data), data: data)
        }
        return archive
    }

    func exportData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(try makeArchive())
        AppLogger.backup.info("Backup exported")
        return data
    }

    static func defaultFileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "LOOKSY-respaldo-\(formatter.string(from: date)).json"
    }

    // MARK: Import

    static func decode(_ data: Data) throws -> BackupArchive {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive: BackupArchive
        do {
            archive = try decoder.decode(BackupArchive.self, from: data)
        } catch {
            throw BackupError.invalidFile
        }
        guard archive.format == BackupArchive.formatIdentifier else { throw BackupError.invalidFile }
        guard archive.formatVersion <= BackupArchive.currentFormatVersion else {
            throw BackupError.newerVersion(archive.formatVersion)
        }
        return archive
    }

    @discardableResult
    func importData(_ data: Data, mode: ImportMode) throws -> BackupImportReport {
        let archive = try Self.decode(data)
        return try restore(archive, mode: mode)
    }

    func restore(_ archive: BackupArchive, mode: ImportMode) throws -> BackupImportReport {
        var report = BackupImportReport()

        if mode == .replace {
            try deleteEverything()
            preferences.replace(with: archive.preferences)
        } else if preferences.preferences == UserPreferences() {
            preferences.replace(with: archive.preferences)
        }

        // Files: verify checksum, reject unsafe names and undecodable images.
        var availableFiles = Set(images.allFileNames())
        for file in archive.files {
            guard Self.isSafeFileName(file.name),
                  Self.sha256(file.data) == file.sha256,
                  UIImage(data: file.data) != nil else {
                report.invalidFiles += 1
                continue
            }
            if availableFiles.contains(file.name) { continue }
            try images.writeData(file.data, named: file.name)
            availableFiles.insert(file.name)
            report.filesRestored += 1
        }

        func checked(_ name: String?) -> String? {
            guard let name else { return nil }
            if availableFiles.contains(name) { return name }
            report.missingFiles += 1
            return nil
        }

        let existingGarments = Set(try context.fetch(FetchDescriptor<Garment>()).map(\.id))
        let existingLooks = Set(try context.fetch(FetchDescriptor<Look>()).map(\.id))
        let existingCollections = Set(try context.fetch(FetchDescriptor<LookCollection>()).map(\.id))
        let existingPlans = Set(try context.fetch(FetchDescriptor<PlannedOutfit>()).map(\.id))
        let existingReferences = Set(try context.fetch(FetchDescriptor<InspirationReference>()).map(\.id))

        var seen = Set<UUID>()
        for record in archive.garments {
            guard !existingGarments.contains(record.id), seen.insert(record.id).inserted else {
                report.duplicatesSkipped += 1
                continue
            }
            let garment = Garment(
                id: record.id,
                name: record.name,
                category: GarmentCategory(rawValue: record.category) ?? .accesorios,
                primaryColor: FashionColor(rawValue: record.primaryColor) ?? .multicolor,
                createdAt: record.createdAt
            )
            garment.imageFileName = checked(record.imageFileName)
            garment.cutoutFileName = checked(record.cutoutFileName)
            garment.thumbnailFileName = checked(record.thumbnailFileName)
            garment.usesCutout = record.usesCutout && garment.cutoutFileName != nil
            garment.secondaryColorRaws = record.secondaryColors.filter { FashionColor(rawValue: $0) != nil }
            garment.detectedColorHex = record.detectedColorHex
            garment.materialRaw = record.material
            garment.patternRaw = record.pattern
            garment.styleRaws = record.styles
            garment.silhouetteRaw = record.silhouette
            garment.seasonRaws = record.seasons
            garment.formality = min(max(record.formality, 1), 5)
            garment.occasionRaws = record.occasions
            garment.tags = record.tags
            garment.notes = record.notes
            garment.isAvailable = record.isAvailable
            garment.isFavorite = record.isFavorite
            garment.wearCount = max(record.wearCount, 0)
            garment.lastWornAt = record.lastWornAt
            garment.updatedAt = record.updatedAt
            context.insert(garment)
            report.garmentsAdded += 1
        }

        seen = []
        for record in archive.looks {
            guard !existingLooks.contains(record.id), seen.insert(record.id).inserted else {
                report.duplicatesSkipped += 1
                continue
            }
            let look = Look(id: record.id, name: record.name, garmentIDs: record.garmentIDs, createdAt: record.createdAt)
            look.composition = record.composition
            look.exportedImageFileName = checked(record.exportedImageFileName)
            look.styleRaw = record.style
            look.occasionRaw = record.occasion
            look.tags = record.tags
            look.notes = record.notes
            look.explanation = record.explanation
            look.pinterestURLs = record.pinterestURLs
            look.referenceIDs = record.referenceIDs
            look.isFavorite = record.isFavorite
            look.updatedAt = record.updatedAt
            look.lastWornAt = record.lastWornAt
            context.insert(look)
            report.looksAdded += 1
        }

        seen = []
        for record in archive.collections {
            guard !existingCollections.contains(record.id), seen.insert(record.id).inserted else {
                report.duplicatesSkipped += 1
                continue
            }
            context.insert(LookCollection(id: record.id, name: record.name, lookIDs: record.lookIDs, createdAt: record.createdAt))
            report.collectionsAdded += 1
        }

        seen = []
        for record in archive.plans {
            guard !existingPlans.contains(record.id), seen.insert(record.id).inserted else {
                report.duplicatesSkipped += 1
                continue
            }
            let plan = PlannedOutfit(id: record.id, day: record.day, lookID: record.lookID, note: record.note)
            plan.markedAsWorn = record.markedAsWorn
            context.insert(plan)
            report.plansAdded += 1
        }

        seen = []
        for record in archive.references {
            guard !existingReferences.contains(record.id), seen.insert(record.id).inserted else {
                report.duplicatesSkipped += 1
                continue
            }
            let reference = InspirationReference(id: record.id, title: record.title, urlString: record.urlString, searchQuery: record.searchQuery, createdAt: record.createdAt)
            reference.imageFileName = checked(record.imageFileName)
            reference.colorRaws = record.colors
            reference.styleRaw = record.style
            reference.notes = record.notes
            reference.isFavorite = record.isFavorite
            reference.linkedLookIDs = record.linkedLookIDs
            reference.linkedGarmentIDs = record.linkedGarmentIDs
            reference.target = record.target
            reference.formality = record.formality
            context.insert(reference)
            report.referencesAdded += 1
        }

        try context.save()
        AppLogger.backup.info("Backup restored")
        return report
    }

    /// Removes every record and stored image (used by "replace").
    func deleteEverything() throws {
        try context.delete(model: PlannedOutfit.self)
        try context.delete(model: LookCollection.self)
        try context.delete(model: Look.self)
        try context.delete(model: InspirationReference.self)
        try context.delete(model: Garment.self)
        try context.save()
        images.delete(images.allFileNames())
        images.clearCache()
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func isSafeFileName(_ name: String) -> Bool {
        !name.isEmpty && !name.contains("/") && !name.contains("\\") && !name.hasPrefix(".") && name.count < 200
    }
}
