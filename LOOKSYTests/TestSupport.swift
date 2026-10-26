import Foundation
import SwiftData
import UIKit
@testable import LOOKSY

enum TestSupport {
    @MainActor
    static func makeContext() -> ModelContext {
        let container = LOOKSYApp.makeContainer(inMemory: true)
        retainedContainers.append(container)
        return container.mainContext
    }

    /// Containers must outlive their contexts during a test.
    @MainActor
    static var retainedContainers: [ModelContainer] = []

    static func temporaryDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LOOKSYTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func solidImage(_ color: UIColor, size: CGSize = CGSize(width: 120, height: 160)) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// A colored rectangle on a white background, like a garment photo.
    static func garmentPhoto(_ color: UIColor, size: CGSize = CGSize(width: 200, height: 200)) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            color.setFill()
            context.fill(CGRect(x: size.width * 0.25, y: size.height * 0.2, width: size.width * 0.5, height: size.height * 0.6))
        }
    }
}
