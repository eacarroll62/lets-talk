//
//  Enums.swift
//  TalkToMe
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
