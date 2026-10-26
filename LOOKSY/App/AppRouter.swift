import SwiftUI
import Observation

enum AppTab: Hashable {
    case home
    case wardrobe
    case stylist
    case inspiration
    case looks
}

/// Shared navigation state so screens can jump between tabs
/// (e.g. "Combinar esta prenda" from Inicio opens Crear outfit).
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    /// Garment the stylist should include in the next request.
    var stylistSeedGarmentID: UUID?
    /// Text to prefill in the stylist.
    var stylistSeedText: String?

    func openStylist(with garmentID: UUID? = nil, text: String? = nil) {
        stylistSeedGarmentID = garmentID
        stylistSeedText = text
        selectedTab = .stylist
    }
}
