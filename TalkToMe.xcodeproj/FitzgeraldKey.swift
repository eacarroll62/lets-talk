//
//  FitzgeraldKey.swift
//  Let's Talk
//
//  Defines Parts of Speech and a Fitzgerald Key color palette mapping.
//  You can tweak the hex values here to match your preferred variant.
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

enum FitzgeraldKey {
    // Default palette (hex) often used in AAC contexts. Adjust as needed.
    // These are chosen for clarity and familiarity; feel free to refine.
    private static let palette: [PartOfSpeech: String] = [
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

    static func colorHex(for pos: PartOfSpeech) -> String {
        palette[pos] ?? "#FFE066"
    }

    static func color(for pos: PartOfSpeech, alpha: Double = 1.0) -> Color {
        Color(hex: colorHex(for: pos)).opacity(alpha)
    }
}

// Local convenience to decode hex into Color
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
