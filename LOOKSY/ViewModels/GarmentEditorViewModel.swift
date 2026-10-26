import SwiftUI
import SwiftData
import Observation

/// Editable copy of a garment's attributes.
struct GarmentDraft: Equatable {
    var name = ""
    var category: GarmentCategory = .blusas
    var primaryColor: FashionColor = .negro
    var secondaryColors: [FashionColor] = []
    var detectedColorHex: String?
    var material: GarmentMaterial = .desconocido
    var pattern: GarmentPattern = .liso
    var styles: [FashionStyle] = []
    var silhouette: GarmentSilhouette = .noDefinida
    var seasons: [Season] = []
    var formality = 2
    var occasions: [Occasion] = []
    var tags: [String] = []
    var notes = ""
    var isAvailable = true
    var isFavorite = false

    init() {}

    init(garment: Garment) {
        name = garment.name
        category = garment.category
        primaryColor = garment.primaryColor
        secondaryColors = garment.secondaryColors
        detectedColorHex = garment.detectedColorHex
        material = garment.material
        pattern = garment.pattern
        styles = garment.styles
        silhouette = garment.silhouette
        seasons = garment.seasons
        formality = garment.formality
        occasions = garment.occasions
        tags = garment.tags
        notes = garment.notes
        isAvailable = garment.isAvailable
        isFavorite = garment.isFavorite
    }

    func apply(to garment: Garment) {
        garment.name = name.trimmed.isEmpty ? category.singularName.capitalized : name.trimmed
        garment.category = category
        garment.primaryColor = primaryColor
        garment.secondaryColors = secondaryColors.filter { $0 != primaryColor }
        garment.detectedColorHex = detectedColorHex
        garment.material = material
        garment.pattern = pattern
        garment.styles = styles
        garment.silhouette = silhouette
        garment.seasons = seasons
        garment.formality = min(max(formality, Formality.range.lowerBound), Formality.range.upperBound)
        garment.occasions = occasions
        garment.tags = tags
        garment.notes = notes
        garment.isAvailable = isAvailable
        garment.isFavorite = isFavorite
        garment.updatedAt = Date()
    }
}

/// Drives the create/edit garment screen, including the local photo tools.
@MainActor
@Observable
final class GarmentEditorViewModel {
    enum Mode {
        case create
        case edit(Garment)
    }

    let mode: Mode
    var draft: GarmentDraft
    /// Working photo (with background). Nil when editing and unchanged.
    var workingImage: UIImage?
    var cutoutImage: UIImage?
    var useCutout = false
    var photoChanged = false
    var cutoutChanged = false

    var isProcessing = false
    var processingMessage: String?
    var errorMessage: String?
    var colorAnalysis: ColorAnalysis?
    /// True once the user picked a color by hand (analysis won't overwrite it).
    var userPickedColor = false

    init(image: UIImage) {
        mode = .create
        draft = GarmentDraft()
        workingImage = image.normalizedOrientation().resized(maxDimension: ImageStorageService.maxOriginalDimension)
        photoChanged = true
    }

    init(garment: Garment) {
        mode = .edit(garment)
        draft = GarmentDraft(garment: garment)
        useCutout = garment.usesCutout
    }

    var isCreating: Bool {
        if case .create = mode { return true }
        return false
    }

    var title: String {
        isCreating ? "Nueva prenda" : "Editar prenda"
    }

    /// Image currently displayed in the editor.
    var displayedImage: UIImage? {
        if useCutout, let cutoutImage { return cutoutImage }
        return workingImage
    }

    /// Loads the stored photos when editing.
    func loadStoredImages() async {
        guard case .edit(let garment) = mode, workingImage == nil else { return }
        if let name = garment.imageFileName {
            workingImage = await ImageStorageService.shared.loadImage(name)
        }
        if let name = garment.cutoutFileName {
            cutoutImage = await ImageStorageService.shared.loadImage(name)
        }
    }

    // MARK: Photo tools

    func analyzeColors(updateSelection: Bool) async {
        guard let image = displayedImage else { return }
        isProcessing = true
        processingMessage = "Analizando colores…"
        let analysis = await Task.detached(priority: .userInitiated) {
            ImageProcessingService.analyzeColors(of: image)
        }.value
        isProcessing = false
        processingMessage = nil
        colorAnalysis = analysis
        guard let analysis else {
            errorMessage = "No se pudieron detectar los colores. Elige el color manualmente."
            return
        }
        if updateSelection && !userPickedColor, let primary = analysis.primary {
            draft.primaryColor = primary
            draft.secondaryColors = analysis.secondary.filter { $0 != primary }
            draft.detectedColorHex = analysis.primaryHex
        }
    }

    func rotate(clockwise: Bool) {
        guard let image = workingImage else { return }
        workingImage = image.rotated(quarterTurns: clockwise ? 1 : -1)
        photoChanged = true
        if let cutout = cutoutImage {
            cutoutImage = cutout.rotated(quarterTurns: clockwise ? 1 : -1)
            cutoutChanged = true
        }
    }

    func applyCrop(_ normalizedRect: CGRect) {
        guard let image = workingImage else { return }
        workingImage = image.cropped(toNormalizedRect: normalizedRect)
        photoChanged = true
        // A cutout made from the previous framing no longer matches.
        if cutoutImage != nil {
            cutoutImage = nil
            useCutout = false
            cutoutChanged = true
        }
    }

    func removeBackground() async {
        guard let image = workingImage else { return }
        isProcessing = true
        processingMessage = "Separando la prenda del fondo…"
        errorMessage = nil
        do {
            let result = try await ImageProcessingService.removeBackground(from: image)
            cutoutImage = result
            useCutout = true
            cutoutChanged = true
            isProcessing = false
            processingMessage = nil
            await analyzeColors(updateSelection: true)
        } catch {
            isProcessing = false
            processingMessage = nil
            errorMessage = error.localizedDescription
        }
    }

    func autoFrame() async {
        guard let image = workingImage else { return }
        isProcessing = true
        processingMessage = "Mejorando el encuadre…"
        let bounds = await ImageProcessingService.foregroundBounds(in: image)
        isProcessing = false
        processingMessage = nil
        guard let bounds else {
            errorMessage = "No se encontró la prenda para encuadrarla. Usa el recorte manual."
            return
        }
        applyCrop(bounds)
    }

    // MARK: Saving

    @discardableResult
    func save(context: ModelContext) -> Bool {
        errorMessage = nil
        let service = WardrobeService(context: context)
        do {
            switch mode {
            case .create:
                guard let image = workingImage else {
                    errorMessage = "Falta la fotografía de la prenda."
                    return false
                }
                let garment = try service.createGarment(
                    image: image,
                    cutout: useCutout ? cutoutImage : nil,
                    input: .init(name: draft.name, category: draft.category, primaryColor: draft.primaryColor)
                )
                draft.apply(to: garment)
                if let cutoutImage, !useCutout {
                    // Keep the cutout available for later even if not active.
                    garment.cutoutFileName = try ImageStorageService.shared.savePNG(cutoutImage, id: garment.id)
                }
                try context.save()
            case .edit(let garment):
                draft.apply(to: garment)
                if photoChanged, let image = workingImage {
                    try service.replacePhoto(of: garment, with: image)
                }
                if cutoutChanged {
                    if let cutoutImage {
                        try service.setCutout(cutoutImage, for: garment)
                    } else {
                        ImageStorageService.shared.delete(garment.cutoutFileName)
                        garment.cutoutFileName = nil
                    }
                }
                try service.setUsesCutout(useCutout && garment.cutoutFileName != nil, for: garment)
                try context.save()
            }
            return true
        } catch {
            errorMessage = "No se pudo guardar la prenda: \(error.localizedDescription)"
            return false
        }
    }
}
