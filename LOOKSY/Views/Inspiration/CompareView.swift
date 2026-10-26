import SwiftUI
import SwiftData

/// "Inspiración vs. mi look": reference and own outfit side by side,
/// compared with explainable criteria (no invented similarity scores).
struct CompareView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case inspiration, mine, sideBySide
        var id: String { rawValue }
        var title: String {
            switch self {
            case .inspiration: return "Inspiración"
            case .mine: return "Mi look"
            case .sideBySide: return "Lado a lado"
            }
        }
    }

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query(sort: \Look.createdAt, order: .reverse) private var looks: [Look]
    @Query(sort: \InspirationReference.createdAt, order: .reverse) private var references: [InspirationReference]
    @Query private var garments: [Garment]

    @State private var lookID: UUID?
    @State private var referenceID: UUID?
    @State private var mode: Mode = .sideBySide
    @State private var pieces: [CollagePiece] = []
    @State private var showingLookPicker = false
    @State private var showingReferencePicker = false
    @State private var showingEditor = false

    init(lookID: UUID?, reference: InspirationReference?) {
        _lookID = State(initialValue: lookID)
        _referenceID = State(initialValue: reference?.id)
    }

    private var look: Look? { looks.first { $0.id == lookID } }
    private var reference: InspirationReference? { references.first { $0.id == referenceID } }

    private var lookGarments: [Garment] {
        guard let look else { return [] }
        return look.garmentIDs.compactMap { id in garments.first { $0.id == id } }
    }

    private var criteria: [ComparisonCriterion] {
        guard let reference, look != nil else { return [] }
        let target = reference.target ?? RecreationTarget(colors: reference.colors, style: reference.style, formality: reference.formality)
        return RecreationService.criteria(target: target, items: lookGarments.map { GarmentSnapshot($0) }, style: look?.style)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Vista", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .inspiration:
                    inspirationPanel
                case .mine:
                    myLookPanel
                case .sideBySide:
                    HStack(alignment: .top, spacing: 10) {
                        inspirationPanel.frame(maxWidth: .infinity)
                        myLookPanel.frame(maxWidth: .infinity)
                    }
                }

                if !criteria.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comparación").font(.headline)
                        CriteriaList(criteria: criteria)
                        Text("Criterios calculados a partir de las prendas, colores, estilo y formalidad que describiste.")
                            .font(.caption2)
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
            }
            .padding(Theme.padding)
        }
        .looksyBackground()
        .navigationTitle("Inspiración vs. mi look")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cerrar") { dismiss() }
            }
        }
        .task(id: lookID) { await loadPieces() }
        .sheet(isPresented: $showingLookPicker) {
            LookPickerSheet(title: "Elegir mi look") { picked in lookID = picked.id }
        }
        .sheet(isPresented: $showingReferencePicker) {
            ReferencePickerSheet { picked in referenceID = picked.id }
        }
        .sheet(isPresented: $showingEditor) {
            if let look {
                NavigationStack {
                    CollageEditorView(composition: look.composition ?? CollageService.automaticComposition(for: pieces), pieces: pieces, title: look.name) { composition, newPieces in
                        pieces = newPieces
                        try? LookService(context: context).updateComposition(of: look, composition: composition, pieces: newPieces)
                    }
                }
            }
        }
    }

    // MARK: Panels

    private var inspirationPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A · Inspiración").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
            if let reference {
                if reference.imageFileName != nil {
                    StoredImageView(fileName: reference.imageFileName, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "link").font(.title2)
                        Text("Referencia sin imagen").font(.caption)
                    }
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .background(Theme.roseSoft, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                }
                Text(reference.title).font(.subheadline.weight(.semibold))
                if !reference.colors.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(reference.colors) { ColorDot(color: $0, size: 16) }
                    }
                }
                if let style = reference.style {
                    Text(style.displayName).font(.caption).foregroundStyle(Theme.textSecondary)
                }
                if let url = reference.url {
                    Button {
                        openURL(url)
                    } label: {
                        Label("Enlace original", systemImage: "arrow.up.right.square").font(.caption)
                    }
                }
                Button("Cambiar referencia") { showingReferencePicker = true }
                    .font(.caption)
            } else {
                Button {
                    showingReferencePicker = true
                } label: {
                    Label("Elegir referencia", systemImage: "bookmark")
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            }
        }
        .cardStyle(padding: 12)
    }

    private var myLookPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("B · Mi outfit").font(.caption.weight(.bold)).foregroundStyle(Theme.accent)
            if let look {
                CollageCanvasView(composition: look.composition ?? CollageService.automaticComposition(for: pieces), pieces: pieces)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                Text(look.name).font(.subheadline.weight(.semibold))
                ForEach(lookGarments) { garment in
                    HStack(spacing: 4) {
                        ColorDot(color: garment.primaryColor, size: 10)
                        Text(garment.name).font(.caption).lineLimit(1)
                    }
                }
                let accessories = lookGarments.filter { $0.category == .accesorios || $0.category == .bolsos }
                if !accessories.isEmpty {
                    Text("Accesorios: \(accessories.map(\.name).joined(separator: ", "))")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSecondary)
                }
                Button("Sustituir prendas") { showingEditor = true }
                    .font(.caption)
                Button("Cambiar look") { showingLookPicker = true }
                    .font(.caption)
            } else {
                Button {
                    showingLookPicker = true
                } label: {
                    Label("Elegir look", systemImage: "square.grid.2x2")
                }
                .buttonStyle(SecondaryButtonStyle(fullWidth: true))
            }
        }
        .cardStyle(padding: 12)
    }

    private func loadPieces() async {
        pieces = await CollageService.loadPieces(for: lookGarments)
    }
}

struct ReferencePickerSheet: View {
    var onPick: (InspirationReference) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \InspirationReference.createdAt, order: .reverse) private var references: [InspirationReference]

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if references.isEmpty {
                    EmptyStateView(title: "Sin referencias", message: "Guarda referencias en la pestaña Inspiración.", systemImage: "bookmark")
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(references) { reference in
                            Button {
                                onPick(reference)
                                dismiss()
                            } label: {
                                ReferenceCard(reference: reference)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.padding)
                }
            }
            .looksyBackground()
            .navigationTitle("Elegir referencia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
