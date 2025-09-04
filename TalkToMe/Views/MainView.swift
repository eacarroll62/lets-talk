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
                    seedIfNeeded()
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
            HStack(spacing: 16) {
                MessageView(favorites: favorites)
                    .frame(maxWidth: .infinity)
                    .containerStyle()

                // Pass a Binding<Page> to TileGridView, derived from the optional @State
                TileGridView(currentPage: Binding<Page>(
                    get: { self.currentPage! },
                    set: { newValue in
                        self.currentPage = newValue
                    }
                ))
                .frame(maxWidth: .infinity)
            }
        } else {
            ProgressView(String(localized: "Loading board…"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func deleteFavorite(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(favorites[index])
        }
    }

    private func moveFavorite(from source: IndexSet, to destination: Int) {
        var reorderedFavorites = favorites.sorted(by: { $0.order < $1.order })
        reorderedFavorites.move(fromOffsets: source, toOffset: destination)

        for (index, favorite) in reorderedFavorites.enumerated() {
            favorite.order = index
        }

        try? modelContext.save()
    }

    private func rootPage() -> Page? {
        pages.first(where: { $0.isRoot }) ?? pages.first
    }

    // Seed a simple root page with core words on first launch
    private func seedIfNeeded() {
        guard pages.isEmpty else { return }

        let root = Page(name: "Home", order: 0, isRoot: true)
        modelContext.insert(root)

        let coreWords: [(String, String?, String?)] = [
            ("I", "person.fill", "#F9D65C"),
            ("want", "hand.point.right.fill", "#AEDFF7"),
            ("more", "plus.circle.fill", "#B5E48C"),
            ("help", "hand.raised.fill", "#FFD6E0"),
            ("yes", "checkmark.circle.fill", "#ACE7FF"),
            ("no", "xmark.circle.fill", "#FFADAD"),
            ("you", "person.2.fill", "#E4C1F9"),
            ("like", "hand.thumbsup.fill", "#C7F9CC"),
        ]

        for (idx, item) in coreWords.enumerated() {
            let tile = Tile(text: item.0, symbolName: item.1, colorHex: item.2, order: idx, isCore: true, page: root)
            modelContext.insert(tile)
            root.tiles.append(tile)
        }

        do {
            try modelContext.save()
        } catch {
            print("Seeding error: \(error)")
        }
    }
}

#Preview {
    MainView()
        .modelContainer(for: [Favorite.self, Page.self, Tile.self], inMemory: true)
        .environment(Speaker())
}
