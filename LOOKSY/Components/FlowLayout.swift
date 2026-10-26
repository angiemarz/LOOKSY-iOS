import SwiftUI

/// Wraps subviews onto multiple lines (used for chips and tags).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                y += lineHeight + lineSpacing
                x = 0
                lineHeight = 0
            }
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                y += lineHeight + lineSpacing
                x = bounds.minX
                lineHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

/// Selectable capsule.
struct Chip: View {
    let title: String
    var systemImage: String?
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let systemImage {
                    Image(systemName: systemImage).font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .foregroundStyle(isSelected ? Theme.onAccent : Theme.text)
            .background(isSelected ? Theme.accent : Theme.cream, in: Capsule())
            .overlay(Capsule().stroke(isSelected ? Color.clear : Theme.separator, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Multi-selection of enum values shown as chips.
struct ChipSelector<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: [Item]
    let title: (Item) -> String

    var body: some View {
        FlowLayout {
            ForEach(items) { item in
                Chip(title: title(item), isSelected: selection.contains(item)) {
                    if let index = selection.firstIndex(of: item) {
                        selection.remove(at: index)
                    } else {
                        selection.append(item)
                    }
                }
            }
        }
    }
}

/// Single selection with optional "none".
struct SingleChipSelector<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item?
    let title: (Item) -> String
    var allowsNone = true

    var body: some View {
        FlowLayout {
            ForEach(items) { item in
                Chip(title: title(item), isSelected: selection == item) {
                    if selection == item, allowsNone {
                        selection = nil
                    } else {
                        selection = item
                    }
                }
            }
        }
    }
}

/// Free-text tags with add/remove.
struct TagEditor: View {
    @Binding var tags: [String]
    var placeholder = "Añadir etiqueta"
    @State private var newTag = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                FlowLayout {
                    ForEach(tags, id: \.self) { tag in
                        HStack(spacing: 4) {
                            Text("#\(tag)").font(.subheadline)
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "xmark.circle.fill").font(.caption)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Quitar etiqueta \(tag)")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Theme.roseSoft, in: Capsule())
                        .foregroundStyle(Theme.text)
                    }
                }
            }
            HStack {
                TextField(placeholder, text: $newTag)
                    .textInputAutocapitalization(.never)
                    .submitLabel(.done)
                    .onSubmit(add)
                Button("Añadir", action: add)
                    .disabled(newTag.trimmed.isEmpty)
            }
        }
    }

    private func add() {
        let value = newTag.trimmed.lowercased()
        guard !value.isEmpty, !tags.contains(value) else {
            newTag = ""
            return
        }
        tags.append(value)
        newTag = ""
    }
}
