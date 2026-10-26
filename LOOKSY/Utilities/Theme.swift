import SwiftUI

/// LOOKSY visual identity. Colors adapt to dark mode while keeping
/// enough contrast for text (WCAG AA for body text).
enum Theme {
    // Brand palette
    static let background = Color.adaptive(light: 0xFAF8F5, dark: 0x1A1716)
    static let surface = Color.adaptive(light: 0xFFFFFF, dark: 0x262120)
    static let cream = Color.adaptive(light: 0xF5EFE8, dark: 0x2B2523)
    static let beige = Color.adaptive(light: 0xE8DDD0, dark: 0x3A312D)
    static let rose = Color.adaptive(light: 0xD8A7B1, dark: 0xB98390)
    static let roseSoft = Color.adaptive(light: 0xF3E2E5, dark: 0x3D2D31)
    /// Darker rose used for interactive elements so white labels stay legible.
    static let accent = Color.adaptive(light: 0xA35E6E, dark: 0xE3B5BF)
    static let onAccent = Color.adaptive(light: 0xFFFFFF, dark: 0x292522)
    static let text = Color.adaptive(light: 0x292522, dark: 0xF5EFE8)
    static let textSecondary = Color.adaptive(light: 0x6B5F57, dark: 0xC2B6AB)
    static let separator = Color.adaptive(light: 0xE6DCD2, dark: 0x3F3632)
    static let danger = Color.adaptive(light: 0xB3261E, dark: 0xF2B8B5)

    // Layout
    static let cornerRadius: CGFloat = 18
    static let smallCornerRadius: CGFloat = 12
    static let padding: CGFloat = 16
    static let spacing: CGFloat = 12

    // Typography
    static func title(_ style: Font.TextStyle = .largeTitle) -> Font {
        .system(style, design: .serif).weight(.semibold)
    }
}

extension View {
    /// Elegant card styling used throughout the app.
    func cardStyle(padding: CGFloat = Theme.padding) -> some View {
        self
            .padding(padding)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
            .shadow(color: Color.black.opacity(0.06), radius: 10, x: 0, y: 4)
    }

    /// Screen background with the warm white tone.
    func looksyBackground() -> some View {
        self.background(Theme.background.ignoresSafeArea())
    }
}

/// Primary filled button style.
struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Theme.onAccent)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Theme.accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Secondary outlined button style.
struct SecondaryButtonStyle: ButtonStyle {
    var fullWidth = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.accent)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(Theme.roseSoft, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
