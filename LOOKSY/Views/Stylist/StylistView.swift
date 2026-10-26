import SwiftUI
import SwiftData

struct StylistView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppRouter.self) private var router
    @Environment(PreferencesService.self) private var preferences
    @Query(sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]
    @State private var viewModel = StylistViewModel()
    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    inputCard
                    if viewModel.request == nil && !viewModel.isGenerating {
                        examples
                    }
                    if let request = viewModel.request {
                        interpretation(request)
                    }
                    ForEach(viewModel.missing, id: \.self) { note in
                        InfoBanner(message: note, systemImage: "exclamationmark.circle")
                    }
                    if let info = viewModel.infoMessage {
                        InfoBanner(message: info, systemImage: "checkmark.circle")
                    }
                    if viewModel.isGenerating {
                        ProgressView("Combinando tus prendas…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 30)
                    }
                    ForEach(viewModel.suggestions) { suggestion in
                        OutfitSuggestionCard(
                            suggestion: suggestion,
                            viewModel: viewModel,
                            garments: garments
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    if !viewModel.suggestions.isEmpty {
                        Button {
                            Task { await viewModel.generateAlternatives(preferences: preferences.preferences) }
                        } label: {
                            Label("Generar alternativas", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(viewModel.isGenerating)
                    }
                    if !viewModel.pinterestQueries.isEmpty {
                        PinterestQueryList(title: "Inspiración en Pinterest", queries: viewModel.pinterestQueries)
                    }
                }
                .padding(Theme.padding)
            }
            .scrollDismissesKeyboard(.interactively)
            .looksyBackground()
            .navigationTitle("Crear outfit")
        }
        .onAppear(perform: consumeRouterSeed)
        .onChange(of: router.stylistSeedGarmentID) { _, _ in consumeRouterSeed() }
        .onChange(of: router.stylistSeedText) { _, _ in consumeRouterSeed() }
    }

    private var seedGarment: Garment? {
        guard let id = viewModel.seedGarmentID else { return nil }
        return garments.first { $0.id == id }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("¿Qué outfit necesitas?")
                .font(Theme.title(.title3))
                .foregroundStyle(Theme.text)
            TextField("Ej. algo casual con mis jeans negros para un café", text: $viewModel.text, axis: .vertical)
                .lineLimit(2...5)
                .focused($inputFocused)
                .padding(12)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
                .submitLabel(.go)
                .onSubmit(generate)

            if let seedGarment {
                HStack(spacing: 10) {
                    StoredImageView(fileName: seedGarment.thumbnailFileName, contentMode: .fit, placeholderSymbol: seedGarment.category.symbolName)
                        .frame(width: 44, height: 44)
                    VStack(alignment: .leading) {
                        Text("Incluir esta prenda").font(.caption).foregroundStyle(Theme.textSecondary)
                        Text(seedGarment.name).font(.subheadline.weight(.medium))
                    }
                    Spacer()
                    Button {
                        viewModel.seedGarmentID = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary)
                    }
                    .accessibilityLabel("Quitar prenda")
                }
                .padding(10)
                .background(Theme.roseSoft, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
            }

            Button(action: generate) {
                Label("Crear outfits", systemImage: "wand.and.stars")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!viewModel.canGenerate || viewModel.isGenerating || garments.isEmpty)

            if garments.isEmpty {
                Text("Primero agrega prendas en Mi armario: LOOKSY solo combina tu ropa real.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .cardStyle()
    }

    private var examples: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Prueba con")
                .font(.headline)
                .foregroundStyle(Theme.text)
            ForEach(StylistViewModel.examples, id: \.self) { example in
                Button {
                    viewModel.text = example
                    generate()
                } label: {
                    HStack {
                        Image(systemName: "quote.opening").font(.caption)
                        Text(example).multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.text)
                    .padding(12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                }
                .buttonStyle(.plain)
                .disabled(garments.isEmpty)
            }
        }
    }

    private func interpretation(_ request: OutfitRequest) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Entendí")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.accent)
            if request.interpretation.isEmpty {
                Text("Una solicitud general: combinaré según tus preferencias y la armonía de colores.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            } else {
                ForEach(request.interpretation, id: \.self) { line in
                    Text("• \(line)").font(.footnote).foregroundStyle(Theme.text)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.cream, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
    }

    private func generate() {
        guard viewModel.canGenerate, !garments.isEmpty else { return }
        inputFocused = false
        viewModel.updateFileNames(from: garments)
        Task { await viewModel.generate(garments: garments, preferences: preferences.preferences) }
    }

    private func consumeRouterSeed() {
        guard router.stylistSeedGarmentID != nil || router.stylistSeedText != nil else { return }
        viewModel.seedGarmentID = router.stylistSeedGarmentID
        if let text = router.stylistSeedText { viewModel.text = text }
        router.stylistSeedGarmentID = nil
        router.stylistSeedText = nil
        if viewModel.text.trimmed.isEmpty, let garment = seedGarment {
            viewModel.text = "Un outfit con mi \(garment.name.lowercased())"
        }
    }
}

/// List of Pinterest searches that open in Pinterest (app or web).
struct PinterestQueryList: View {
    let title: String
    let queries: [PinterestQuery]
    var allowsSaving = true
    var linkedLookID: UUID?
    var linkedGarmentIDs: [UUID] = []
    @Environment(\.openURL) private var openURL
    @Environment(\.modelContext) private var context
    @Query private var references: [InspirationReference]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, subtitle: "Búsquedas reales en Pinterest; se abren fuera de LOOKSY.")
            ForEach(queries) { query in
                HStack(spacing: 10) {
                    Text(query.language.rawValue)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Theme.roseSoft, in: Capsule())
                    Button {
                        openURL(query.url)
                    } label: {
                        HStack {
                            Text(query.text)
                                .font(.subheadline)
                                .foregroundStyle(Theme.text)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                                .foregroundStyle(Theme.accent)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Abre la búsqueda en Pinterest")
                    if allowsSaving {
                        let isSaved = references.contains { $0.searchQuery == query.text }
                        Button {
                            save(query)
                        } label: {
                            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        }
                        .disabled(isSaved)
                        .accessibilityLabel(isSaved ? "Búsqueda guardada" : "Guardar búsqueda")
                    }
                    ShareLink(item: query.url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Compartir búsqueda")
                }
                .padding(10)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
            }
        }
    }

    private func save(_ query: PinterestQuery) {
        let reference = InspirationReference(title: query.text, urlString: query.url.absoluteString, searchQuery: query.text)
        if let linkedLookID { reference.linkedLookIDs = [linkedLookID] }
        reference.linkedGarmentIDs = linkedGarmentIDs
        context.insert(reference)
        try? context.save()
    }
}
