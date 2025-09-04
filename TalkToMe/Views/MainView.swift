//
//  ContentView.swift
//  Let's Talk
//
//  Created by Eric Carroll on 7/2/23.
//

import SwiftUI
import SwiftData
import AVFoundation
import Observation

struct MainView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Speaker.self) private var speaker
    @State private var showSettings: Bool = false
    @State private var showPagesManager: Bool = false
    @State private var searchText: String = ""
    @State private var selectedFavorite: Favorite?

    @State private var currentPage: Page?

    @Query(sort: \Favorite.order) var favorites: [Favorite]
    @Query(sort: \Page.order) private var pages: [Page]
    @Query(sort: \Recent.timestamp, order: .reverse) private var recents: [Recent]
    @Query(sort: \QuickPhrase.order) private var quickPhrases: [QuickPhrase]

    @AppStorage("language") private var languageSetting: String = "en-US"

    var body: some View {
        NavigationStack {
            content
                .safeAreaPadding()
                .navigationTitle(String(localized: "Let's Talk"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        HStack {
                            Button {
                                showPagesManager.toggle()
                            } label: {
                                Image(systemName: "folder")
                            }
                            .accessibilityLabel(Text(String(localized: "Manage Pages")))
                            EditButton()
                        }
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(action: { showSettings.toggle() }) {
                            Image(systemName: "line.horizontal.3")
                        }
                        .accessibilityLabel(Text(String(localized: "Open Settings")))
                    }
                }
                .sheet(isPresented: $showSettings) { SettingsView() }
                .sheet(isPresented: $showPagesManager) { PagesManagerView(rootPage: rootPage()) }
                .onAppear {
                    // Seed as needed
                    SeedingService.seedAllIfNeeded(modelContext: modelContext, pages: pages)
                    if currentPage == nil {
                        currentPage = pages.first(where: { $0.isRoot }) ?? pages.first
                    }
                    // Train predictor from existing data
                    let langCode = languageSetting.hasPrefix("es") ? "es" : "en"
                    let tileTexts = pages.flatMap { $0.tiles.map { $0.text } }
                    let favTexts = favorites.map { $0.text }
                    PredictionService.shared.learn(from: tileTexts + favTexts, languageCode: langCode)

                    DispatchQueue.main.async {
                        speaker.speak(String(localized: "Welcome to the Let's Talk app!"))
                    }
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let _ = currentPage {
            VStack(spacing: 12) {
                MessageView(favorites: favorites)
                    .containerStyle()

                if !quickPhrases.isEmpty {
                    QuickPhrasesRow(phrases: quickPhrases.map { $0.text }) { phrase in
                        insertIntoMessage(phrase)
                    }
                    .containerStyle()
                }

                if !recents.isEmpty {
                    RecentsRow(items: recents) { text in
                        insertIntoMessage(text)
                    }
                    .containerStyle()
                }

                if let currentPage {
                    BreadcrumbBar(current: currentPage) { page in
                        self.currentPage = page
                    }
                    .containerStyle()
                }

                TileGridView(currentPage: Binding<Page>(
                    get: { self.currentPage! },
                    set: { newValue in
                        self.currentPage = newValue
                    }
                ))
            }
        } else {
            ProgressView(String(localized: "Loading board…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func insertIntoMessage(_ text: String) {
        speaker.text = speaker.text.isEmpty ? text : speaker.text + " " + text
    }

    private func rootPage() -> Page? {
        pages.first(where: { $0.isRoot }) ?? pages.first
    }
}

#Preview {
    MainView()
        .modelContainer(for: [Favorite.self, Page.self, Tile.self, Recent.self, QuickPhrase.self], inMemory: true)
        .environment(Speaker())
}
