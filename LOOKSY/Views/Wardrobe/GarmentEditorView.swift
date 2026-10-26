import SwiftUI
import SwiftData

/// Create or edit a garment: photo tools + attributes.
struct GarmentEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: GarmentEditorViewModel
    @State private var showingCrop = false
    var saveTitle: String = "Guardar"
    var onSaved: (() -> Void)?
    var onSkip: (() -> Void)?

    init(viewModel: GarmentEditorViewModel, saveTitle: String = "Guardar", onSaved: (() -> Void)? = nil, onSkip: (() -> Void)? = nil) {
        _viewModel = State(initialValue: viewModel)
        self.saveTitle = saveTitle
        self.onSaved = onSaved
        self.onSkip = onSkip
    }

    var body: some View {
        Form {
            Section {
                photoSection
            }
            .listRowBackground(Theme.cream)

            if let error = viewModel.errorMessage {
                Section {
                    InfoBanner(message: error, systemImage: "exclamationmark.triangle", tint: Theme.danger)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Datos básicos") {
                TextField("Nombre (ej. Blusa rosa de lino)", text: $viewModel.draft.name)
                Picker("Categoría", selection: $viewModel.draft.category) {
                    ForEach(GarmentCategory.allCases) { category in
                        Label(category.displayName, systemImage: category.symbolName).tag(category)
                    }
                }
                .onChange(of: viewModel.draft.category) { _, newValue in
                    if viewModel.isCreating {
                        viewModel.draft.formality = newValue.defaultFormality
                    }
                }
            }

            Section {
                if let analysis = viewModel.colorAnalysis, !analysis.entries.isEmpty {
                    detectedColors(analysis)
                }
                ColorPickerGrid(
                    selection: Binding(
                        get: { viewModel.draft.primaryColor },
                        set: { viewModel.draft.primaryColor = $0; viewModel.userPickedColor = true }
                    ),
                    highlighted: Set(viewModel.colorAnalysis?.entries.map(\.color) ?? [])
                )
                .padding(.vertical, 6)
            } header: {
                Text("Color principal")
            } footer: {
                Text("El color se detecta en el dispositivo; corrígelo si no coincide.")
            }

            Section("Colores secundarios") {
                MultiColorPickerGrid(selection: $viewModel.draft.secondaryColors, excluded: [viewModel.draft.primaryColor])
                    .padding(.vertical, 6)
            }

            Section("Detalles") {
                Picker("Material", selection: $viewModel.draft.material) {
                    ForEach(GarmentMaterial.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Estampado", selection: $viewModel.draft.pattern) {
                    ForEach(GarmentPattern.allCases) { Text($0.displayName).tag($0) }
                }
                Picker("Silueta", selection: $viewModel.draft.silhouette) {
                    ForEach(GarmentSilhouette.allCases) { Text($0.displayName).tag($0) }
                }
                VStack(alignment: .leading) {
                    Stepper(value: $viewModel.draft.formality, in: Formality.range) {
                        HStack {
                            Text("Formalidad")
                            Spacer()
                            Text(Formality.label(for: viewModel.draft.formality))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
            }

            Section("Estilo") {
                ChipSelector(items: FashionStyle.allCases, selection: $viewModel.draft.styles) { $0.displayName }
                    .padding(.vertical, 4)
            }

            Section("Ocasiones") {
                ChipSelector(items: Occasion.allCases, selection: $viewModel.draft.occasions) { $0.displayName }
                    .padding(.vertical, 4)
            }

            Section {
                ChipSelector(items: Season.allCases, selection: $viewModel.draft.seasons) { $0.displayName }
                    .padding(.vertical, 4)
            } header: {
                Text("Temporada")
            } footer: {
                Text("Sin selección = todo el año.")
            }

            Section("Etiquetas") {
                TagEditor(tags: $viewModel.draft.tags, placeholder: "Ej. tacones, básico, oficina")
            }

            Section("Notas") {
                TextField("Notas personales", text: $viewModel.draft.notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            Section {
                Toggle("Disponible", isOn: $viewModel.draft.isAvailable)
                Toggle("Favorita", isOn: $viewModel.draft.isFavorite)
            } footer: {
                Text("Las prendas no disponibles (lavandería, préstamo) no se usan en las recomendaciones.")
            }
        }
        .scrollContentBackground(.hidden)
        .looksyBackground()
        .navigationTitle(viewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(saveTitle) {
                    if viewModel.save(context: context) {
                        if let onSaved { onSaved() } else { dismiss() }
                    }
                }
                .disabled(viewModel.isProcessing)
            }
            if let onSkip {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Omitir", action: onSkip)
                }
            }
        }
        .task {
            await viewModel.loadStoredImages()
            if viewModel.isCreating && viewModel.colorAnalysis == nil {
                await viewModel.analyzeColors(updateSelection: true)
            }
        }
        .sheet(isPresented: $showingCrop) {
            if let image = viewModel.workingImage {
                ImageCropView(image: image) { rect in
                    viewModel.applyCrop(rect)
                    Task { await viewModel.analyzeColors(updateSelection: false) }
                }
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(viewModel.useCutout ? AnyShapeStyle(Color.white) : AnyShapeStyle(Theme.beige.opacity(0.4)))
                if let image = viewModel.displayedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .padding(12)
                        .accessibilityLabel("Foto de la prenda")
                } else {
                    ProgressView()
                }
                if viewModel.isProcessing {
                    VStack(spacing: 8) {
                        ProgressView()
                        if let message = viewModel.processingMessage {
                            Text(message).font(.footnote)
                        }
                    }
                    .padding(16)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                }
            }
            .frame(height: 300)

            if viewModel.cutoutImage != nil {
                Picker("Imagen", selection: $viewModel.useCutout) {
                    Text("Sin fondo").tag(true)
                    Text("Foto original").tag(false)
                }
                .pickerStyle(.segmented)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    toolButton("Quitar fondo", systemImage: "person.crop.rectangle.badge.plus") {
                        Task { await viewModel.removeBackground() }
                    }
                    toolButton("Recortar", systemImage: "crop") {
                        showingCrop = true
                    }
                    toolButton("Auto encuadre", systemImage: "viewfinder") {
                        Task { await viewModel.autoFrame() }
                    }
                    toolButton("Girar", systemImage: "rotate.right") {
                        viewModel.rotate(clockwise: true)
                    }
                    toolButton("Detectar color", systemImage: "eyedropper") {
                        viewModel.userPickedColor = false
                        Task { await viewModel.analyzeColors(updateSelection: true) }
                    }
                }
            }
            .disabled(viewModel.isProcessing || viewModel.workingImage == nil)
        }
        .padding(.vertical, 6)
    }

    private func toolButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.semibold))
        }
        .buttonStyle(SecondaryButtonStyle())
    }

    private func detectedColors(_ analysis: ColorAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Detectado en la foto")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
            HStack(spacing: 12) {
                ForEach(analysis.entries, id: \.color) { entry in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(hex: entry.averageHex))
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(Theme.separator))
                        Text("\(entry.color.displayName) \(Int((entry.share * 100).rounded()))%")
                            .font(.caption)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
