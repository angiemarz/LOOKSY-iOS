import SwiftUI

/// Pending feature: clearly labeled so no button pretends to work.
struct StylistView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                title: "En desarrollo",
                message: "El estilista con lenguaje natural llega en la Fase 2 del desarrollo.",
                systemImage: "wand.and.stars"
            )
            .frame(maxHeight: .infinity)
            .looksyBackground()
            .navigationTitle("Crear outfit")
        }
    }
}
