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
    @AppStorage("editLocked") private var editLocked: Bool = true
    @AppStorage("userPreferredName") private var userPreferredName: String = ""

    // Visibility toggles
    @AppStorage("showSentenceBar") private var showSentenceBar: Bool = true
    @AppStorage("showQuickPhrases") private var showQuickPhrases: Bool = true
    @AppStorage("showRecents") private var showRecents: Bool = true

    var body: some View {
        NavigationStack {
            Group {
                if isSearching {
                    searchResultsView
                } else {
                    content
                }
            }
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
                        .disabled(editLocked)

                        EditButton()
                            .disabled(editLocked)
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
            .task {
                // Pick a sensible default voice for the current language if one isn't set
                if UserDefaults.standard.string(forKey: "identifier")?.isEmpty ?? true {
                    if let best = VoicePicker.bestVoiceIdentifier(for: languageSetting) {
                        await MainActor.run {
                            UserDefaults.standard.set(best, forKey: "identifier")
                        }
                    }
                }

                // Seed initial data if needed
                SeedingService.seedAllIfNeeded(modelContext: modelContext, pages: pages)

                // Ensure we have a current page
                if currentPage == nil {
                    await MainActor.run {
                        currentPage = pages.first(where: { $0.isRoot }) ?? pages.first
                    }
                }

                // Train prediction service
                let langCode = languageSetting.hasPrefix("es") ? "es" : "en"
                let tileTexts = pages.flatMap { $0.tiles.map { $0.text } }
                let favTexts = favorites.map { $0.text }
                PredictionService.shared.learn(from: tileTexts + favTexts, languageCode: langCode)

                // Speak greeting on the main actor
                let trimmed = userPreferredName.trimmingCharacters(in: .whitespacesAndNewlines)
                let greeting: String
                if trimmed.isEmpty {
                    greeting = String(localized: "Let's Talk!")
                } else {
                    greeting = String(format: String(localized: "Let's Talk, %@"), trimmed)
                }
                await MainActor.run {
                    speaker.speak(greeting)
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .automatic), prompt: Text(String(localized: "Search tiles and pages")))
            .searchSuggestions {
                let tiles = filteredTiles().prefix(6)
                let pgs = filteredPages().prefix(4)

                if !tiles.isEmpty {
                    Section(String(localized: "Tiles")) {
                        ForEach(tiles, id: \.id) { tile in
                            Button {
                                navigate(to: tile)
                            } label: {
                                HStack {
                                    if let symbol = tile.symbolName, !symbol.isEmpty {
                                        Image(systemName: symbol)
                                    }
                                    Text(tile.text)
                                    Spacer()
                                    if let page = tile.page {
                                        Text(page.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                if !pgs.isEmpty {
                    Section(String(localized: "Pages")) {
                        ForEach(pgs, id: \.id) { page in
                            Button {
                                navigate(to: page)
                            } label: {
                                HStack {
                                    Image(systemName: page.isRoot ? "house.fill" : "folder")
                                    Text(page.name)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @ViewBuilder
    private var searchResultsView: some View {
        let tiles = filteredTiles()
        let pgs = filteredPages()

        List {
            if !tiles.isEmpty {
                Section(String(localized: "Tiles")) {
                    ForEach(tiles, id: \.id) { tile in
                        Button {
                            navigate(to: tile)
                        } label: {
                            HStack {
                                if let symbol = tile.symbolName, !symbol.isEmpty {
                                    Image(systemName: symbol)
                                }
                                VStack(alignment: .leading) {
                                    Text(tile.text)
                                    if let page = tile.page {
                                        Text(page.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if !pgs.isEmpty {
                Section(String(localized: "Pages")) {
                    ForEach(pgs, id: \.id) { page in
                        Button {
                            navigate(to: page)
                        } label: {
                            HStack {
                                Image(systemName: page.isRoot ? "house.fill" : "folder")
                                Text(page.name)
                            }
                        }
                    }
                }
            }

            if tiles.isEmpty && pgs.isEmpty {
                Text(String(localized: "No results"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Search helpers

    private func filteredTiles() -> [Tile] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        let allTiles = pages.flatMap { $0.tiles }
        return allTiles.filter { $0.text.localizedCaseInsensitiveContains(needle) }
            .sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
    }

    private func filteredPages() -> [Page] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        return pages.filter { $0.name.localizedCaseInsensitiveContains(needle) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func navigate(to tile: Tile) {
        // If tile opens a destination page (folder), go there. Otherwise go to the tile's page.
        if let dest = tile.destinationPage {
            if dest.parent == nil, let srcPage = tile.page {
                dest.parent = srcPage
                try? modelContext.save()
            }
            currentPage = dest
        } else if let page = tile.page {
            currentPage = page
        }
        // Clear search after navigation
        searchText = ""
    }

    private func navigate(to page: Page) {
        currentPage = page
        searchText = ""
    }

    // MARK: - Main content

    @ViewBuilder
    private var content: some View {
        if let _ = currentPage {
            VStack(spacing: 12) {
                if showSentenceBar {
                    MessageView(favorites: favorites)
                        .containerStyle()
                }

                if showQuickPhrases && !quickPhrases.isEmpty {
                    QuickPhrasesRow(phrases: quickPhrases.map { $0.text }) { phrase in
                        insertIntoMessage(phrase)
                    }
                    .containerStyle()
                }

                if showRecents && !recents.isEmpty {
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
