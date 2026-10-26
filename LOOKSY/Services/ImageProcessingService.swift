import UIKit
import Vision
import CoreImage

/// Result of the local color analysis of a photo.
struct ColorAnalysis: Equatable, Sendable {
    struct Entry: Equatable, Sendable {
        var color: FashionColor
        /// Fraction of analyzed pixels (0...1).
        var share: Double
        /// Average measured color of the pixels mapped to `color`.
        var averageHex: String
    }

    var entries: [Entry]

    var primary: FashionColor? { entries.first?.color }
    var primaryHex: String? { entries.first?.averageHex }

    /// Secondary colors that cover a meaningful part of the garment.
    var secondary: [FashionColor] {
        entries.dropFirst().filter { $0.share >= 0.12 }.prefix(2).map(\.color)
    }
}

/// On-device photo processing: color analysis, background removal and auto-framing.
/// Everything runs locally with Vision/Core Image — no network, no paid services.
enum ImageProcessingService {
    enum ProcessingError: LocalizedError {
        case invalidImage
        case noForegroundFound
        case unsupported

        var errorDescription: String? {
            switch self {
            case .invalidImage: return "La imagen no se pudo procesar."
            case .noForegroundFound: return "No se pudo separar la prenda del fondo en esta foto. Puedes recortarla manualmente o usar la foto original."
            case .unsupported: return "Este dispositivo no admite la separación automática del fondo."
            }
        }
    }

    // MARK: Color analysis

    /// Measures the dominant colors of an image.
    /// - Transparent pixels (cutouts) are ignored.
    /// - For photos without transparency only the central area is analyzed,
    ///   and pixels similar to the border color (likely background) are skipped.
    static func analyzeColors(of image: UIImage) -> ColorAnalysis? {
        guard let pixels = samplePixels(of: image, side: 64) else { return nil }
        return analyzeColors(pixels: pixels.colors, hasAlpha: pixels.hasTransparency, side: 64, alphas: pixels.alphas)
    }

    /// Pure function used by `analyzeColors(of:)`; exposed for tests.
    static func analyzeColors(pixels: [RGBColor], hasAlpha: Bool, side: Int, alphas: [Double]? = nil) -> ColorAnalysis? {
        guard !pixels.isEmpty else { return nil }
        var candidates: [RGBColor] = []

        if hasAlpha, let alphas {
            for (index, color) in pixels.enumerated() where alphas[index] > 0.5 {
                candidates.append(color)
            }
        } else {
            // Estimate the background from the border pixels.
            var border: [RGBColor] = []
            for y in 0..<side {
                for x in 0..<side where x == 0 || y == 0 || x == side - 1 || y == side - 1 {
                    let index = y * side + x
                    if index < pixels.count { border.append(pixels[index]) }
                }
            }
            let background = average(border)
            let inset = side / 6
            for y in inset..<(side - inset) {
                for x in inset..<(side - inset) {
                    let index = y * side + x
                    guard index < pixels.count else { continue }
                    let color = pixels[index]
                    if let background, color.distance(to: background) < 12 { continue }
                    candidates.append(color)
                }
            }
            // A plain garment photographed on a similar background: fall back to the center.
            if candidates.count < 40 {
                candidates = []
                for y in inset..<(side - inset) {
                    for x in inset..<(side - inset) {
                        let index = y * side + x
                        if index < pixels.count { candidates.append(pixels[index]) }
                    }
                }
            }
        }

        guard !candidates.isEmpty else { return nil }

        var buckets: [FashionColor: [RGBColor]] = [:]
        for color in candidates {
            buckets[FashionColor.nearest(to: color), default: []].append(color)
        }
        let total = Double(candidates.count)
        let entries = buckets
            .map { key, values in
                ColorAnalysis.Entry(color: key, share: Double(values.count) / total, averageHex: (average(values) ?? key.rgb).hexString)
            }
            .sorted { $0.share > $1.share }
        return ColorAnalysis(entries: Array(entries.prefix(4)))
    }

    private static func average(_ colors: [RGBColor]) -> RGBColor? {
        guard !colors.isEmpty else { return nil }
        var r = 0.0, g = 0.0, b = 0.0
        for c in colors { r += c.red; g += c.green; b += c.blue }
        let n = Double(colors.count)
        return RGBColor(red: r / n, green: g / n, blue: b / n)
    }

    private struct PixelSample {
        var colors: [RGBColor]
        var alphas: [Double]
        var hasTransparency: Bool
    }

    private static func samplePixels(of image: UIImage, side: Int) -> PixelSample? {
        guard let cgImage = image.normalizedOrientation().cgImage else { return nil }
        let bytesPerRow = side * 4
        var buffer = [UInt8](repeating: 0, count: side * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let drawn: Bool = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }

        var colors: [RGBColor] = []
        var alphas: [Double] = []
        colors.reserveCapacity(side * side)
        var transparent = 0
        for i in 0..<(side * side) {
            let offset = i * 4
            let a = Double(buffer[offset + 3]) / 255
            alphas.append(a)
            if a < 0.5 { transparent += 1 }
            // Un-premultiply.
            let divisor = a > 0 ? a : 1
            colors.append(RGBColor(
                red: Double(buffer[offset]) / 255 / divisor,
                green: Double(buffer[offset + 1]) / 255 / divisor,
                blue: Double(buffer[offset + 2]) / 255 / divisor
            ))
        }
        return PixelSample(colors: colors, alphas: alphas, hasTransparency: transparent > side)
    }

    // MARK: Background removal (Vision, iOS 17+)

    /// Tries to isolate the garment using `VNGenerateForegroundInstanceMaskRequest`.
    /// Returns a transparent PNG-ready image cropped to the subject.
    /// May fail (e.g. busy backgrounds, simulator): callers must offer manual fallbacks.
    static func removeBackground(from image: UIImage) async throws -> UIImage {
        let input = image.normalizedOrientation().resized(maxDimension: 1600)
        return try await Task.detached(priority: .userInitiated) {
            try ImageProcessingService.removeBackgroundSync(from: input)
        }.value
    }

    private static func removeBackgroundSync(from image: UIImage) throws -> UIImage {
        guard let cgImage = image.cgImage else { throw ProcessingError.invalidImage }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        do {
            try handler.perform([request])
        } catch {
            AppLogger.images.error("Foreground mask request failed")
            throw ProcessingError.unsupported
        }
        guard let observation = request.results?.first, !observation.allInstances.isEmpty else {
            throw ProcessingError.noForegroundFound
        }
        let buffer = try observation.generateMaskedImage(
            ofInstances: observation.allInstances,
            from: handler,
            croppedToInstancesExtent: true
        )
        let ciImage = CIImage(cvPixelBuffer: buffer)
        let context = CIContext(options: nil)
        guard let output = context.createCGImage(ciImage, from: ciImage.extent) else {
            throw ProcessingError.noForegroundFound
        }
        return UIImage(cgImage: output, scale: 1, orientation: .up)
    }

    /// Finds the subject's bounding box (normalized, top-left origin) to auto-frame a photo
    /// while keeping its original background.
    static func foregroundBounds(in image: UIImage) async -> CGRect? {
        let input = image.normalizedOrientation().resized(maxDimension: 1024)
        return await Task.detached(priority: .userInitiated) {
            ImageProcessingService.foregroundBoundsSync(in: input)
        }.value
    }

    private static func foregroundBoundsSync(in image: UIImage) -> CGRect? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: .up, options: [:])
        guard (try? handler.perform([request])) != nil,
              let observation = request.results?.first,
              !observation.allInstances.isEmpty,
              let mask = try? observation.generateScaledMaskForImage(forInstances: observation.allInstances, from: handler)
        else { return nil }

        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)
        let rowBytes = CVPixelBufferGetBytesPerRow(mask)
        guard let base = CVPixelBufferGetBaseAddress(mask), width > 0, height > 0 else { return nil }
        let format = CVPixelBufferGetPixelFormatType(mask)

        var minX = width, minY = height, maxX = -1, maxY = -1
        let step = 2
        for y in stride(from: 0, to: height, by: step) {
            let row = base.advanced(by: y * rowBytes)
            for x in stride(from: 0, to: width, by: step) {
                let value: Float
                if format == kCVPixelFormatType_OneComponent32Float {
                    value = row.assumingMemoryBound(to: Float.self)[x]
                } else {
                    value = Float(row.assumingMemoryBound(to: UInt8.self)[x]) / 255
                }
                if value > 0.5 {
                    minX = min(minX, x); maxX = max(maxX, x)
                    minY = min(minY, y); maxY = max(maxY, y)
                }
            }
        }
        guard maxX > minX, maxY > minY else { return nil }
        let padX = CGFloat(maxX - minX) * 0.08
        let padY = CGFloat(maxY - minY) * 0.08
        let rect = CGRect(
            x: (CGFloat(minX) - padX) / CGFloat(width),
            y: (CGFloat(minY) - padY) / CGFloat(height),
            width: (CGFloat(maxX - minX) + 2 * padX) / CGFloat(width),
            height: (CGFloat(maxY - minY) + 2 * padY) / CGFloat(height)
        )
        return rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
    }
}
