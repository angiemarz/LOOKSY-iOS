import UIKit

/// Stores photos in the app container (Application Support/LOOKSY/Images).
/// Images never leave the device unless the user exports a backup.
final class ImageStorageService: @unchecked Sendable {
    static let shared = ImageStorageService()

    enum StorageError: LocalizedError {
        case encodingFailed
        case fileMissing

        var errorDescription: String? {
            switch self {
            case .encodingFailed: return "No se pudo guardar la imagen."
            case .fileMissing: return "No se encontró la imagen en el dispositivo."
            }
        }
    }

    static let maxOriginalDimension: CGFloat = 1800
    static let thumbnailDimension: CGFloat = 420

    let directory: URL
    private let cache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default

    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appendingPathComponent("LOOKSY/Images", isDirectory: true)
        }
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
        cache.countLimit = 150
    }

    func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName, isDirectory: false)
    }

    func fileExists(_ fileName: String?) -> Bool {
        guard let fileName else { return false }
        return fileManager.fileExists(atPath: url(for: fileName).path)
    }

    // MARK: Saving

    /// Saves a photo (JPEG, downscaled) and a thumbnail. Returns both file names.
    func savePhoto(_ image: UIImage, id: UUID = UUID()) throws -> (original: String, thumbnail: String) {
        let normalized = image.normalizedOrientation()
        let original = normalized.resized(maxDimension: Self.maxOriginalDimension)
        let originalName = "\(id.uuidString)-\(Self.shortStamp()).jpg"
        try writeJPEG(original, named: originalName, quality: 0.86)
        let thumbName = try saveThumbnail(for: normalized, baseID: id)
        return (originalName, thumbName)
    }

    /// Saves a PNG keeping transparency (used for background-removed cutouts).
    func savePNG(_ image: UIImage, id: UUID = UUID(), suffix: String = "cutout") throws -> String {
        let resized = image.resized(maxDimension: Self.maxOriginalDimension)
        guard let data = resized.pngData() else { throw StorageError.encodingFailed }
        let name = "\(id.uuidString)-\(suffix)-\(Self.shortStamp()).png"
        try data.write(to: url(for: name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        cache.setObject(resized, forKey: name as NSString)
        return name
    }

    func saveThumbnail(for image: UIImage, baseID: UUID) throws -> String {
        let thumb = image.resized(maxDimension: Self.thumbnailDimension)
        let name = "\(baseID.uuidString)-thumb-\(Self.shortStamp())" + (image.hasAlphaChannel ? ".png" : ".jpg")
        if image.hasAlphaChannel {
            guard let data = thumb.pngData() else { throw StorageError.encodingFailed }
            try data.write(to: url(for: name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } else {
            try writeJPEG(thumb, named: name, quality: 0.8)
        }
        cache.setObject(thumb, forKey: name as NSString)
        return name
    }

    /// Writes raw data (used when restoring backups).
    func writeData(_ data: Data, named fileName: String) throws {
        try data.write(to: url(for: fileName), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        cache.removeObject(forKey: fileName as NSString)
    }

    func data(for fileName: String) -> Data? {
        try? Data(contentsOf: url(for: fileName))
    }

    private func writeJPEG(_ image: UIImage, named name: String, quality: CGFloat) throws {
        guard let data = image.jpegData(compressionQuality: quality) else { throw StorageError.encodingFailed }
        try data.write(to: url(for: name), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        cache.setObject(image, forKey: name as NSString)
    }

    // MARK: Loading

    func cachedImage(_ fileName: String) -> UIImage? {
        cache.object(forKey: fileName as NSString)
    }

    /// Synchronous load; prefer `loadImage` from the main thread.
    func loadImageSync(_ fileName: String) -> UIImage? {
        if let cached = cachedImage(fileName) { return cached }
        guard let image = UIImage(contentsOfFile: url(for: fileName).path) else { return nil }
        // Force decoding off the main thread.
        let decoded = image.preparingForDisplay() ?? image
        cache.setObject(decoded, forKey: fileName as NSString)
        return decoded
    }

    /// Loads an image from disk on a background thread.
    func loadImage(_ fileName: String) async -> UIImage? {
        if let cached = cachedImage(fileName) { return cached }
        return await Task.detached(priority: .userInitiated) { [self] in
            self.loadImageSync(fileName)
        }.value
    }

    // MARK: Deleting & maintenance

    func delete(_ fileName: String?) {
        guard let fileName else { return }
        cache.removeObject(forKey: fileName as NSString)
        try? fileManager.removeItem(at: url(for: fileName))
    }

    func delete(_ fileNames: [String]) {
        fileNames.forEach { delete($0) }
    }

    func allFileNames() -> [String] {
        (try? fileManager.contentsOfDirectory(atPath: directory.path)) ?? []
    }

    /// Total bytes used by stored images.
    func totalSize() -> Int64 {
        allFileNames().reduce(Int64(0)) { total, name in
            let attributes = try? fileManager.attributesOfItem(atPath: url(for: name).path)
            return total + ((attributes?[.size] as? NSNumber)?.int64Value ?? 0)
        }
    }

    /// Removes files that no record references. Returns the number of files deleted.
    @discardableResult
    func removeOrphans(referenced: Set<String>) -> Int {
        let orphans = allFileNames().filter { !referenced.contains($0) }
        delete(orphans)
        return orphans.count
    }

    func clearCache() {
        cache.removeAllObjects()
    }

    private static func shortStamp() -> String {
        String(Int(Date().timeIntervalSince1970 * 1000) % 100_000_000)
    }
}
