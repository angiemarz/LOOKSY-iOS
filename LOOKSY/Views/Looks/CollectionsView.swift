import SwiftUI
import SwiftData

struct CollectionsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LookCollection.createdAt, order: .reverse) private var collections: [LookCollection]
    @Query private var looks: [Look]
    @State private var showingNewCollection = false
    @State private var newName = ""
    @State private var collectionToDelete: LookCollection?

    var body: some View {
        List {
            Section {
                Button {
                    newName = ""
                    showingNewCollection = true
                } label: {
                    Label("Nueva colección", systemImage: "folder.badge.plus")
                }
            }
            if collections.isEmpty {
                Section {
                    Text("Agrupa tus looks por ocasión, temporada o viaje (ej. “Oficina”, “Vacaciones”).")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            ForEach(collections) { collection in
                NavigationLink(value: collection) {
                    HStack(spacing: 12) {
                        let firstLook = looks.first { collection.lookIDs.contains($0.id) }
                        StoredImageView(fileName: firstLook?.exportedImageFileName, contentMode: .fit, placeholderSymbol: "folder")
                            .frame(width: 48, height: 60)
                            .background(Theme.cream, in: RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading) {
                            Text(collection.name).foregroundStyle(Theme.text)
                            Text("\(collection.lookIDs.filter { id in looks.contains { $0.id == id } }.count) looks")
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .swipeActions {
                    Button(role: .destructive) {
                        collectionToDelete = collection
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .alert("Nueva colección", isPresented: $showingNewCollection) {
            TextField("Nombre", text: $newName)
            Button("Crear") {
                let name = newName.trimmed
                guard !name.isEmpty else { return }
                context.insert(LookCollection(name: name))
                try? context.save()
            }
            Button("Cancelar", role: .cancel) {}
        }
        .confirmationDialog(
            "¿Eliminar la colección?",
            isPresented: Binding(get: { collectionToDelete != nil }, set: { if !$0 { collectionToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Eliminar colección", role: .destructive) {
                if let collection = collectionToDelete {
                    context.delete(collection)
                    try? context.save()
                }
                collectionToDelete = nil
            }
        } message: {
            Text("Los looks no se borran.")
        }
    }
}

struct CollectionDetailView: View {
    @Bindable var collection: LookCollection
    @Environment(\.modelContext) private var context
    @Query(sort: \Look.createdAt, order: .reverse) private var looks: [Look]
    @State private var showingPicker = false
    @State private var showingRename = false
    @State private var newName = ""

    private let columns = [GridItem(.adaptive(minimum: 155), spacing: 14)]

    var body: some View {
        let members = looks.filter { collection.lookIDs.contains($0.id) }
        ScrollView {
            if members.isEmpty {
                EmptyStateView(title: "Colección vacía", message: "Añade looks guardados a esta colección.", systemImage: "folder", actionTitle: "Añadir looks") {
                    showingPicker = true
                }
            } else {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(members) { look in
                        NavigationLink(value: look) {
                            LookCard(look: look)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                collection.lookIDs.removeAll { $0 == look.id }
                                try? context.save()
                            } label: {
                                Label("Quitar de la colección", systemImage: "folder.badge.minus")
                            }
                        }
                    }
                }
                .padding(Theme.padding)
            }
        }
        .looksyBackground()
        .navigationTitle(collection.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { showingPicker = true } label: { Label("Añadir looks", systemImage: "plus") }
                    Button {
                        newName = collection.name
                        showingRename = true
                    } label: { Label("Renombrar", systemImage: "pencil") }
                } label: {
                    Image(systemName: "ellipsis.circle").accessibilityLabel("Opciones")
                }
            }
        }
        .sheet(isPresented: $showingPicker) {
            LookPickerSheet(title: "Añadir a \(collection.name)", excludedIDs: Set(collection.lookIDs)) { look in
                if !collection.lookIDs.contains(look.id) {
                    collection.lookIDs.append(look.id)
                    try? context.save()
                }
            }
        }
        .alert("Renombrar colección", isPresented: $showingRename) {
            TextField("Nombre", text: $newName)
            Button("Guardar") {
                if !newName.trimmed.isEmpty {
                    collection.name = newName.trimmed
                    try? context.save()
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }
}

/// Picks a saved look.
struct LookPickerSheet: View {
    var title = "Elegir look"
    var excludedIDs: Set<UUID> = []
    var onPick: (Look) -> Void
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Look.createdAt, order: .reverse) private var looks: [Look]

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                let visible = looks.filter { !excludedIDs.contains($0.id) }
                if visible.isEmpty {
                    EmptyStateView(title: "Sin looks", message: "Guarda looks desde Crear outfit para elegirlos aquí.", systemImage: "square.grid.2x2")
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(visible) { look in
                            Button {
                                onPick(look)
                                dismiss()
                            } label: {
                                LookCard(look: look)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(Theme.padding)
                }
            }
            .looksyBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
}
