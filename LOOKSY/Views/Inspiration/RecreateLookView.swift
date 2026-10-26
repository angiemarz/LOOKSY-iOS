import SwiftUI
import SwiftData

/// "Recrea este look": the user describes the reference (manual editor,
/// with the palette detected from the imported image) and LOOKSY finds
/// equivalents in the wardrobe.
struct RecreateLookView: View {
    @Bindable var reference: InspirationReference
    @Environment(\.modelContext) private var context
    @Environment(PreferencesService.self) private var preferences
    @Query private var garments: [Garment]
    @State private var target = RecreationTarget()
    @State private var recreations: [Recreation] = []
    @State private var pieces: [UUID: CollagePiece] = [:]
    @State private var addingSlot: OutfitSlot?
    @State private var savedKinds: Set<Recreation.Kind> = []
    @State private var editing: Recreation?
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                referenceHeader
                honestyNote
                targetEditor
                Button {
                    search()
                } label: {
                    Label("Buscar en mi armario", systemImage: "hanger")
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(target.pieces.isEmpty || garments.isEmpty)
                if garments.isEmpty {
                    Text("Agrega prendas a tu armario para recrear looks.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                if let message {
                    InfoBanner(message: message, systemImage: "checkmark.circle")
                }
                ForEach(recreations) { recreation in
                    recreationCard(recreation)
                }
            }
            .padding(Theme.padding)
        }
        .looksyBackground()
        .navigationTitle("Recrea este look")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: loadTarget)
        .onDisappear(perform: storeTarget)
        .confirmationDialog("Añadir prenda", isPresented: Binding(get: { addingSlot != nil }, set: { if !$0 { addingSlot = nil } })) {
            ForEach(GarmentCategory.categories(in: addingSlot ?? .top)) { category in
                Button(category.displayName) {
                    target.pieces.append(TargetPiece(slot: category.slot, category: category, color: target.colors.first))
                    addingSlot = nil
                }
            }
            Button("Cualquier \(addingSlot?.displayName.lowercased() ?? "")") {
                if let slot = addingSlot {
                    target.pieces.append(TargetPiece(slot: slot, category: nil, color: nil))
                }
                addingSlot = nil
            }
        }
        .sheet(item: $editing) { recreation in
            NavigationStack {
                CollageEditorView(
                    composition: CollageService.automaticComposition(for: collagePieces(recreation)),
                    pieces: collagePieces(recreation),
                    title: lookName(for: recreation),
                    saveTitle: "Guardar look"
                ) { composition, finalPieces in
                    save(recreation, composition: composition, pieces: finalPieces)
                }
            }
        }
    }

    private var referenceHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            if reference.imageFileName != nil {
                StoredImageView(fileName: reference.imageFileName, contentMode: .fill)
                    .frame(width: 96, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
            } else {
                Image(systemName: "link")
                    .font(.title)
                    .frame(width: 96, height: 128)
                    .background(Theme.roseSoft, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(reference.title).font(.headline)
                if let url = reference.url {
                    Link(destination: url) {
                        Label("Ver referencia original", systemImage: "arrow.up.right.square")
                            .font(.footnote)
                    }
                }
                if !reference.colors.isEmpty {
                    HStack(spacing: 4) { ForEach(reference.colors) { ColorDot(color: $0, size: 14) } }
                }
            }
        }
    }

    private var honestyNote: some View {
        InfoBanner(
            message: reference.imageFileName == nil
                ? "LOOKSY no puede ver el contenido de un enlace de Pinterest. Describe abajo las prendas que ves en el look."
                : "De la imagen solo se detecta la paleta de colores. Indica abajo qué prendas aparecen en el look.",
            systemImage: "info.circle"
        )
    }

    private var targetEditor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Prendas del look de referencia").font(.headline)
            if target.pieces.isEmpty {
                Text("Añade cada prenda que ves en la referencia.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            ForEach(target.pieces) { piece in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(piece.description.capitalizedFirst).font(.subheadline.weight(.semibold))
                        Spacer()
                        Button(role: .destructive) {
                            target.pieces.removeAll { $0.id == piece.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .accessibilityLabel("Quitar prenda")
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Chip(title: "Sin color", isSelected: piece.color == nil) { setColor(nil, for: piece.id) }
                            ForEach(colorOptions, id: \.self) { color in
                                Button {
                                    setColor(color, for: piece.id)
                                } label: {
                                    ColorDot(color: color, size: 26)
                                        .overlay(Circle().stroke(Theme.accent, lineWidth: piece.color == color ? 3 : 0).padding(-3))
                                }
                                .accessibilityLabel(color.displayName)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(12)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([OutfitSlot.top, .bottom, .onePiece, .outerwear, .shoes, .bag, .accessory]) { slot in
                        Button {
                            addingSlot = slot
                        } label: {
                            Label(slot.displayName, systemImage: "plus")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                }
            }

            Text("Estilo").font(.subheadline.weight(.semibold))
            SingleChipSelector(items: FashionStyle.allCases, selection: $target.style) { $0.displayName }
            Stepper(value: $target.formality, in: Formality.range) {
                LabeledContent("Formalidad", value: Formality.label(for: target.formality))
            }
        }
        .cardStyle()
    }

    private func setColor(_ color: FashionColor?, for pieceID: UUID) {
        guard let index = target.pieces.firstIndex(where: { $0.id == pieceID }) else { return }
        target.pieces[index].color = color
    }

    /// Detected colors first, then the full palette.
    private var colorOptions: [FashionColor] {
        let detected = reference.colors
        return detected + FashionColor.allCases.filter { !detected.contains($0) }
    }

    @ViewBuilder
    private func recreationCard(_ recreation: Recreation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(recreation.kind.title).font(Theme.title(.title3))
            Text(recreation.kind.subtitle).font(.footnote).foregroundStyle(Theme.textSecondary)
            if recreation.items.isEmpty {
                InfoBanner(message: "No se encontraron prendas suficientes para esta versión.", systemImage: "exclamationmark.circle")
            } else {
                CollageCanvasView(composition: CollageService.automaticComposition(for: collagePieces(recreation)), pieces: collagePieces(recreation))
                    .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
            }
            ForEach(recreation.notes, id: \.self) { note in
                Text("• \(note)").font(.footnote)
            }
            if !recreation.criteria.isEmpty {
                CriteriaList(criteria: recreation.criteria)
            }
            if !recreation.items.isEmpty {
                HStack(spacing: 8) {
                    Button {
                        save(recreation, composition: CollageService.automaticComposition(for: collagePieces(recreation)), pieces: collagePieces(recreation))
                    } label: {
                        Label(savedKinds.contains(recreation.kind) ? "Guardado" : "Guardar look", systemImage: savedKinds.contains(recreation.kind) ? "checkmark.circle.fill" : "heart")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(savedKinds.contains(recreation.kind))
                    Button {
                        editing = recreation
                    } label: {
                        Label("Editar", systemImage: "slider.horizontal.3")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
            }
        }
        .cardStyle()
    }

    private func collagePieces(_ recreation: Recreation) -> [CollagePiece] {
        recreation.items.map { pieces[$0.id] ?? CollagePiece(garment: $0, image: nil) }
    }

    private func lookName(for recreation: Recreation) -> String {
        "\(reference.title) · \(recreation.kind == .creative ? "versión creativa" : "recreación")"
    }

    private func loadTarget() {
        if let stored = reference.target {
            target = stored
        } else {
            target.colors = reference.colors
            target.style = reference.style
            target.formality = reference.formality
        }
    }

    private func storeTarget() {
        reference.target = target
        if let style = target.style { reference.style = style }
        reference.formality = target.formality
        try? context.save()
    }

    private func search() {
        storeTarget()
        let snapshots = garments.map { GarmentSnapshot($0) }
        recreations = RecreationService().recreate(target: target, wardrobe: snapshots, preferences: preferences.preferences)
        savedKinds = []
        message = nil
        let needed = Set(recreations.flatMap(\.items).map(\.id))
        Task {
            let loaded = await CollageService.loadPieces(for: garments.filter { needed.contains($0.id) })
            for piece in loaded { pieces[piece.id] = piece }
        }
    }

    private func save(_ recreation: Recreation, composition: CollageComposition, pieces finalPieces: [CollagePiece]) {
        do {
            let look = try LookService(context: context).saveLook(
                name: lookName(for: recreation),
                garmentIDs: composition.garmentIDs,
                composition: composition,
                pieces: finalPieces,
                style: target.style,
                occasion: nil,
                explanation: recreation.notes.joined(separator: "\n"),
                pinterestURLs: reference.urlString.map { [$0] } ?? [],
                referenceIDs: [reference.id]
            )
            if !reference.linkedLookIDs.contains(look.id) { reference.linkedLookIDs.append(look.id) }
            try? context.save()
            savedKinds.insert(recreation.kind)
            message = "“\(look.name)” se guardó en Mis looks."
        } catch {
            message = "No se pudo guardar el look."
        }
    }
}

/// Shows explainable comparison criteria with icons.
struct CriteriaList: View {
    let criteria: [ComparisonCriterion]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(criteria) { criterion in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: icon(criterion.status))
                        .foregroundStyle(color(criterion.status))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(criterion.title).font(.caption.weight(.semibold))
                        Text(criterion.detail).font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cream, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
    }

    private func icon(_ status: ComparisonCriterion.Status) -> String {
        switch status {
        case .match: return "checkmark.circle.fill"
        case .partial: return "circle.lefthalf.filled"
        case .miss: return "xmark.circle"
        case .unknown: return "questionmark.circle"
        }
    }

    private func color(_ status: ComparisonCriterion.Status) -> Color {
        switch status {
        case .match: return Theme.accent
        case .partial: return Theme.rose
        case .miss, .unknown: return Theme.textSecondary
        }
    }
}
