import SwiftUI
import UIKit

extension UIColor {
    /// Creates a color from a 24-bit RGB value such as `0xFAF8F5`.
    convenience init(rgb: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: alpha
        )
    }

    /// Hex string in `#RRGGBB` form.
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return RGBColor(red: Double(r), green: Double(g), blue: Double(b)).hexString
    }
}

extension Color {
    /// A color that adapts to light and dark mode.
    static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }

    init(rgb: UInt32) {
        self.init(uiColor: UIColor(rgb: rgb))
    }

    /// Creates a color from a `#RRGGBB` string. Falls back to gray when invalid.
    init(hex: String) {
        let rgb = RGBColor(hex: hex) ?? RGBColor(red: 0.5, green: 0.5, blue: 0.5)
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }

    var hexString: String {
        UIColor(self).hexString
    }
}
