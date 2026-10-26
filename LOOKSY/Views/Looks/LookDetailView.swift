import SwiftUI
import SwiftData

struct LookDetailView: View {
    @Bindable var look: Look
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var garments: [Garment]
    @Query(sort: \LookCollection.name) private var collections: [LookCollection]
    @Query private var references: [InspirationReference]

    @State private var pieces: [CollagePiece] = []
    @State private var isLoading = true
    @State private var showingEditor = false
    @State private var showingInfoEditor = false
    @State private var showingExport = false
    @State private var showingPlanner = false
    @State private var showingDeleteConfirmation = false
    @State private var showingCompare = false
    @State private var planDate = Date()
    @State private var message: String?

    private var lookGarments: [Garment] {
        look.garmentIDs.compactMap { id in garments.first { $0.id == id } }
    }

    private var missingCount: Int {
        look.garmentIDs.count - lookGarments.count
    }

    private var composition: CollageComposition {
        look.composition ?? CollageService.automaticComposition(for: pieces)
    }

    private var linkedReferences: [InspirationReference] {
        references.filter { look.referenceIDs.contains($0.id) || $0.linkedLookIDs.contains(look.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isLoading {
                    ShimmerView().aspectRatio(0.8, contentMode: .fit)
                } else {
                    CollageCanvasView(composition: composition, pieces: pieces)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 10, y: 4)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(look.name)
                        .font(Theme.title(.title))
                        .foregroundStyle(Theme.text)
                    HStack(spacing: 8) {
                        if let style = look.style { Text(style.displayName) }
                        if let occasion = look.occasion { Text("· \(occasion.displayName)") }
                    }
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    if !look.tags.isEmpty {
                        Text(look.tags.map { "#\($0)" }.joined(separator: " "))
                            .font(.footnote)
                            .foregroundStyle(Theme.accent)
                    }
                }

                if missingCount > 0 {
                    InfoBanner(
                        message: "\(missingCount) prenda(s) de este look ya no están en tu armario. Edita el collage para reemplazarlas o quitarlas.",
                        systemImage: "exclamationmark.triangle",
                        tint: Theme.danger
                    )
                }

                if let message {
                    InfoBanner(message: message, systemImage: "checkmark.circle")
                }

                actionGrid

                VStack(alignment: .leading, spacing: 10) {
                    Text("Prendas").font(.headline)
                    ForEach(lookGarments) { garment in
                        NavigationLink(value: garment) {
                            HStack(spacing: 12) {
                                StoredImageView(fileName: garment.thumbnailFileName, contentMode: .fit, placeholderSymbol: garment.category.symbolName)
                                    .frame(width: 52, height: 52)
                                    .background(Theme.cream, in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading) {
                                    Text(garment.name).foregroundStyle(Theme.text)
                                    Text(garment.category.displayName).font(.caption).foregroundStyle(Theme.textSecondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .cardStyle()

                if !look.explanation.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Por qué funciona").font(.headline)
                        Text(look.explanation).font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }

                if !look.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notas").font(.headline)
                        Text(look.notes).font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }

                if !linkedReferences.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Referencias de inspiración").font(.headline)
                        ForEach(linkedReferences) { reference in
                            NavigationLink {
                                ReferenceDetailView(reference: reference)
                            } label: {
                                Label(reference.title, systemImage: reference.imageFileName == nil ? "link" : "photo")
                                    .font(.subheadline)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }

                PinterestQueryList(
                    title: "Busca inspiración",
                    queries: PinterestSearchService.queries(for: lookGarments.map { GarmentSnapshot($0) }, style: look.style, occasion: look.occasion),
                    linkedLookID: look.id,
                    linkedGarmentIDs: look.garmentIDs
                )
            }
            .padding(Theme.padding)
        }
        .looksyBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingInfoEditor = true } label: { Label("Editar detalles", systemImage: "pencil") }
                    Button {
                        if let copy = try? LookService(context: context).duplicate(look) {
                            message = "Se creó “\(copy.name)”."
                        }
                    } label: { Label("Duplicar", systemImage: "plus.square.on.square") }
                    Menu {
                        if collections.isEmpty {
                            Text("Crea una colección en la pestaña Colecciones")
                        }
                        ForEach(collections) { collection in
                            let contains = collection.lookIDs.contains(look.id)
                            Button {
                                if contains {
                                    collection.lookIDs.removeAll { $0 == look.id }
                                } else {
                                    collection.lookIDs.append(look.id)
                                }
                                try? context.save()
                            } label: {
                                Label(collection.name, systemImage: contains ? "checkmark" : "folder")
                            }
                        }
                    } label: { Label("Colecciones", systemImage: "folder") }
                    Button(role: .destructive) { showingDeleteConfirmation = true } label: { Label("Eliminar", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis.circle").accessibilityLabel("Más opciones")
                }
            }
        }
        .task { await loadPieces() }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                CollageEditorView(composition: composition, pieces: pieces, title: look.name) { newComposition, newPieces in
                    pieces = newPieces
                    try? LookService(context: context).updateComposition(of: look, composition: newComposition, pieces: newPieces)
                }
            }
        }
        .sheet(isPresented: $showingInfoEditor) {
            LookInfoEditor(look: look)
        }
        .sheet(isPresented: $showingExport) {
            CollageExportSheet(composition: composition, pieces: pieces, name: look.name)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingCompare) {
            NavigationStack {
                CompareView(lookID: look.id, reference: linkedReferences.first)
            }
        }
        .sheet(isPresented: $showingPlanner) {
            NavigationStack {
                Form {
                    DatePicker("Día", selection: $planDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                .navigationTitle("Planificar look")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { showingPlanner = false } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Planificar") {
                            context.insert(PlannedOutfit(day: planDate, lookID: look.id))
                            try? context.save()
                            message = "Planificado para el \(planDate.formatted(date: .long, time: .omitted))."
                            showingPlanner = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
        }
        .confirmationDialog("¿Eliminar este look?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Eliminar look", role: .destructive) {
                let target = look
                let service = LookService(context: context)
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    try? service.delete(target)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Las prendas no se borran; solo el look, su collage y su planificación.")
        }
    }

    private var actionGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: 10) {
            actionButton(look.isFavorite ? "Favorito" : "Favorito", look.isFavorite ? "heart.fill" : "heart") {
                look.isFavorite.toggle()
                try? context.save()
            }
            actionButton("Editar", "slider.horizontal.3") { showingEditor = true }
            actionButton("Exportar", "square.and.arrow.up") { showingExport = true }
            actionButton("Planificar", "calendar.badge.plus") { showingPlanner = true }
            actionButton("Usado hoy", "checkmark.seal") {
                WardrobeService(context: context).markWorn(look.garmentIDs)
                look.lastWornAt = Date()
                try? context.save()
                message = "Registrado como usado hoy."
            }
            actionButton("Comparar", "rectangle.split.2x1") { showingCompare = true }
        }
    }

    private func actionButton(_ title: String, _ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImage).font(.title3)
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(Theme.accent)
            .background(Theme.roseSoft, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
        }
        .buttonStyle(.plain)
    }

    private func loadPieces() async {
        let ids = look.composition?.garmentIDs ?? look.garmentIDs
        let byID = Dictionary(garments.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let existing = ids.compactMap { byID[$0] }
        var loaded = await CollageService.loadPieces(for: existing)
        // Placeholders for deleted garments so the collage shows the gap.
        for id in ids where byID[id] == nil {
            loaded.append(CollagePiece(garment: GarmentSnapshot(id: id, name: "Prenda eliminada", category: .accesorios, primaryColor: .gris), image: nil))
        }
        pieces = loaded
        isLoading = false
    }
}

/// Edits the look's name, style, occasion, tags and notes.
struct LookInfoEditor: View {
    @Bindable var look: Look
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    var body: some View {
        NavigationStack {
            Form {
                Section("Nombre") {
                    TextField("Nombre", text: $look.name)
                }
                Section("Estilo") {
                    SingleChipSelector(items: FashionStyle.allCases, selection: Binding(get: { look.style }, set: { look.style = $0 })) { $0.displayName }
                        .padding(.vertical, 4)
                }
                Section("Ocasión") {
                    SingleChipSelector(items: Occasion.allCases, selection: Binding(get: { look.occasion }, set: { look.occasion = $0 })) { $0.displayName }
                        .padding(.vertical, 4)
                }
                Section("Etiquetas") {
                    TagEditor(tags: $look.tags)
                }
                Section("Notas") {
                    TextField("Notas", text: $look.notes, axis: .vertical)
                        .lineLimit(3...8)
                }
            }
            .navigationTitle("Detalles del look")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        look.updatedAt = Date()
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }
}
