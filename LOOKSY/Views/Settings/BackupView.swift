import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// File wrapper used by the system exporter.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw BackupService.BackupError.unreadable
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct BackupView: View {
    @Environment(\.modelContext) private var context
    @Environment(PreferencesService.self) private var preferences
    @Query private var garments: [Garment]
    @Query private var looks: [Look]

    @State private var document: BackupDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var pendingImport: Data?
    @State private var isWorking = false
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Label("El respaldo es un archivo .json con tus prendas, fotos, looks, collages, colecciones, calendario, referencias y preferencias.", systemImage: "doc.zipper")
                    .font(.footnote)
                Label("Guárdalo en Archivos, en tu computadora o en la nube que prefieras. LOOKSY no lo sube a ningún lado.", systemImage: "lock")
                    .font(.footnote)
            }

            Section("Exportar") {
                Button {
                    export()
                } label: {
                    Label("Crear respaldo (\(garments.count) prendas, \(looks.count) looks)", systemImage: "square.and.arrow.up")
                }
                .disabled(isWorking)
            }

            Section {
                Button {
                    showingImporter = true
                } label: {
                    Label("Restaurar desde archivo", systemImage: "square.and.arrow.down")
                }
                .disabled(isWorking)
            } header: {
                Text("Restaurar")
            } footer: {
                Text("Se verifica la integridad de cada foto. Los registros con IDs repetidos se omiten.")
            }

            if isWorking {
                Section { ProgressView("Procesando…") }
            }
            if let resultMessage {
                Section("Resultado") { Text(resultMessage).font(.footnote) }
            }
            if let errorMessage {
                Section { Text(errorMessage).foregroundStyle(Theme.danger).font(.footnote) }
            }
        }
        .scrollContentBackground(.hidden)
        .looksyBackground()
        .navigationTitle("Respaldo")
        .fileExporter(
            isPresented: $showingExporter,
            document: document,
            contentType: .json,
            defaultFilename: BackupService.defaultFileName()
        ) { result in
            switch result {
            case .success:
                resultMessage = "Respaldo guardado correctamente."
            case .failure(let error):
                errorMessage = "No se pudo guardar el respaldo: \(error.localizedDescription)"
            }
            document = nil
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                readImport(url)
            case .failure(let error):
                errorMessage = "No se pudo abrir el archivo: \(error.localizedDescription)"
            }
        }
        .confirmationDialog(
            "¿Cómo quieres restaurar?",
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            titleVisibility: .visible
        ) {
            Button("Combinar con mis datos") { runImport(.merge) }
            Button("Reemplazar todo", role: .destructive) { runImport(.replace) }
            Button("Cancelar", role: .cancel) { pendingImport = nil }
        } message: {
            Text("Combinar conserva tus datos actuales y añade lo nuevo. Reemplazar borra lo actual de este iPhone y restaura el respaldo.")
        }
    }

    private func export() {
        errorMessage = nil
        resultMessage = nil
        isWorking = true
        do {
            let data = try BackupService(context: context, preferences: preferences).exportData()
            document = BackupDocument(data: data)
            showingExporter = true
        } catch {
            errorMessage = "No se pudo crear el respaldo."
        }
        isWorking = false
    }

    private func readImport(_ url: URL) {
        errorMessage = nil
        resultMessage = nil
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            _ = try BackupService.decode(data)
            pendingImport = data
        } catch let error as BackupService.BackupError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = BackupService.BackupError.unreadable.localizedDescription
        }
    }

    private func runImport(_ mode: BackupService.ImportMode) {
        guard let data = pendingImport else { return }
        pendingImport = nil
        isWorking = true
        do {
            let report = try BackupService(context: context, preferences: preferences).importData(data, mode: mode)
            resultMessage = "Restauración completada.\n" + report.summary
        } catch {
            errorMessage = error.localizedDescription
        }
        isWorking = false
    }
}
