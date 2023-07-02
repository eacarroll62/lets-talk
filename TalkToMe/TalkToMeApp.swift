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

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: Item.self)
    }
}
