//
//  FitzgeraldKey.swift
//  Let's Talk
//
//  Defines Parts of Speech and AAC color schemes (Fitzgerald variants).
//  Includes a high-contrast option and helpers to fetch hex/Color values.
//

import SwiftUI

enum PartOfSpeech: String, CaseIterable, Codable, Identifiable {
    case pronoun
    case verb
    case noun
    case adjective
    case adverb
    case preposition
    case conjunction
    case interjection
    case determiner
    case question
    case negation
    case social

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pronoun:      return String(localized: "Pronoun")
        case .verb:         return String(localized: "Verb")
        case .noun:         return String(localized: "Noun")
        case .adjective:    return String(localized: "Adjective")
        case .adverb:       return String(localized: "Adverb")
        case .preposition:  return String(localized: "Preposition")
        case .conjunction:  return String(localized: "Conjunction")
        case .interjection: return String(localized: "Interjection")
        case .determiner:   return String(localized: "Determiner/Article")
        case .question:     return String(localized: "Question")
        case .negation:     return String(localized: "Negation")
        case .social:       return String(localized: "Social")
        }
    }
}

/// AAC color scheme options (extensible).
enum AACColorScheme: String, CaseIterable, Identifiable, Codable {
    case fitzgerald
    case fitzgeraldHighContrast

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fitzgerald:              return String(localized: "Fitzgerald")
        case .fitzgeraldHighContrast:  return String(localized: "Fitzgerald (High Contrast)")
        }
    }
}

/// Provides color mappings for Parts of Speech under different AAC schemes.
enum FitzgeraldKey {

    // Base Fitzgerald palette (hex). Tuned for familiarity.
    private static let fitzgeraldPalette: [PartOfSpeech: String] = [
        .pronoun:      "#FFE066", // yellow
        .verb:         "#2ECC71", // green
        .noun:         "#FF9F1C", // orange
        .adjective:    "#339AF0", // blue
        .adverb:       "#74C0FC", // light blue
        .preposition:  "#9B59B6", // purple
        .conjunction:  "#95A5A6", // gray
        .interjection: "#7F8C8D", // dark gray
        .determiner:   "#F6C177", // tan/gold
        .question:     "#F06595", // pink
        .negation:     "#E74C3C", // red
        .social:       "#F06595"  // pink
    ]

    // High-contrast variant (aims for higher luminance contrast).
    private static let fitzgeraldHighContrastPalette: [PartOfSpeech: String] = [
        .pronoun:      "#FFD000", // stronger yellow
        .verb:         "#0F9D58", // deeper green
        .noun:         "#E65100", // deeper orange
        .adjective:    "#1565C0", // deeper blue
        .adverb:       "#0288D1", // deeper light-blue
        .preposition:  "#6A1B9A", // deeper purple
        .conjunction:  "#455A64", // darker gray-blue
        .interjection: "#263238", // very dark gray
        .determiner:   "#B26A00", // deeper amber
        .question:     "#C2185B", // deeper pink
        .negation:     "#C62828", // deeper red
        .social:       "#AD1457"  // deeper pink/magenta
    ]

    /// Resolve the palette for a given scheme.
    private static func palette(for scheme: AACColorScheme) -> [PartOfSpeech: String] {
        switch scheme {
        case .fitzgerald:             return fitzgeraldPalette
        case .fitzgeraldHighContrast: return fitzgeraldHighContrastPalette
        }
    }

    /// Return the hex color for a POS under a given scheme.
    static func colorHex(for pos: PartOfSpeech, scheme: AACColorScheme = .fitzgerald) -> String {
        palette(for: scheme)[pos] ?? "#FFE066"
    }

    /// Return a SwiftUI Color for a POS under a given scheme, with optional alpha.
    static func color(for pos: PartOfSpeech, scheme: AACColorScheme = .fitzgerald, alpha: Double = 1.0) -> Color {
        (Color(hex: colorHex(for: pos, scheme: scheme)) ?? .yellow).opacity(alpha)
    }
}

// MARK: - Color hex helpers

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") { hexSanitized.removeFirst() }
        guard hexSanitized.count == 6,
              let rgb = Int(hexSanitized, radix: 16) else {
            return nil
        }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}
