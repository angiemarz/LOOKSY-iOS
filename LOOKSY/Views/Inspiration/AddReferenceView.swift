import SwiftUI
import SwiftData
import PhotosUI

/// Saves a reference: Pinterest link and/or a screenshot from Photos.
struct AddReferenceView: View {
    var openRecreation = false
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var urlText = ""
    @State private var notes = ""
    @State private var style: FashionStyle?
    @State private var colors: [FashionColor] = []
    @State private var pickerItem: PhotosPickerItem?
    @State private var image: UIImage?
    @State private var analysis: ColorAnalysis?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var savedReference: InspirationReference?

    private var parsedURL: URL? { PinterestSearchService.normalizedURL(from: urlText) }

    private var urlWarning: String? {
        guard !urlText.trimmed.isEmpty else { return nil }
        guard let url = parsedURL else { return "El enlace no es válido." }
        return PinterestSearchService.isPinterestURL(url) ? nil : "No parece un enlace de Pinterest; se guardará igualmente."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 260)
                                .frame(maxWidth: .infinity)
                        } else {
                            Label("Importar captura o foto", systemImage: "photo.on.rectangle.angled")
                        }
                    }
                    if image != nil {
                        Button("Quitar imagen", role: .destructive) {
                            image = nil
                            analysis = nil
                            pickerItem = nil
                        }
                    }
                } header: {
                    Text("Imagen de referencia")
                } footer: {
                    Text("La imagen se guarda solo en tu iPhone.")
                }

                Section {
                    TextField("https://pin.it/… o pinterest.com/pin/…", text: $urlText)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if let urlWarning {
                        Text(urlWarning).font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                } header: {
                    Text("Enlace de Pinterest (opcional)")
                } footer: {
                    Text("LOOKSY no descarga ni analiza el contenido de los enlaces; solo los guarda para abrirlos después.")
                }

                Section("Título") {
                    TextField("Ej. Look de café en tonos beige", text: $title)
                }

                Section {
                    if isAnalyzing {
                        ProgressView("Analizando colores de la imagen…")
                    } else if let analysis {
                        Text("Detectados en la imagen: " + analysis.entries.map { "\($0.color.displayName) \(Int(($0.share * 100).rounded()))%" }.joined(separator: ", "))
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    MultiColorPickerGrid(selection: $colors)
                        .padding(.vertical, 6)
                } header: {
                    Text("Paleta")
                } footer: {
                    Text("Los colores detectados son una aproximación de toda la imagen; ajústalos si es necesario.")
                }

                Section("Estilo") {
                    SingleChipSelector(items: FashionStyle.allCases, selection: $style) { $0.displayName }
                        .padding(.vertical, 4)
                }

                Section("Notas") {
                    TextField("¿Qué te gusta de este look?", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(Theme.danger) }
                }
            }
            .scrollContentBackground(.hidden)
            .looksyBackground()
            .navigationTitle(openRecreation ? "Recrea este look" : "Nueva referencia")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(openRecreation ? "Siguiente" : "Guardar", action: save)
                        .disabled(image == nil && parsedURL == nil && title.trimmed.isEmpty)
                }
            }
            .onChange(of: pickerItem) { _, item in
                Task { await load(item) }
            }
            .navigationDestination(item: $savedReference) { reference in
                RecreateLookView(reference: reference)
            }
        }
    }

    private func load(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        guard let data = try? await item.loadTransferable(type: Data.self), let loaded = UIImage(data: data) else {
            errorMessage = "No se pudo cargar la imagen."
            return
        }
        image = loaded.normalizedOrientation().resized(maxDimension: 1600)
        isAnalyzing = true
        let analyzed = await Task.detached(priority: .userInitiated) {
            ImageProcessingService.analyzeColors(of: loaded)
        }.value
        isAnalyzing = false
        analysis = analyzed
        if colors.isEmpty, let analyzed {
            colors = analyzed.entries.filter { $0.share >= 0.08 }.prefix(4).map(\.color)
        }
    }

    private func save() {
        let reference = InspirationReference(
            title: title.trimmed.isEmpty ? defaultTitle : title.trimmed,
            urlString: parsedURL?.absoluteString
        )
        reference.colors = colors
        reference.style = style
        reference.notes = notes
        reference.formality = style?.typicalFormality ?? 2
        if let image {
            do {
                let files = try ImageStorageService.shared.savePhoto(image, id: reference.id)
                reference.imageFileName = files.original
                ImageStorageService.shared.delete(files.thumbnail)
            } catch {
                errorMessage = "No se pudo guardar la imagen."
                return
            }
        }
        context.insert(reference)
        try? context.save()
        if openRecreation {
            savedReference = reference
        } else {
            dismiss()
        }
    }

    private var defaultTitle: String {
        if let style { return "Inspiración \(style.displayName.lowercased())" }
        if parsedURL != nil { return "Pin guardado" }
        return "Referencia \(Date().formatted(date: .abbreviated, time: .omitted))"
    }
}
