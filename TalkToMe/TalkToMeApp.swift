//
//  LetsTalkApp.swift
//  Let's Talk
//
//  Created by Eric Carroll on 7/2/23.
//

import SwiftUI
import SwiftData

@main
struct LetsTalkApp: App {
    @State private var speaker: Speaker = Speaker()

    // First-run onboarding flag
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some Scene {
        WindowGroup {
            MainView()
                .environment(speaker)
                .modelContainer(for: [Favorite.self, Page.self, Tile.self, Recent.self, QuickPhrase.self])
                .fullScreenCover(isPresented: .constant(!hasCompletedOnboarding)) {
                    OnboardingView()
                }
        }
    }
}

