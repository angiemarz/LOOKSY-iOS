import SwiftUI

/// Walks through imported photos one by one so each becomes a garment.
struct AddGarmentsFlow: View {
    let queue: ImageImportQueue
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    @State private var savedCount = 0

    var body: some View {
        NavigationStack {
            if index < queue.images.count {
                GarmentEditorView(
                    viewModel: GarmentEditorViewModel(image: queue.images[index]),
                    saveTitle: index < queue.images.count - 1 ? "Guardar y seguir" : "Guardar",
                    onSaved: {
                        savedCount += 1
                        advance()
                    },
                    onSkip: queue.images.count > 1 ? { advance() } : nil
                )
                .id(index)
                .toolbar {
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 0) {
                            Text("Nueva prenda").font(.headline)
                            if queue.images.count > 1 {
                                Text("\(index + 1) de \(queue.images.count)")
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    if queue.images.count == 1 {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { dismiss() }
                        }
                    }
                }
            } else {
                EmptyStateView(
                    title: savedCount == 1 ? "Prenda guardada" : "\(savedCount) prendas guardadas",
                    message: "Ya puedes usarlas para crear outfits.",
                    systemImage: "checkmark.circle",
                    actionTitle: "Listo"
                ) {
                    dismiss()
                }
                .looksyBackground()
            }
        }
        .interactiveDismissDisabled(index < queue.images.count)
    }

    private func advance() {
        withAnimation {
            index += 1
        }
        if index >= queue.images.count, savedCount == 0 {
            dismiss()
        } else if index >= queue.images.count, queue.images.count == 1 {
            dismiss()
        }
    }
}
