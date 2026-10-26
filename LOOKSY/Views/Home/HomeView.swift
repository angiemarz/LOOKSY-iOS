import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @Environment(PreferencesService.self) private var preferences
    @Query(sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]
    @Query(sort: \Look.createdAt, order: .reverse) private var looks: [Look]
    @Query(sort: \PlannedOutfit.day) private var plans: [PlannedOutfit]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    stats
                    createOutfitCard
                    weekPreview
                    recentGarments
                    favoriteLooks
                    underusedIdeas
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
            .navigationDestination(for: Look.self) { look in
                LookDetailView(look: look)
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
            StatTile(value: "\(looks.count)", label: "Looks", systemImage: "square.grid.2x2")
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

    // MARK: Week

    private var weekPreview: some View {
        let days = WeekPlanner.days(of: Date(), weekOffset: 0, calendar: Calendar.current)
        return VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Tu semana", actionTitle: "Planificar") {
                router.selectedTab = .looks
            }
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { day in
                    let plan = plans.first { Calendar.current.isDate($0.day, inSameDayAs: day) }
                    let look = plan.flatMap { plan in looks.first { $0.id == plan.lookID } }
                    VStack(spacing: 4) {
                        Text(day.formatted(.dateTime.weekday(.narrow).locale(Locale(identifier: "es_MX"))).uppercased())
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Calendar.current.isDateInToday(day) ? Theme.accent : Theme.textSecondary)
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Calendar.current.isDateInToday(day) ? Theme.roseSoft : Theme.cream)
                            if let look {
                                StoredImageView(fileName: look.exportedImageFileName, contentMode: .fit, placeholderSymbol: "tshirt")
                                    .padding(2)
                            } else {
                                Text(day.formatted(.dateTime.day()))
                                    .font(.caption)
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .frame(height: 56)
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(day.formatted(date: .complete, time: .omitted)): \(look?.name ?? "sin plan")")
                }
            }
        }
    }

    // MARK: Favorite looks

    @ViewBuilder
    private var favoriteLooks: some View {
        let favorites = looks.filter(\.isFavorite)
        if !favorites.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Looks favoritos", actionTitle: "Ver todos") {
                    router.selectedTab = .looks
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(favorites.prefix(10)) { look in
                            NavigationLink(value: look) {
                                LookCard(look: look)
                                    .frame(width: 140)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: Underused garments

    /// Garments worn the least (and longest ago) — ideas to give them a new life.
    private var underused: [Garment] {
        let available = garments.filter(\.isAvailable)
        guard available.count >= 3 else { return [] }
        return Array(available.sorted {
            if $0.wearCount != $1.wearCount { return $0.wearCount < $1.wearCount }
            return ($0.lastWornAt ?? $0.createdAt) < ($1.lastWornAt ?? $1.createdAt)
        }.prefix(4))
    }

    @ViewBuilder
    private var underusedIdeas: some View {
        let items = underused
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(title: "Dales una nueva oportunidad", subtitle: "Prendas que casi no has usado")
                ForEach(items) { garment in
                    HStack(spacing: 12) {
                        StoredImageView(fileName: garment.thumbnailFileName, contentMode: .fit, placeholderSymbol: garment.category.symbolName)
                            .frame(width: 56, height: 56)
                            .background(Theme.cream, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(garment.name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.text)
                            Text(garment.wearCount == 0 ? "Aún sin usar" : "Usada \(garment.wearCount) vez/veces")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                        Spacer()
                        Button("Combinar") {
                            router.openStylist(with: garment.id)
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    .padding(10)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                }
            }
        }
    }
}
