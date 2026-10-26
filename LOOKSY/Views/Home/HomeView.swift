import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(PreferencesService.self) private var preferences
    @Query(sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    stats
                    createOutfitCard
                    recentGarments
                }
                .padding(Theme.padding)
            }
            .looksyBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .accessibilityLabel("Ajustes")
                    }
                }
            }
            .navigationDestination(for: Garment.self) { garment in
                GarmentDetailView(garment: garment)
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let base: String
        switch hour {
        case 5..<12: base = "Buenos días"
        case 12..<19: base = "Buenas tardes"
        default: base = "Buenas noches"
        }
        let name = preferences.preferences.displayName.trimmed
        return name.isEmpty ? base : "\(base), \(name)"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOOKSY")
                .font(.caption.weight(.semibold))
                .tracking(4)
                .foregroundStyle(Theme.accent)
            Text(greeting)
                .font(Theme.title())
                .foregroundStyle(Theme.text)
            Text("¿Qué te pondrás hoy?")
                .font(.title3)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var stats: some View {
        HStack(spacing: 12) {
            StatTile(value: "\(garments.count)", label: "Prendas", systemImage: "hanger")
            StatTile(value: "\(garments.filter(\.isFavorite).count)", label: "Favoritas", systemImage: "heart")
            StatTile(value: "\(Set(garments.map(\.category)).count)", label: "Categorías", systemImage: "square.grid.2x2")
        }
    }

    private var createOutfitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tu estilista personal")
                .font(Theme.title(.title3))
                .foregroundStyle(Theme.text)
            Text("Describe la ocasión y LOOKSY combinará prendas reales de tu armario.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Button {
                router.openStylist()
            } label: {
                Label("Crear outfit", systemImage: "wand.and.stars")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(
            LinearGradient(colors: [Theme.roseSoft, Theme.cream], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
        )
    }

    @ViewBuilder
    private var recentGarments: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Prendas recientes", actionTitle: garments.isEmpty ? nil : "Ver todas") {
                router.selectedTab = .wardrobe
            }
            if garments.isEmpty {
                EmptyStateView(
                    title: "Empieza tu armario",
                    message: "Agrega fotos de tus prendas para recibir combinaciones.",
                    systemImage: "camera",
                    actionTitle: "Ir a Mi armario"
                ) {
                    router.selectedTab = .wardrobe
                }
                .cardStyle(padding: 0)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(garments.prefix(10)) { garment in
                            NavigationLink(value: garment) {
                                GarmentThumbnail(garment: garment, height: 130)
                                    .frame(width: 120)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}
