import SwiftUI
import SwiftData

struct ReferenceDetailView: View {
    @Bindable var reference: InspirationReference
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query private var looks: [Look]
    @State private var showingDeleteConfirmation = false
    @State private var showingRecreate = false
    @State private var showingCompare = false

    private var linkedLooks: [Look] {
        looks.filter { reference.linkedLookIDs.contains($0.id) || $0.referenceIDs.contains(reference.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if reference.imageFileName != nil {
                    StoredImageView(fileName: reference.imageFileName, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(maxHeight: 420)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 6) {
                    TextField("Título", text: $reference.title)
                        .font(Theme.title(.title2))
                    if let style = reference.style {
                        Text(style.displayName).foregroundStyle(Theme.textSecondary)
                    }
                    if !reference.colors.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(reference.colors) { color in
                                HStack(spacing: 3) {
                                    ColorDot(color: color, size: 14)
                                    Text(color.displayName).font(.caption)
                                }
                            }
                        }
                    }
                }

                if let url = reference.url {
                    HStack(spacing: 10) {
                        Button {
                            openURL(url)
                        } label: {
                            Label(PinterestSearchService.isPinterestURL(url) ? "Abrir en Pinterest" : "Abrir enlace", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                                .padding(14)
                                .background(Theme.roseSoft, in: Circle())
                        }
                        .accessibilityLabel("Compartir enlace")
                    }
                } else if let image = reference.imageFileName, let url = Optional(ImageStorageService.shared.url(for: image)) {
                    ShareLink(item: url) {
                        Label("Compartir imagen", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                HStack(spacing: 10) {
                    Button {
                        showingRecreate = true
                    } label: {
                        Label("Recrea este look", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                    Button {
                        showingCompare = true
                    } label: {
                        Label("Comparar", systemImage: "rectangle.split.2x1")
                    }
                    .buttonStyle(SecondaryButtonStyle(fullWidth: true))
                }

                Toggle("Favorita", isOn: $reference.isFavorite)
                    .padding(.horizontal, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Notas").font(.headline)
                    TextField("Notas", text: $reference.notes, axis: .vertical)
                        .lineLimit(2...6)
                        .padding(10)
                        .background(Theme.cream, in: RoundedRectangle(cornerRadius: Theme.smallCornerRadius))
                }

                if !linkedLooks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Looks relacionados").font(.headline)
                        ForEach(linkedLooks) { look in
                            NavigationLink(value: look) {
                                Label(look.name, systemImage: "square.grid.2x2")
                            }
                        }
                    }
                }

                if let query = reference.searchQuery {
                    PinterestQueryList(title: "Búsqueda guardada", queries: [PinterestQuery(text: query, language: .spanish)], allowsSaving: false)
                }

                Text("Guardada el \(reference.createdAt.formatted(date: .long, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(Theme.padding)
        }
        .looksyBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .accessibilityLabel("Eliminar referencia")
            }
        }
        .onDisappear { try? context.save() }
        .sheet(isPresented: $showingRecreate) {
            NavigationStack { RecreateLookView(reference: reference) }
        }
        .sheet(isPresented: $showingCompare) {
            NavigationStack { CompareView(lookID: linkedLooks.first?.id, reference: reference) }
        }
        .confirmationDialog("¿Eliminar esta referencia?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                let target = reference
                let file = reference.imageFileName
                dismiss()
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(450))
                    ImageStorageService.shared.delete(file)
                    for look in looks where look.referenceIDs.contains(target.id) {
                        look.referenceIDs.removeAll { $0 == target.id }
                    }
                    context.delete(target)
                    try? context.save()
                }
            }
            Button("Cancelar", role: .cancel) {}
        }
    }
}
