//
//  TalkToMeApp.swift
//  TalkToMe
//
//  Created by Eric Carroll on 7/2/23.
//

import SwiftUI
import SwiftData

@main
struct TalkToMeApp: App {
    @State private var speaker: Speaker = Speaker()
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(speaker)
                .modelContainer(for: [Favorite.self, Page.self, Tile.self])
        }
    }
}

