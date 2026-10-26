import Foundation

/// Explainable color-harmony rules for outfits.
enum ColorHarmony {
    struct Evaluation: Equatable {
        var score: Double
        var description: String
        var isClash: Bool { score < 0 }
    }

    /// Circular hue distance in degrees (0...180).
    static func hueDistance(_ a: Double, _ b: Double) -> Double {
        let diff = abs(a - b).truncatingRemainder(dividingBy: 360)
        return diff > 180 ? 360 - diff : diff
    }

    /// Evaluates the main colors of an outfit (one color per main garment).
    static func evaluate(_ colors: [FashionColor]) -> Evaluation {
        let unique = colors.reduce(into: [FashionColor]()) { if !$0.contains($1) { $0.append($1) } }
        let neutrals = unique.filter(\.isNeutral)
        let accents = unique.filter { !$0.isNeutral }
        let neutralNames = neutrals.map(\.adjective).joined(separator: ", ")

        switch accents.count {
        case 0:
            return Evaluation(score: 2, description: neutrals.isEmpty
                ? "Paleta sencilla."
                : "Paleta neutra (\(neutralNames)): combina sin esfuerzo y se ve pulida.")
        case 1:
            let accent = accents[0]
            if accent == .multicolor {
                return Evaluation(score: 1.5, description: "La prenda multicolor es la protagonista y el resto la acompaña en neutros.")
            }
            if neutrals.isEmpty {
                return Evaluation(score: 2.5, description: "Look monocromático en \(accent.adjective): estiliza y se ve intencional.")
            }
            return Evaluation(score: 3, description: "El \(accent.adjective) es el acento y los neutros (\(neutralNames)) lo equilibran.")
        case 2:
            let a = accents[0], b = accents[1]
            if a == .multicolor || b == .multicolor {
                return Evaluation(score: -1, description: "Una prenda multicolor junto a otro color fuerte puede verse cargado.")
            }
            if a.family == b.family {
                return Evaluation(score: 2.5, description: "Tonos de la misma familia (\(a.adjective) y \(b.adjective)): armonía tono sobre tono.")
            }
            guard let ha = a.hue, let hb = b.hue else {
                return Evaluation(score: 0.5, description: "Combinación de \(a.adjective) y \(b.adjective).")
            }
            let distance = hueDistance(ha, hb)
            if distance <= 50 {
                return Evaluation(score: 2, description: "\(a.displayName) y \(b.adjective) son colores análogos: armonía suave.")
            }
            if distance >= 150 {
                return Evaluation(score: 1, description: "\(a.displayName) y \(b.adjective) son complementarios: contraste con intención.")
            }
            if softPair(a, b) {
                return Evaluation(score: 1.5, description: "\(a.displayName) y \(b.adjective) en tonos suaves se ven delicados juntos.")
            }
            return Evaluation(score: -1.5, description: "\(a.displayName) y \(b.adjective) compiten entre sí; un neutro ayudaría.")
        default:
            return Evaluation(score: -2.5, description: "Demasiados colores fuertes juntos (\(accents.map(\.adjective).joined(separator: ", "))).")
        }
    }

    /// Pastel pairs that work even when hues are far apart.
    private static func softPair(_ a: FashionColor, _ b: FashionColor) -> Bool {
        let pastels: Set<FashionColor> = [.rosaPalo, .lila, .celeste, .menta, .crema]
        return pastels.contains(a) && pastels.contains(b)
    }
}
