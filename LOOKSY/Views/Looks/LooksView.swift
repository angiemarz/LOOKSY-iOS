import SwiftUI
import SwiftData

enum LooksSection: String, CaseIterable, Identifiable {
    case looks
    case collections
    case planner

    var id: String { rawValue }

    var title: String {
        switch self {
        case .looks: return "Looks"
        case .collections: return "Colecciones"
        case .planner: return "Calendario"
        }
    }
}

struct LooksView: View {
    @State private var section: LooksSection = .looks

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Sección", selection: $section) {
                    ForEach(LooksSection.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, Theme.padding)
                .padding(.vertical, 8)

                switch section {
                case .looks: LooksGridView()
                case .collections: CollectionsView()
                case .planner: PlannerView()
                }
            }
            .looksyBackground()
            .navigationTitle("Mis looks")
            .navigationDestination(for: Look.self) { look in
                LookDetailView(look: look)
            }
            .navigationDestination(for: LookCollection.self) { collection in
                CollectionDetailView(collection: collection)
            }
            .navigationDestination(for: Garment.self) { garment in
                GarmentDetailView(garment: garment)
            }
        }
    }
}

struct LooksGridView: View {
    @Query(sort: \Look.createdAt, order: .reverse) private var looks: [Look]
    @Query private var garments: [Garment]
    @Environment(AppRouter.self) private var router
    @State private var onlyFavorites = false
    @State private var styleFilter: FashionStyle?
    @State private var occasionFilter: Occasion?
    @State private var search = ""
    @State private var showingManualBuilder = false

    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 14)]

    var body: some View {
        let garmentIDs = Set(garments.map(\.id))
        let visible = looks.filter { look in
            (!onlyFavorites || look.isFavorite)
                && (styleFilter == nil || look.style == styleFilter)
                && (occasionFilter == nil || look.occasion == occasionFilter)
                && (search.isEmpty || look.name.normalizedForSearch.contains(search.normalizedForSearch)
                    || look.tags.contains { $0.normalizedForSearch.contains(search.normalizedForSearch) })
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    TextField("Buscar look o etiqueta", text: $search)
                        .padding(10)
                        .background(Theme.cream, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                    Button {
                        showingManualBuilder = true
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title2)
                    }
                    .accessibilityLabel("Crear look manualmente")
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Chip(title: "Favoritos", systemImage: "heart", isSelected: onlyFavorites) { onlyFavorites.toggle() }
                        Menu {
                            Button("Todos los estilos") { styleFilter = nil }
                            ForEach(FashionStyle.allCases) { style in
                                Button(style.displayName) { styleFilter = style }
                            }
                        } label: {
                            Chip(title: styleFilter?.displayName ?? "Estilo", systemImage: "sparkles", isSelected: styleFilter != nil) {}
                                .allowsHitTesting(false)
                        }
                        Menu {
                            Button("Todas las ocasiones") { occasionFilter = nil }
                            ForEach(Occasion.allCases) { occasion in
                                Button(occasion.displayName) { occasionFilter = occasion }
                            }
                        } label: {
                            Chip(title: occasionFilter?.displayName ?? "Ocasión", systemImage: "calendar", isSelected: occasionFilter != nil) {}
                                .allowsHitTesting(false)
                        }
                    }
                }
                if looks.isEmpty {
                    EmptyStateView(
                        title: "Aún no tienes looks",
                        message: "Crea outfits con el estilista y guárdalos aquí, o arma uno manualmente.",
                        systemImage: "square.grid.2x2",
                        actionTitle: "Crear outfit"
                    ) {
                        router.openStylist()
                    }
                } else if visible.isEmpty {
                    EmptyStateView(title: "Sin resultados", message: "Ningún look coincide con los filtros.", systemImage: "line.3.horizontal.decrease.circle")
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(visible) { look in
                            NavigationLink(value: look) {
                                LookCard(look: look, missingCount: look.garmentIDs.filter { !garmentIDs.contains($0) }.count)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(Theme.padding)
        }
        .sheet(isPresented: $showingManualBuilder) {
            ManualLookBuilder()
        }
    }
}

struct LookCard: View {
    let look: Look
    var missingCount = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                StoredImageView(fileName: look.exportedImageFileName, contentMode: .fit, placeholderSymbol: "square.grid.2x2")
                    .frame(maxWidth: .infinity)
                    .aspectRatio(0.8, contentMode: .fit)
                    .background(Theme.cream)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
                if look.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Theme.accent)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(6)
                }
            }
            Text(look.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
            HStack(spacing: 4) {
                if let style = look.style {
                    Text(style.displayName).font(.caption).foregroundStyle(Theme.textSecondary)
                }
                if missingCount > 0 {
                    Label("\(missingCount)", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Theme.danger)
                        .accessibilityLabel("\(missingCount) prenda(s) eliminada(s)")
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Build a look by hand: pick garments, then arrange the collage.
struct ManualLookBuilder: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]
    @State private var selected: [UUID] = []
    @State private var pieces: [CollagePiece] = []
    @State private var showingEditor = false
    @State private var name = ""

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    TextField("Nombre del look", text: $name)
                        .padding(10)
                        .background(Theme.cream, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                    Text("Elige las prendas (\(selected.count))")
                        .font(.headline)
                    if garments.isEmpty {
                        EmptyStateView(title: "Sin prendas", message: "Agrega prendas a tu armario primero.", systemImage: "hanger")
                    }
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(garments) { garment in
                            let isSelected = selected.contains(garment.id)
                            Button {
                                if isSelected { selected.removeAll { $0 == garment.id } } else { selected.append(garment.id) }
                            } label: {
                                GarmentThumbnail(garment: garment, height: 100)
                                    .overlay(alignment: .topLeading) {
                                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(isSelected ? Theme.accent : Theme.textSecondary)
                                            .background(Circle().fill(Theme.surface))
                                            .padding(6)
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                .padding(Theme.padding)
            }
            .looksyBackground()
            .navigationTitle("Nuevo look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear collage") {
                        Task {
                            let chosen = selected.compactMap { id in garments.first { $0.id == id } }
                            pieces = await CollageService.loadPieces(for: chosen)
                            showingEditor = true
                        }
                    }
                    .disabled(selected.isEmpty)
                }
            }
            .navigationDestination(isPresented: $showingEditor) {
                CollageEditorView(
                    composition: CollageService.automaticComposition(for: pieces),
                    pieces: pieces,
                    title: name,
                    saveTitle: "Guardar look"
                ) { composition, finalPieces in
                    let snapshots = finalPieces.map(\.garment)
                    let style = ScoringContext(request: OutfitRequest(), preferences: UserPreferences(), seed: 0).dominantStyle(of: snapshots)
                    _ = try? LookService(context: context).saveLook(
                        name: name.trimmed.isEmpty ? OutfitRecommendationService.name(for: snapshots, style: style) : name,
                        garmentIDs: composition.garmentIDs,
                        composition: composition,
                        pieces: finalPieces,
                        style: style,
                        occasion: nil
                    )
                    dismiss()
                }
            }
        }
    }
}
