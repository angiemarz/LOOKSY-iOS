import UIKit

extension UIImage {
    /// Redraws the image with `.up` orientation so pixel data matches what the user sees.
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Scales the image down so its longest side is at most `maxDimension` points (scale 1).
    func resized(maxDimension: CGFloat, opaque: Bool = false) -> UIImage {
        let pixelSize = CGSize(width: size.width * scale, height: size.height * scale)
        let longest = max(pixelSize.width, pixelSize.height)
        let ratio = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (pixelSize.width * ratio).rounded(), height: (pixelSize.height * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = opaque
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Rotates by multiples of 90 degrees.
    func rotated(quarterTurns: Int) -> UIImage {
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns != 0 else { return self }
        let base = normalizedOrientation()
        let newSize = turns % 2 == 0 ? base.size : CGSize(width: base.size.height, height: base.size.width)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = base.scale
        format.opaque = false
        return UIGraphicsImageRenderer(size: newSize, format: format).image { context in
            let cg = context.cgContext
            cg.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            cg.rotate(by: CGFloat(turns) * .pi / 2)
            base.draw(in: CGRect(x: -base.size.width / 2, y: -base.size.height / 2, width: base.size.width, height: base.size.height))
        }
    }

    /// Crops using a rectangle expressed in normalized coordinates (0...1, origin top-left).
    func cropped(toNormalizedRect rect: CGRect) -> UIImage {
        let base = normalizedOrientation()
        guard let cgImage = base.cgImage else { return base }
        let width = CGFloat(cgImage.width), height = CGFloat(cgImage.height)
        let clamped = rect.intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        guard !clamped.isNull, clamped.width > 0.01, clamped.height > 0.01 else { return base }
        let pixelRect = CGRect(
            x: (clamped.minX * width).rounded(),
            y: (clamped.minY * height).rounded(),
            width: (clamped.width * width).rounded(),
            height: (clamped.height * height).rounded()
        )
        guard let croppedImage = cgImage.cropping(to: pixelRect) else { return base }
        return UIImage(cgImage: croppedImage, scale: base.scale, orientation: .up)
    }

    /// Height divided by width.
    var aspectRatio: CGFloat {
        size.width > 0 ? size.height / size.width : 1
    }

    var hasAlphaChannel: Bool {
        guard let alpha = cgImage?.alphaInfo else { return false }
        switch alpha {
        case .first, .last, .premultipliedFirst, .premultipliedLast: return true
        default: return false
        }
    }
}
