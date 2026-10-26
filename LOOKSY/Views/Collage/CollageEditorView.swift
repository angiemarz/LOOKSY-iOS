import SwiftUI
import SwiftData

/// Touch editor: drag to move, pinch to resize, twist to rotate.
struct CollageEditorView: View {
    @State private var viewModel: CollageEditorViewModel
    @Environment(\.dismiss) private var dismiss
    var saveTitle: String
    var onSave: (CollageComposition, [CollagePiece]) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var liveScale: CGFloat = 1
    @State private var liveRotation: Angle = .zero
    @State private var showingAddGarment = false
    @State private var showingExport = false
    @State private var showingDiscardConfirmation = false

    init(composition: CollageComposition, pieces: [CollagePiece], title: String, saveTitle: String = "Guardar", onSave: @escaping (CollageComposition, [CollagePiece]) -> Void) {
        _viewModel = State(initialValue: CollageEditorViewModel(composition: composition, pieces: pieces, title: title))
        self.saveTitle = saveTitle
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            canvas
                .padding(.horizontal, Theme.padding)
                .padding(.top, 8)
            Spacer(minLength: 8)
            controls
        }
        .looksyBackground()
        .navigationTitle("Editar collage")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancelar") {
                    if viewModel.hasChanges {
                        showingDiscardConfirmation = true
                    } else {
                        dismiss()
                    }
                }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(saveTitle) {
                    onSave(viewModel.composition, viewModel.pieces)
                    dismiss()
                }
                .disabled(viewModel.composition.items.isEmpty)
            }
        }
        .confirmationDialog("¿Descartar los cambios del collage?", isPresented: $showingDiscardConfirmation, titleVisibility: .visible) {
            Button("Descartar cambios", role: .destructive) { dismiss() }
            Button("Seguir editando", role: .cancel) {}
        }
        .sheet(isPresented: $showingAddGarment) {
            GarmentPickerSheet(excludedIDs: Set(viewModel.garmentIDsInCanvas)) { garment in
                Task {
                    let pieces = await CollageService.loadPieces(for: [garment])
                    if let piece = pieces.first { viewModel.add(piece) }
                }
            }
        }
        .sheet(isPresented: $showingExport) {
            CollageExportSheet(composition: viewModel.composition, pieces: viewModel.pieces, name: viewModel.title)
                .presentationDetents([.medium])
        }
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                Color(hex: viewModel.composition.backgroundHex)
                    .contentShape(Rectangle())
                    .onTapGesture { viewModel.select(nil) }
                ForEach(viewModel.composition.sortedItems) { item in
                    itemView(item, canvas: size)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius, style: .continuous))
            .simultaneousGesture(pinchAndRotate(canvas: size))
        }
        .aspectRatio(1 / viewModel.composition.aspect.heightRatio, contentMode: .fit)
        .shadow(color: .black.opacity(0.08), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lienzo del collage")
    }

    private func itemView(_ item: CollageItem, canvas: CGSize) -> some View {
        let piece = viewModel.piece(for: item)
        let isSelected = item.id == viewModel.selectedItemID
        let scale = isSelected ? liveScale : 1
        let rotation = isSelected ? liveRotation : .zero
        let offset = isSelected ? dragOffset : .zero
        let width = CGFloat(item.width) * canvas.width
        let height = width * CGFloat(piece?.imageAspect ?? 1.2)

        return CollageItemView(piece: piece, cardStyle: viewModel.composition.cardStyleForPhotos, isSelected: isSelected)
            .frame(width: width, height: height)
            .scaleEffect(scale)
            .rotationEffect(.degrees(item.rotation + rotation.degrees))
            .position(x: item.centerX * canvas.width + offset.width, y: item.centerY * canvas.height + offset.height)
            .onTapGesture { viewModel.select(item.id) }
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if viewModel.selectedItemID != item.id {
                            viewModel.select(item.id)
                        }
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        viewModel.update(item.id) { element in
                            element.centerX += Double(value.translation.width / canvas.width)
                            element.centerY += Double(value.translation.height / canvas.height)
                        }
                        dragOffset = .zero
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(piece?.garment.name ?? "Prenda")
            .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private func pinchAndRotate(canvas: CGSize) -> some Gesture {
        let magnify = MagnifyGesture()
            .onChanged { value in
                guard viewModel.selectedItemID != nil else { return }
                liveScale = value.magnification
            }
            .onEnded { value in
                if let id = viewModel.selectedItemID {
                    viewModel.update(id) { $0.width *= Double(value.magnification) }
                }
                liveScale = 1
            }
        let rotate = RotateGesture()
            .onChanged { value in
                guard viewModel.selectedItemID != nil else { return }
                liveRotation = value.rotation
            }
            .onEnded { value in
                if let id = viewModel.selectedItemID {
                    viewModel.update(id) { $0.rotation += value.rotation.degrees }
                }
                liveRotation = .zero
            }
        return magnify.simultaneously(with: rotate)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 12) {
            if let item = viewModel.selectedItem {
                selectedControls(item)
            } else {
                Text("Toca una prenda para seleccionarla. Arrastra para moverla, pellizca para cambiar su tamaño y gira con dos dedos.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Picker("Formato", selection: Binding(get: { viewModel.composition.aspect }, set: { viewModel.setAspect($0) })) {
                ForEach(CollageAspect.allCases) { aspect in
                    Text(aspect.displayName).tag(aspect)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.padding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(CollageEditorViewModel.backgroundPresets, id: \.self) { hex in
                        Button {
                            viewModel.composition.backgroundHex = hex
                        } label: {
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Theme.separator))
                                .overlay(Circle().stroke(Theme.accent, lineWidth: viewModel.composition.backgroundHex == hex ? 3 : 0).padding(-3))
                        }
                        .accessibilityLabel("Fondo \(hex)")
                    }
                    ColorPicker("Fondo personalizado", selection: Binding(
                        get: { Color(hex: viewModel.composition.backgroundHex) },
                        set: { viewModel.composition.backgroundHex = $0.hexString }
                    ), supportsOpacity: false)
                    .labelsHidden()
                }
                .padding(.horizontal, Theme.padding)
                .padding(.vertical, 4)
            }

            HStack(spacing: 10) {
                Button {
                    showingAddGarment = true
                } label: {
                    Label("Añadir", systemImage: "plus")
                }
                .buttonStyle(SecondaryButtonStyle())
                Button {
                    viewModel.resetLayout()
                } label: {
                    Label("Restablecer", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(SecondaryButtonStyle())
                Toggle(isOn: $viewModel.composition.cardStyleForPhotos) {
                    Text("Tarjetas").font(.footnote)
                }
                .toggleStyle(.button)
                .accessibilityHint("Muestra las fotos con fondo como tarjetas limpias")
                Button {
                    showingExport = true
                } label: {
                    Label("Exportar", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            .font(.footnote)
        }
        .padding(.vertical, 12)
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
    }

    private func selectedControls(_ item: CollageItem) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 14) {
                controlButton("Al frente", "square.3.layers.3d.top.filled") { viewModel.bringToFront() }
                controlButton("Subir", "chevron.up") { viewModel.moveForward() }
                controlButton("Bajar", "chevron.down") { viewModel.moveBackward() }
                controlButton("Al fondo", "square.3.layers.3d.bottom.filled") { viewModel.sendToBack() }
                controlButton("Quitar", "trash", role: .destructive) { viewModel.removeSelected() }
            }
            HStack {
                Image(systemName: "arrow.up.left.and.arrow.down.right").font(.caption)
                Slider(value: Binding(
                    get: { item.width },
                    set: { value in viewModel.update(item.id) { $0.width = value } }
                ), in: 0.08...0.9)
                .accessibilityLabel("Tamaño")
                Image(systemName: "rotate.right").font(.caption)
                Slider(value: Binding(
                    get: { item.rotation },
                    set: { value in viewModel.update(item.id) { $0.rotation = value } }
                ), in: -180...180)
                .accessibilityLabel("Rotación")
            }
            .padding(.horizontal, Theme.padding)
        }
    }

    private func controlButton(_ title: String, _ systemImage: String, role: ButtonRole? = nil, action: @escaping () -> Void) -> some View {
        Button(role: role, action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                Text(title).font(.caption2)
            }
            .frame(minWidth: 52)
        }
        .tint(role == .destructive ? Theme.danger : Theme.accent)
    }
}

/// Export options: PNG to Photos or the share sheet.
struct CollageExportSheet: View {
    let composition: CollageComposition
    let pieces: [CollagePiece]
    let name: String
    @State private var image: UIImage?
    @State private var fileURL: URL?
    @State private var status: String?
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                        .shadow(radius: 4)
                    Text("PNG · \(Int(image.size.width))×\(Int(image.size.height)) px")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ProgressView("Generando imagen…")
                        .frame(height: 220)
                }
                HStack(spacing: 12) {
                    Button {
                        Task { await saveToPhotos() }
                    } label: {
                        Label("Guardar en Fotos", systemImage: "photo.badge.arrow.down")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(image == nil || isSaving)

                    if let fileURL {
                        ShareLink(item: fileURL) {
                            Label("Compartir", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                    }
                }
                if let status {
                    Text(status)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(Theme.padding)
            .navigationTitle("Exportar collage")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task {
            guard image == nil else { return }
            if let rendered = CollageService.render(composition, pieces: pieces) {
                image = rendered
                fileURL = try? CollageService.pngFile(for: rendered, name: name)
            } else {
                status = CollageService.ExportError.renderFailed.localizedDescription
            }
        }
    }

    private func saveToPhotos() async {
        guard let image else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            try await CollageService.saveToPhotos(image)
            status = "Collage guardado en Fotos."
        } catch {
            status = error.localizedDescription
        }
    }
}

/// Picks a garment from the wardrobe (used to add pieces to a collage).
struct GarmentPickerSheet: View {
    var excludedIDs: Set<UUID> = []
    var slot: OutfitSlot?
    var onPick: (Garment) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]
    @State private var search = ""

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                let visible = garments.filter { garment in
                    !excludedIDs.contains(garment.id)
                        && (slot == nil || garment.category.slot == slot)
                        && (search.isEmpty || garment.name.normalizedForSearch.contains(search.normalizedForSearch))
                }
                if visible.isEmpty {
                    EmptyStateView(title: "Sin prendas", message: "No hay más prendas para añadir.", systemImage: "hanger")
                } else {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(visible) { garment in
                            Button {
                                onPick(garment)
                                dismiss()
                            } label: {
                                GarmentThumbnail(garment: garment, height: 110)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.padding)
                }
            }
            .searchable(text: $search, prompt: "Buscar prenda")
            .looksyBackground()
            .navigationTitle("Elegir prenda")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
