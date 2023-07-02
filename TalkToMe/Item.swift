//
//  Item.swift
//  TalkToMe
//
//  Created by Eric Carroll on 7/2/23.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
