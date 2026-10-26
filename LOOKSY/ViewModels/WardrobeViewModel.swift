import Foundation
import Observation

enum WardrobeSort: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case name
    case category
    case leastWorn

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newest: return "Más recientes"
        case .oldest: return "Más antiguas"
        case .name: return "Nombre"
        case .category: return "Categoría"
        case .leastWorn: return "Menos usadas"
        }
    }
}

/// Filtering and sorting state of "Mi armario".
@Observable
final class WardrobeViewModel {
    var searchText = ""
    var selectedCategories: [GarmentCategory] = []
    var selectedColors: [FashionColor] = []
    var selectedStyles: [FashionStyle] = []
    var selectedSeasons: [Season] = []
    var onlyFavorites = false
    var onlyAvailable = false
    var tagFilter = ""
    var sort: WardrobeSort = .newest

    var activeFilterCount: Int {
        selectedColors.count + selectedStyles.count + selectedSeasons.count
            + (onlyFavorites ? 1 : 0) + (onlyAvailable ? 1 : 0) + (tagFilter.trimmed.isEmpty ? 0 : 1)
    }

    func resetFilters() {
        selectedCategories = []
        selectedColors = []
        selectedStyles = []
        selectedSeasons = []
        onlyFavorites = false
        onlyAvailable = false
        tagFilter = ""
    }

    func apply(to garments: [Garment]) -> [Garment] {
        let query = searchText.normalizedForSearch.trimmed
        let tag = tagFilter.normalizedForSearch.trimmed
        let filtered = garments.filter { garment in
            if !selectedCategories.isEmpty, !selectedCategories.contains(garment.category) { return false }
            if !selectedColors.isEmpty {
                let colors = Set([garment.primaryColor] + garment.secondaryColors)
                if colors.isDisjoint(with: selectedColors) { return false }
            }
            if !selectedStyles.isEmpty, Set(garment.styles).isDisjoint(with: selectedStyles) { return false }
            if !selectedSeasons.isEmpty, !garment.seasons.isEmpty, Set(garment.seasons).isDisjoint(with: selectedSeasons) { return false }
            if onlyFavorites, !garment.isFavorite { return false }
            if onlyAvailable, !garment.isAvailable { return false }
            if !tag.isEmpty, !garment.tags.contains(where: { $0.normalizedForSearch.contains(tag) }) { return false }
            if !query.isEmpty {
                let haystack = [
                    garment.name,
                    garment.category.displayName,
                    garment.primaryColor.displayName,
                    garment.tags.joined(separator: " "),
                    garment.notes
                ].joined(separator: " ").normalizedForSearch
                if !haystack.contains(query) { return false }
            }
            return true
        }
        switch sort {
        case .newest:
            return filtered.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            return filtered.sorted { $0.createdAt < $1.createdAt }
        case .name:
            return filtered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .category:
            return filtered.sorted {
                if $0.category == $1.category { return $0.createdAt > $1.createdAt }
                return (GarmentCategory.allCases.firstIndex(of: $0.category) ?? 0) < (GarmentCategory.allCases.firstIndex(of: $1.category) ?? 0)
            }
        case .leastWorn:
            return filtered.sorted {
                if $0.wearCount == $1.wearCount { return ($0.lastWornAt ?? .distantPast) < ($1.lastWornAt ?? .distantPast) }
                return $0.wearCount < $1.wearCount
            }
        }
    }
}
