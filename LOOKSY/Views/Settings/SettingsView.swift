import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(PreferencesService.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section("Perfil") {
                TextField("Tu nombre (para el saludo)", text: $preferences.preferences.displayName)
                    .textContentType(.givenName)
                NavigationLink {
                    PreferencesView()
                } label: {
                    Label("Preferencias de estilo", systemImage: "heart.text.square")
                }
            }

            Section("Datos") {
                NavigationLink {
                    StorageView()
                } label: {
                    Label("Almacenamiento", systemImage: "internaldrive")
                }
            }

            Section {
                Label("Tus fotos y datos se guardan solo en este iPhone.", systemImage: "lock.shield")
                Label("LOOKSY no usa cuentas, servidores ni servicios de IA en la nube.", systemImage: "icloud.slash")
                Label("Pinterest solo se abre cuando tú lo pides; no se envían tus fotos.", systemImage: "link")
            } header: {
                Text("Privacidad")
            }
            .font(.footnote)

            Section("Acerca de") {
                LabeledContent("Versión", value: Bundle.main.appVersionDescription)
                LabeledContent("Hecho con", value: "SwiftUI · SwiftData · Vision")
            }
        }
        .scrollContentBackground(.hidden)
        .looksyBackground()
        .navigationTitle("Ajustes")
    }
}

extension Bundle {
    var appVersionDescription: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

struct PreferencesView: View {
    @Environment(PreferencesService.self) private var service
    @Query(sort: \Garment.name) private var garments: [Garment]

    var body: some View {
        @Bindable var service = service
        Form {
            Section("Estilos favoritos") {
                ChipSelector(items: FashionStyle.allCases, selection: $service.preferences.favoriteStyles) { $0.displayName }
                    .padding(.vertical, 4)
            }
            Section("Colores favoritos") {
                MultiColorPickerGrid(selection: $service.preferences.favoriteColors, excluded: Set(service.preferences.avoidedColors))
                    .padding(.vertical, 6)
            }
            Section {
                MultiColorPickerGrid(selection: $service.preferences.avoidedColors, excluded: Set(service.preferences.favoriteColors))
                    .padding(.vertical, 6)
            } header: {
                Text("Colores que evito")
            } footer: {
                Text("El estilista no propondrá prendas con estos colores salvo que las pidas explícitamente.")
            }
            Section("Calzado preferido") {
                ChipSelector(items: GarmentCategory.categories(in: .shoes), selection: $service.preferences.preferredShoes) { $0.displayName }
                    .padding(.vertical, 4)
                Toggle("Evitar tacones", isOn: $service.preferences.avoidHeels)
            }
            Section {
                Stepper(value: $service.preferences.comfortLevel, in: 1...5) {
                    LabeledContent("Comodidad", value: comfortLabel(service.preferences.comfortLevel))
                }
                Stepper(value: $service.preferences.usualFormality, in: Formality.range) {
                    LabeledContent("Formalidad habitual", value: Formality.label(for: service.preferences.usualFormality))
                }
            } header: {
                Text("Comodidad y formalidad")
            }
            Section("Siluetas que prefieres") {
                ChipSelector(items: GarmentSilhouette.allCases.filter { $0 != .noDefinida }, selection: $service.preferences.silhouettePreferences) { $0.displayName }
                    .padding(.vertical, 4)
            }
            Section("Ocasiones frecuentes") {
                ChipSelector(items: Occasion.allCases, selection: $service.preferences.frequentOccasions) { $0.displayName }
                    .padding(.vertical, 4)
            }
            Section("Temporadas") {
                ChipSelector(items: Season.allCases, selection: $service.preferences.seasons) { $0.displayName }
                    .padding(.vertical, 4)
            }
            Section {
                if garments.isEmpty {
                    Text("Agrega prendas a tu armario para elegir favoritas.")
                        .foregroundStyle(Theme.textSecondary)
                } else {
                    ForEach(garments) { garment in
                        let isFavorite = service.preferences.favoriteGarmentIDs.contains(garment.id)
                        Button {
                            if isFavorite {
                                service.preferences.favoriteGarmentIDs.removeAll { $0 == garment.id }
                            } else {
                                service.preferences.favoriteGarmentIDs.append(garment.id)
                            }
                        } label: {
                            HStack {
                                StoredImageView(fileName: garment.thumbnailFileName, contentMode: .fit, placeholderSymbol: garment.category.symbolName)
                                    .frame(width: 40, height: 40)
                                Text(garment.name).foregroundStyle(Theme.text)
                                Spacer()
                                Image(systemName: isFavorite ? "star.fill" : "star")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .accessibilityAddTraits(isFavorite ? .isSelected : [])
                    }
                }
            } header: {
                Text("Prendas favoritas para combinar")
            } footer: {
                Text("LOOKSY no aplica restricciones por talla ni tipo de cuerpo.")
            }
        }
        .scrollContentBackground(.hidden)
        .looksyBackground()
        .navigationTitle("Preferencias")
    }

    private func comfortLabel(_ level: Int) -> String {
        switch level {
        case 1: return "Máxima"
        case 2: return "Alta"
        case 3: return "Equilibrada"
        case 4: return "Flexible"
        default: return "Prioriza el look"
        }
    }
}

struct StorageView: View {
    @Environment(\.modelContext) private var context
    @Query private var garments: [Garment]
    @Query private var looks: [Look]
    @Query private var references: [InspirationReference]
    @State private var totalBytes: Int64 = 0
    @State private var fileCount = 0
    @State private var message: String?

    var body: some View {
        Form {
            Section("Uso") {
                LabeledContent("Prendas", value: "\(garments.count)")
                LabeledContent("Looks", value: "\(looks.count)")
                LabeledContent("Referencias", value: "\(references.count)")
                LabeledContent("Archivos de imagen", value: "\(fileCount)")
                LabeledContent("Espacio de imágenes", value: ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file))
            }
            Section {
                Button("Limpiar imágenes huérfanas") {
                    let removed = ImageStorageService.shared.removeOrphans(referenced: referencedFiles())
                    message = removed == 0 ? "No había imágenes huérfanas." : "Se eliminaron \(removed) archivo(s) sin uso."
                    refresh()
                }
                Button("Vaciar caché de imágenes") {
                    ImageStorageService.shared.clearCache()
                    message = "Caché vaciada."
                }
            } footer: {
                Text("Las imágenes huérfanas son archivos que ya no pertenecen a ninguna prenda, look o referencia.")
            }
            if let message {
                Section { Text(message).font(.footnote) }
            }
        }
        .scrollContentBackground(.hidden)
        .looksyBackground()
        .navigationTitle("Almacenamiento")
        .onAppear(perform: refresh)
    }

    private func referencedFiles() -> Set<String> {
        var names = Set<String>()
        garments.forEach { names.formUnion($0.allImageFileNames) }
        looks.compactMap(\.exportedImageFileName).forEach { names.insert($0) }
        references.compactMap(\.imageFileName).forEach { names.insert($0) }
        return names
    }

    private func refresh() {
        totalBytes = ImageStorageService.shared.totalSize()
        fileCount = ImageStorageService.shared.allFileNames().count
    }
}
