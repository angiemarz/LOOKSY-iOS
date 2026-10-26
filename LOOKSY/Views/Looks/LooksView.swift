import SwiftUI

/// Pending feature: clearly labeled so no button pretends to work.
struct LooksView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                title: "En desarrollo",
                message: "Tus looks, collages y calendario llegan en las Fases 2, 3 y 5.",
                systemImage: "square.grid.2x2"
            )
            .frame(maxHeight: .infinity)
            .looksyBackground()
            .navigationTitle("Mis looks")
        }
    }
}
