//
//  Favorite.swift
//  LetsTalk
//
//  Created by Eric Carroll on 12/15/24.
//

import Foundation
import SwiftUI
import SwiftData

@Model
final class Favorite: Identifiable {
    @Attribute(.unique) var text: String
    @Attribute var order: Int
    
    init(text: String, order: Int) {
        self.text = text
        self.order = order
    }
}
