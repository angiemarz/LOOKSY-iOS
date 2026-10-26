import Foundation

extension String {
    /// Lowercased, accent-free version used for keyword matching
    /// ("Suéter Rosa" -> "sueter rosa").
    var normalizedForSearch: String {
        folding(options: [.diacriticInsensitive, .caseInsensitive, .widthInsensitive], locale: Locale(identifier: "es_MX"))
            .lowercased()
    }

    /// Words made of letters/numbers after normalization.
    var searchTokens: [String] {
        normalizedForSearch
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
