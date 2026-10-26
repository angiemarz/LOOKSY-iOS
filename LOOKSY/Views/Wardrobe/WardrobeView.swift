import SwiftUI
import SwiftData
import PhotosUI

struct WardrobeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Garment.createdAt, order: .reverse) private var garments: [Garment]
    @State private var viewModel = WardrobeViewModel()
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var showingFilters = false
    @State private var importQueue: ImageImportQueue?
    @State private var isLoadingPicks = false

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        NavigationStack {
            Group {
                if garments.isEmpty {
                    EmptyStateView(
                        title: "Tu armario está vacío",
                        message: "Fotografía o importa tus prendas reales. Todo se guarda solo en tu iPhone.",
                        systemImage: "hanger",
                        actionTitle: "Agregar prendas"
                    ) {
                        showingPhotoPicker = true
                    }
                } else {
                    content
                }
            }
            .looksyBackground()
            .navigationTitle("Mi armario")
            .searchable(text: $viewModel.searchText, prompt: "Buscar por nombre, color o etiqueta")
            .toolbar { toolbarContent }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $pickerItems, maxSelectionCount: 20, matching: .images)
            .onChange(of: pickerItems) { _, items in
                Task { await loadPicked(items) }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraPicker { image in
                    importQueue = ImageImportQueue(images: [image])
                }
                .ignoresSafeArea()
            }
            .sheet(item: $importQueue) { queue in
                AddGarmentsFlow(queue: queue)
            }
            .sheet(isPresented: $showingFilters) {
                WardrobeFiltersSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
            }
            .overlay {
                if isLoadingPicks {
                    ProgressView("Importando fotos…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.cornerRadius))
                }
            }
            .navigationDestination(for: Garment.self) { garment in
                GarmentDetailView(garment: garment)
            }
        }
    }

    private var content: some View {
        let visible = viewModel.apply(to: garments)
        return ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                categoryBar
                HStack {
                    Text("\(visible.count) de \(garments.count) prendas")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                    Spacer()
                    Menu {
                        Picker("Ordenar", selection: $viewModel.sort) {
                            ForEach(WardrobeSort.allCases) { sort in
                                Text(sort.displayName).tag(sort)
                            }
                        }
                    } label: {
                        Label(viewModel.sort.displayName, systemImage: "arrow.up.arrow.down")
                            .font(.footnote)
                    }
                }
                if visible.isEmpty {
                    EmptyStateView(
                        title: "Sin resultados",
                        message: "Ninguna prenda coincide con la búsqueda o los filtros.",
                        systemImage: "line.3.horizontal.decrease.circle",
                        actionTitle: "Quitar filtros"
                    ) {
                        viewModel.resetFilters()
                        viewModel.searchText = ""
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(visible) { garment in
                            NavigationLink(value: garment) {
                                GarmentThumbnail(garment: garment)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    garment.isFavorite.toggle()
                                    try? context.save()
                                } label: {
                                    Label(garment.isFavorite ? "Quitar de favoritas" : "Marcar favorita", systemImage: garment.isFavorite ? "heart.slash" : "heart")
                                }
                                Button {
                                    garment.isAvailable.toggle()
                                    try? context.save()
                                } label: {
                                    Label(garment.isAvailable ? "Marcar no disponible" : "Marcar disponible", systemImage: "checkmark.circle")
                                }
                            }
                        }
                    }
                }
            }
            .padding(Theme.padding)
        }
    }

    private var categoryBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "Todas", isSelected: viewModel.selectedCategories.isEmpty) {
                    viewModel.selectedCategories = []
                }
                ForEach(GarmentCategory.allCases) { category in
                    let count = garments.filter { $0.category == category }.count
                    if count > 0 {
                        Chip(title: "\(category.displayName) \(count)", isSelected: viewModel.selectedCategories.contains(category)) {
                            if let index = viewModel.selectedCategories.firstIndex(of: category) {
                                viewModel.selectedCategories.remove(at: index)
                            } else {
                                viewModel.selectedCategories.append(category)
                            }
                        }
                    }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button {
                showingFilters = true
            } label: {
                Label(viewModel.activeFilterCount > 0 ? "Filtros (\(viewModel.activeFilterCount))" : "Filtros", systemImage: viewModel.activeFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Importar de Fotos", systemImage: "photo.on.rectangle")
                }
                if CameraPicker.isAvailable {
                    Button {
                        showingCamera = true
                    } label: {
                        Label("Tomar foto", systemImage: "camera")
                    }
                }
            } label: {
                Label("Agregar", systemImage: "plus.circle.fill")
            }
        }
    }

    private func loadPicked(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        isLoadingPicks = true
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(image)
            }
        }
        isLoadingPicks = false
        pickerItems = []
        if !images.isEmpty {
            importQueue = ImageImportQueue(images: images)
        }
    }
}

/// Photos waiting to become garments.
struct ImageImportQueue: Identifiable {
    let id = UUID()
    var images: [UIImage]
}

struct WardrobeFiltersSheet: View {
    @Bindable var viewModel: WardrobeViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Solo favoritas", isOn: $viewModel.onlyFavorites)
                    Toggle("Solo disponibles", isOn: $viewModel.onlyAvailable)
                }
                Section("Colores") {
                    MultiColorPickerGrid(selection: $viewModel.selectedColors)
                        .padding(.vertical, 6)
                }
                Section("Estilos") {
                    ChipSelector(items: FashionStyle.allCases, selection: $viewModel.selectedStyles) { $0.displayName }
                        .padding(.vertical, 4)
                }
                Section("Temporada") {
                    ChipSelector(items: Season.allCases, selection: $viewModel.selectedSeasons) { $0.displayName }
                        .padding(.vertical, 4)
                }
                Section("Etiqueta") {
                    TextField("Ej. trabajo", text: $viewModel.tagFilter)
                        .textInputAutocapitalization(.never)
                }
            }
            .navigationTitle("Filtros")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Restablecer") { viewModel.resetFilters() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}
