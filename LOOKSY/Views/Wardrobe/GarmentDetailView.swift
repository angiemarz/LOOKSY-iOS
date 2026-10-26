import SwiftUI
import SwiftData

struct GarmentDetailView: View {
    @Bindable var garment: Garment
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var router
    @Environment(PreferencesService.self) private var preferences
    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false
    @State private var looksUsing: [Look] = []
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                StoredImageView(fileName: garment.collageImageFileName ?? garment.imageFileName, contentMode: .fit, placeholderSymbol: garment.category.symbolName)
                    .frame(maxWidth: .infinity)
                    .frame(height: 360)
                    .padding(16)
                    .background(garment.usesCutout ? Color.white : Theme.cream, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))

                VStack(alignment: .leading, spacing: 6) {
                    Text(garment.name)
                        .font(Theme.title(.title))
                        .foregroundStyle(Theme.text)
                    Text("\(garment.category.displayName) · \(Formality.label(for: garment.formality))")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }

                HStack(spacing: 10) {
                    Button {
                        garment.isFavorite.toggle()
                        try? context.save()
                    } label: {
                        Label(garment.isFavorite ? "Favorita" : "Favorita", systemImage: garment.isFavorite ? "heart.fill" : "heart")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .accessibilityLabel(garment.isFavorite ? "Quitar de favoritas" : "Marcar como favorita")

                    Button {
                        garment.isAvailable.toggle()
                        try? context.save()
                    } label: {
                        Label(garment.isAvailable ? "Disponible" : "No disponible", systemImage: garment.isAvailable ? "checkmark.circle" : "clock")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Button {
                    router.openStylist(with: garment.id)
                } label: {
                    Label("Crear outfit con esta prenda", systemImage: "wand.and.stars")
                }
                .buttonStyle(PrimaryButtonStyle())

                attributes
                    .cardStyle()

                if !garment.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Notas").font(.headline)
                        Text(garment.notes).foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardStyle()
                }

                if let errorMessage {
                    InfoBanner(message: errorMessage, systemImage: "exclamationmark.triangle", tint: Theme.danger)
                }
            }
            .padding(Theme.padding)
        }
        .looksyBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        showingEditor = true
                    } label: {
                        Label("Editar", systemImage: "pencil")
                    }
                    Button {
                        do {
                            _ = try WardrobeService(context: context).duplicate(garment)
                        } catch {
                            errorMessage = "No se pudo duplicar la prenda."
                        }
                    } label: {
                        Label("Duplicar", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive) {
                        looksUsing = WardrobeService(context: context).looksUsing(garment)
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .accessibilityLabel("Más opciones")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            NavigationStack {
                GarmentEditorView(viewModel: GarmentEditorViewModel(garment: garment))
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancelar") { showingEditor = false }
                        }
                    }
            }
        }
        .confirmationDialog("¿Eliminar esta prenda?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Eliminar prenda", role: .destructive) {
                // Leave the screen first so no view reads the deleted model.
                let target = garment
                let service = WardrobeService(context: context)
                let prefs = preferences
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    try? service.delete(target, preferences: prefs)
                }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            if looksUsing.isEmpty {
                Text("Se borrarán la prenda y sus fotos de este iPhone. Esta acción no se puede deshacer.")
            } else {
                Text("Esta prenda aparece en \(looksUsing.count) look(s). Los looks se conservarán y mostrarán un aviso de prenda eliminada.")
            }
        }
    }

    private var attributes: some View {
        VStack(alignment: .leading, spacing: 12) {
            attributeRow("Color") {
                HStack(spacing: 6) {
                    ColorDot(color: garment.primaryColor)
                    Text(garment.primaryColor.displayName)
                    ForEach(garment.secondaryColors) { color in
                        ColorDot(color: color, size: 12)
                    }
                }
            }
            if garment.material != .desconocido {
                attributeRow("Material") { Text(garment.material.displayName) }
            }
            attributeRow("Estampado") { Text(garment.pattern.displayName) }
            if garment.silhouette != .noDefinida {
                attributeRow("Silueta") { Text(garment.silhouette.displayName) }
            }
            if !garment.styles.isEmpty {
                attributeRow("Estilo") { Text(garment.styles.map(\.displayName).joined(separator: ", ")) }
            }
            if !garment.occasions.isEmpty {
                attributeRow("Ocasiones") { Text(garment.occasions.map(\.displayName).joined(separator: ", ")) }
            }
            attributeRow("Temporada") {
                Text(garment.seasons.isEmpty ? "Todo el año" : garment.seasons.map(\.displayName).joined(separator: ", "))
            }
            if !garment.tags.isEmpty {
                attributeRow("Etiquetas") { Text(garment.tags.map { "#\($0)" }.joined(separator: " ")) }
            }
            attributeRow("Uso") {
                if let last = garment.lastWornAt {
                    Text("\(garment.wearCount) veces · última \(last.formatted(date: .abbreviated, time: .omitted))")
                } else {
                    Text("Aún sin registrar")
                }
            }
            attributeRow("Agregada") { Text(garment.createdAt.formatted(date: .abbreviated, time: .omitted)) }
        }
        .font(.subheadline)
    }

    private func attributeRow<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 100, alignment: .leading)
            content()
                .foregroundStyle(Theme.text)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}
