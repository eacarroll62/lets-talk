//
//  Enums.swift
//  LetsTalk
//
//  Created by Eric Carroll on 7/2/23.
//

import SwiftUI

enum Language: String, CaseIterable, Identifiable, CustomStringConvertible {
    case african, american, australian, british, irish, indian
  
    var id: Self { self }

    var description: String {
        switch self {
            case .american:
              return "en-EN"
            case .british:
              return "en-GB"
            case .australian:
              return "en-AU"
            case .irish:
              return "en-IE"
            case .african:
              return "en-ZA"
            case .indian:
                return "en-IN"
        }
    }
}

enum ControlsStyle: String, CaseIterable {
    case compact = "Compact"
    case large = "Large"
}

// New: Selection behavior for tile/quick phrase taps
enum SelectionBehavior: String, CaseIterable, Identifiable {
    case speak
    case addToMessage
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .speak:        return String(localized: "Speak")
        case .addToMessage: return String(localized: "Add")
        case .both:         return String(localized: "Both")
        }
    }
}

// New: Scanning mode
enum ScanningMode: String, CaseIterable, Identifiable {
    case step
    case auto

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .step: return String(localized: "Step")
        case .auto: return String(localized: "Auto")
        }
    }
}

