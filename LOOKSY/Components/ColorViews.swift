import SwiftUI

struct ColorDot: View {
    let color: FashionColor
    var size: CGFloat = 14

    var body: some View {
        Group {
            if color == .multicolor {
                Circle().fill(AngularGradient(colors: [.red, .yellow, .green, .blue, .purple, .red], center: .center))
            } else {
                Circle().fill(Color(rgb: color.rgbValue))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(Theme.separator, lineWidth: 1))
        .accessibilityLabel(color.displayName)
    }
}

/// Grid to choose one color.
struct ColorPickerGrid: View {
    @Binding var selection: FashionColor
    var highlighted: Set<FashionColor> = []

    private let columns = [GridItem(.adaptive(minimum: 46), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(FashionColor.allCases) { color in
                Button {
                    selection = color
                } label: {
                    VStack(spacing: 4) {
                        ColorDot(color: color, size: 30)
                            .overlay(
                                Circle()
                                    .stroke(Theme.accent, lineWidth: selection == color ? 3 : 0)
                                    .padding(-4)
                            )
                            .overlay(alignment: .topTrailing) {
                                if highlighted.contains(color) {
                                    Image(systemName: "eyedropper.halffull")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Theme.onAccent)
                                        .padding(3)
                                        .background(Theme.accent, in: Circle())
                                        .offset(x: 6, y: -6)
                                }
                            }
                        Text(color.displayName)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.displayName)
                .accessibilityAddTraits(selection == color ? .isSelected : [])
            }
        }
    }
}

/// Grid to choose several colors.
struct MultiColorPickerGrid: View {
    @Binding var selection: [FashionColor]
    var excluded: Set<FashionColor> = []

    private let columns = [GridItem(.adaptive(minimum: 46), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(FashionColor.allCases.filter { !excluded.contains($0) }) { color in
                let isSelected = selection.contains(color)
                Button {
                    if isSelected {
                        selection.removeAll { $0 == color }
                    } else {
                        selection.append(color)
                    }
                } label: {
                    VStack(spacing: 4) {
                        ColorDot(color: color, size: 26)
                            .overlay(
                                Circle()
                                    .stroke(Theme.accent, lineWidth: isSelected ? 3 : 0)
                                    .padding(-4)
                            )
                        Text(color.displayName)
                            .font(.system(size: 9))
                            .foregroundStyle(Theme.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.displayName)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}
