import SwiftUI

/// Pending feature: clearly labeled so no button pretends to work.
struct InspirationView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                title: "En desarrollo",
                message: "Las búsquedas de Pinterest y referencias guardadas llegan en la Fase 4.",
                systemImage: "sparkles"
            )
            .frame(maxHeight: .infinity)
            .looksyBackground()
            .navigationTitle("Inspiración")
        }
    }
}
