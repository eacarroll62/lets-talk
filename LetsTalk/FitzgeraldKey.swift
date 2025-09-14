//
//  FitzgeraldKey.swift
//  Let's Talk
//
//  Defines Parts of Speech and AAC color palettes (Fitzgerald and Modified).
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

enum AACColorScheme: String, CaseIterable, Identifiable, Codable {
    case fitzgerald
    case modifiedFitzgerald

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fitzgerald:
            return String(localized: "Fitzgerald")
        case .modifiedFitzgerald:
            return String(localized: "Modified Fitzgerald")
        }
    }
}

enum FitzgeraldKey {
    // Default Fitzgerald palette (hex). Adjust as needed.
    private static let fitzgerald: [PartOfSpeech: String] = [
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

    // A slightly different set that some teams prefer (tweak freely).
    private static let modified: [PartOfSpeech: String] = [
        .pronoun:      "#FFD166", // warm yellow
        .verb:         "#06D6A0", // teal-green
        .noun:         "#F4A261", // softer orange
        .adjective:    "#118AB2", // deeper blue
        .adverb:       "#73C2FB", // sky blue
        .preposition:  "#9D4EDD", // violet
        .conjunction:  "#A0AEC0", // cool gray
        .interjection: "#718096", // darker cool gray
        .determiner:   "#E9C46A", // goldenrod
        .question:     "#EF476F", // raspberry
        .negation:     "#E63946", // red
        .social:       "#EF476F"  // raspberry
    ]

    private static func palette(for scheme: AACColorScheme) -> [PartOfSpeech: String] {
        switch scheme {
        case .fitzgerald:         return fitzgerald
        case .modifiedFitzgerald: return modified
        }
    }

    static func colorHex(for pos: PartOfSpeech, scheme: AACColorScheme = .fitzgerald) -> String {
        palette(for: scheme)[pos] ?? "#FFE066"
    }

    static func color(for pos: PartOfSpeech, scheme: AACColorScheme = .fitzgerald, alpha: Double = 1.0) -> Color {
        Color(hex: colorHex(for: pos, scheme: scheme), alpha: alpha)
    }
}
