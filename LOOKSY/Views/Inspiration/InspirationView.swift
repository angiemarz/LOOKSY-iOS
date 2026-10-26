import SwiftUI
import SwiftData

struct InspirationView: View {
    @Query(sort: \InspirationReference.createdAt, order: .reverse) private var references: [InspirationReference]
    @Query private var garments: [Garment]
    @State private var searchText = ""
    @State private var styleSelection: FashionStyle?
    @State private var paletteSelection: [FashionColor] = []
    @State private var showingAddReference = false
    @State private var onlyFavorites = false
    @State private var recreateAfterAdding = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    recreateCard
                    searchSection
                    savedSection
                }
                .padding(Theme.padding)
            }
            .scrollDismissesKeyboard(.interactively)
            .looksyBackground()
            .navigationTitle("Inspiración")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        recreateAfterAdding = false
                        showingAddReference = true
                    } label: {
                        Label("Guardar referencia", systemImage: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingAddReference) {
                AddReferenceView(openRecreation: recreateAfterAdding)
            }
            .navigationDestination(for: InspirationReference.self) { reference in
                ReferenceDetailView(reference: reference)
            }
            .navigationDestination(for: Look.self) { look in
                LookDetailView(look: look)
            }
            .navigationDestination(for: Garment.self) { garment in
                GarmentDetailView(garment: garment)
            }
        }
    }

    private var recreateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recrea este look")
                .font(Theme.title(.title3))
            Text("Importa una captura o pega un enlace de Pinterest, describe las prendas y LOOKSY buscará equivalentes en tu armario.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Button {
                recreateAfterAdding = true
                showingAddReference = true
            } label: {
                Label("Empezar", systemImage: "camera.viewfinder")
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(LinearGradient(colors: [Theme.roseSoft, Theme.cream], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Buscar en Pinterest", subtitle: "Genera búsquedas en español e inglés.")
            TextField("Describe el look (ej. vestido floral para brunch)", text: $searchText)
                .padding(12)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
            Text("Estilo").font(.subheadline.weight(.semibold))
            SingleChipSelector(items: FashionStyle.allCases, selection: $styleSelection) { $0.displayName }
            Text("Paleta").font(.subheadline.weight(.semibold))
            MultiColorPickerGrid(selection: $paletteSelection)
            let queries = generatedQueries
            if !queries.isEmpty {
                PinterestQueryList(title: "Búsquedas sugeridas", queries: queries)
            }
        }
    }

    private var generatedQueries: [PinterestQuery] {
        var queries: [PinterestQuery] = []
        if !searchText.trimmed.isEmpty {
            let request = OutfitRequestParser().parse(searchText)
            queries += PinterestSearchService.queries(for: request, limit: 4)
        }
        if styleSelection != nil || !paletteSelection.isEmpty {
            queries += PinterestSearchService.queries(colors: paletteSelection, style: styleSelection)
        }
        var seen = Set<String>()
        return queries.filter { seen.insert($0.id).inserted }
    }

    private var savedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Referencias guardadas", subtitle: references.isEmpty ? nil : "\(references.count) guardadas")
            if references.isEmpty {
                EmptyStateView(
                    title: "Sin referencias",
                    message: "Guarda búsquedas, enlaces de Pinterest o capturas que te inspiren.",
                    systemImage: "bookmark"
                )
                .cardStyle(padding: 0)
            } else {
                Chip(title: "Favoritas", systemImage: "heart", isSelected: onlyFavorites) { onlyFavorites.toggle() }
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(references.filter { !onlyFavorites || $0.isFavorite }) { reference in
                        NavigationLink(value: reference) {
                            ReferenceCard(reference: reference)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct ReferenceCard: View {
    let reference: InspirationReference

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if reference.imageFileName != nil {
                    StoredImageView(fileName: reference.imageFileName, contentMode: .fill)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: reference.searchQuery != nil ? "magnifyingglass" : "link")
                            .font(.title2)
                        Text(reference.searchQuery != nil ? "Búsqueda" : "Enlace")
                            .font(.caption)
                    }
                    .foregroundStyle(Theme.accent)
                }
            }
            .frame(height: 150)
            .frame(maxWidth: .infinity)
            .background(Theme.roseSoft)
            .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
            .overlay(alignment: .topTrailing) {
                if reference.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(Theme.accent)
                        .padding(6)
                        .background(.ultraThinMaterial, in: Circle())
                        .padding(6)
                }
            }
            Text(reference.title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.text)
                .lineLimit(2)
            if !reference.colors.isEmpty {
                HStack(spacing: 4) {
                    ForEach(reference.colors.prefix(5)) { ColorDot(color: $0, size: 12) }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}
