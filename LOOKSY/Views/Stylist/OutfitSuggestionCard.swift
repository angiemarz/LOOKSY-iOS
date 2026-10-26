import SwiftUI
import SwiftData

/// One generated outfit: collage, pieces, explanation and actions.
struct OutfitSuggestionCard: View {
    let suggestion: OutfitSuggestion
    @Bindable var viewModel: StylistViewModel
    let garments: [Garment]
    @Environment(\.modelContext) private var context
    @Environment(PreferencesService.self) private var preferences
    @State private var swapSlot: OutfitSlot?
    @State private var showingEditor = false
    @State private var showingPinterest = false

    private var isSaved: Bool { viewModel.savedLookIDs[suggestion.id] != nil }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(suggestion.name)
                    .font(Theme.title(.title3))
                    .foregroundStyle(Theme.text)
                HStack(spacing: 6) {
                    if let style = suggestion.style { tag(style.displayName) }
                    if let occasion = suggestion.occasion { tag(occasion.displayName) }
                    tag("\(suggestion.items.count) prendas")
                }
            }

            CollageCanvasView(composition: viewModel.composition(for: suggestion), pieces: viewModel.collagePieces(for: suggestion))
                .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
                .onTapGesture { showingEditor = true }
                .accessibilityHint("Toca para editar el collage")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(suggestion.items) { item in
                        VStack(spacing: 4) {
                            StoredImageView(fileName: garment(item.id)?.thumbnailFileName, contentMode: .fit, placeholderSymbol: item.category.symbolName)
                                .frame(width: 64, height: 64)
                                .background(Theme.cream, in: RoundedRectangle(cornerRadius: 10))
                            Text(item.name)
                                .font(.caption2)
                                .lineLimit(1)
                                .frame(width: 70)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                ForEach(suggestion.reasons, id: \.self) { reason in
                    Label(reason, systemImage: "checkmark")
                        .font(.footnote)
                        .foregroundStyle(Theme.text)
                }
                ForEach(suggestion.warnings, id: \.self) { warning in
                    Label(warning, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            actions
        }
        .cardStyle()
        .sheet(item: $swapSlot) { slot in
            SwapGarmentSheet(
                slot: slot,
                current: suggestion.item(in: slot),
                options: viewModel.alternatives(for: slot, in: suggestion, preferences: preferences.preferences),
                garments: garments
            ) { replacement in
                Task { await viewModel.swap(slot, in: suggestion, with: replacement, preferences: preferences.preferences) }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                CollageEditorView(
                    composition: viewModel.composition(for: suggestion),
                    pieces: viewModel.collagePieces(for: suggestion),
                    title: suggestion.name,
                    saveTitle: "Aplicar"
                ) { composition, pieces in
                    viewModel.applyEditedCollage(composition, newPieces: pieces, to: suggestion, preferences: preferences.preferences)
                }
            }
        }
        .sheet(isPresented: $showingPinterest) {
            NavigationStack {
                ScrollView {
                    PinterestQueryList(
                        title: "Inspiración para este look",
                        queries: PinterestSearchService.queries(for: suggestion.items, style: suggestion.style, occasion: suggestion.occasion, feminine: viewModel.request?.feminine ?? false),
                        linkedLookID: viewModel.savedLookIDs[suggestion.id],
                        linkedGarmentIDs: suggestion.garmentIDs
                    )
                    .padding(Theme.padding)
                }
                .looksyBackground()
                .navigationTitle("Pinterest")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") { showingPinterest = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                viewModel.save(suggestion, context: context)
            } label: {
                Label(isSaved ? "Guardado en Mis looks" : "Guardar look", systemImage: isSaved ? "checkmark.circle.fill" : "heart")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isSaved)

            HStack(spacing: 8) {
                Button {
                    showingEditor = true
                } label: {
                    Label("Editar", systemImage: "slider.horizontal.3")
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))

                Menu {
                    ForEach(suggestion.items.map(\.slot), id: \.self) { slot in
                        Button(slot.displayName) { swapSlot = slot }
                    }
                    let missingSlots = [OutfitSlot.outerwear, .bag, .accessory, .shoes].filter { slot in
                        !suggestion.items.contains { $0.slot == slot } && garments.contains { $0.category.slot == slot && $0.isAvailable }
                    }
                    if !missingSlots.isEmpty {
                        Divider()
                        ForEach(missingSlots, id: \.self) { slot in
                            Button("Añadir \(slot.displayName.lowercased())") { swapSlot = slot }
                        }
                    }
                } label: {
                    Label("Cambiar", systemImage: "arrow.left.arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Theme.roseSoft, in: Capsule())
                }
            }
            HStack(spacing: 8) {
                Button {
                    Task { await viewModel.alternative(to: suggestion, preferences: preferences.preferences) }
                } label: {
                    Label("Alternativa", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))

                Button {
                    showingPinterest = true
                } label: {
                    Label("Pinterest", systemImage: "sparkle.magnifyingglass")
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            }
        }
    }

    private func tag(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.cream, in: Capsule())
            .foregroundStyle(Theme.textSecondary)
    }

    private func garment(_ id: UUID) -> Garment? {
        garments.first { $0.id == id }
    }
}

/// Lists replacements for one slot, ranked by compatibility with the rest of the outfit.
struct SwapGarmentSheet: View {
    let slot: OutfitSlot
    let current: GarmentSnapshot?
    let options: [GarmentSnapshot]
    let garments: [Garment]
    var onPick: (GarmentSnapshot) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if options.isEmpty {
                    EmptyStateView(
                        title: "Sin alternativas",
                        message: "No hay otras prendas disponibles para \(slot.displayName.lowercased()).",
                        systemImage: "hanger"
                    )
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ordenadas de mejor a menor compatibilidad con el resto del look.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(options) { option in
                                Button {
                                    onPick(option)
                                    dismiss()
                                } label: {
                                    if let garment = garments.first(where: { $0.id == option.id }) {
                                        GarmentThumbnail(garment: garment, height: 110)
                                    } else {
                                        Text(option.name)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(Theme.padding)
                }
            }
            .looksyBackground()
            .navigationTitle(current == nil ? "Añadir \(slot.displayName.lowercased())" : "Cambiar \(slot.displayName.lowercased())")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
