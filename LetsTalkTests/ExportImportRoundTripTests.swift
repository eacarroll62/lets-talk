//
//  Test.swift
//  LetsTalk
//
//  Created by Eric Carroll on 9/7/25.
//

import Testing
import SwiftData
import Foundation

@testable import LetsTalk // Replace with your app’s module name

@Suite("Export/Import Round-Trip")
struct ExportImportRoundTripTests {

    // Build an in-memory SwiftData container for tests
    private func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Favorite.self, Page.self, Tile.self, Recent.self, QuickPhrase.self,
            configurations: config
        )
    }

    // Fetch helpers
    private func fetchPages(_ context: ModelContext) throws -> [Page] {
        try context.fetch(FetchDescriptor<Page>())
    }
    private func fetchTiles(_ context: ModelContext) throws -> [Tile] {
        try context.fetch(FetchDescriptor<Tile>())
    }
    private func fetchFavorites(_ context: ModelContext) throws -> [Favorite] {
        try context.fetch(FetchDescriptor<Favorite>())
    }

    @Test("Round-trip export/import without images")
    func exportImportRoundTrip() async throws {
        // Create in-memory container and context
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        // Seed a small graph on the main actor (SwiftData mutations)
        let (root, child, t1, t2) = try await MainActor.run { () -> (Page, Page, Tile, Tile) in
            let root = Page(name: "Home", order: 0, isRoot: true)
            let child = Page(name: "Food", order: 1, isRoot: false)
            child.parent = root
            root.children = [child]

            let t1 = Tile(text: "Hello", symbolName: "hand.wave.fill", colorHex: "#FFD6E0", order: 0, isCore: false, destinationPage: nil, page: root)
            let t2 = Tile(text: "Fruit", symbolName: "applelogo", colorHex: "#FFCC99", order: 1, isCore: false, destinationPage: child, page: root)

            context.insert(root)
            context.insert(child)
            context.insert(t1)
            context.insert(t2)

            // Link tiles to page arrays
            root.tiles.append(contentsOf: [t1, t2])

            // Favorites
            let fav = Favorite(text: "Hello", order: 0)
            context.insert(fav)

            try context.save()
            return (root, child, t1, t2)
        }

        // Verify initial state
        do {
            let pages = try fetchPages(context)
            let tiles = try fetchTiles(context)
            let favs = try fetchFavorites(context)
            #expect(pages.count == 2)
            #expect(tiles.count == 2)
            #expect(favs.count == 1)
            #expect(pages.contains(where: { $0.isRoot && $0.name == "Home" }))
            #expect(pages.contains(where: { !$0.isRoot && $0.name == "Food" }))
            #expect(tiles.contains(where: { $0.text == "Fruit" && $0.destinationPage?.name == "Food" }))
        }

        // Export off the main actor via async API
        let exportURL = try await ExportService.exportJSON(
            modelContext: context,
            pages: try fetchPages(context),
            tiles: try fetchTiles(context),
            favorites: try fetchFavorites(context)
        )

        // Wipe the store (delete everything) on the main actor
        try await MainActor.run {
            for page in (try? context.fetch(FetchDescriptor<Page>())) ?? [] { context.delete(page) }
            for tile in (try? context.fetch(FetchDescriptor<Tile>())) ?? [] { context.delete(tile) }
            for fav in (try? context.fetch(FetchDescriptor<Favorite>())) ?? [] { context.delete(fav) }
            try? context.save()
        }

        // Sanity check wiped
        #expect((try fetchPages(context)).isEmpty)
        #expect((try fetchTiles(context)).isEmpty)
        #expect((try fetchFavorites(context)).isEmpty)

        // Import asynchronously
        try await ExportService.import(modelContext: context, from: exportURL)

        // Validate round-trip
        let pagesAfter = try fetchPages(context)
        let tilesAfter = try fetchTiles(context)
        let favsAfter = try fetchFavorites(context)

        #expect(pagesAfter.count == 2)
        #expect(tilesAfter.count == 2)
        #expect(favsAfter.count == 1)

        // Root restored
        let rootAfter = pagesAfter.first(where: { $0.isRoot })
        #expect(rootAfter?.name == "Home")

        // Child restored under root
        let foodAfter = pagesAfter.first(where: { $0.name == "Food" })
        #expect(foodAfter != nil)
        #expect(foodAfter?.parent?.id == rootAfter?.id)

        // Destination/page relationships preserved
        let fruitTileAfter = tilesAfter.first(where: { $0.text == "Fruit" })
        #expect(fruitTileAfter?.page?.id == rootAfter?.id)
        #expect(fruitTileAfter?.destinationPage?.id == foodAfter?.id)

        // Favorite restored
        #expect(favsAfter.first?.text == "Hello")
    }
}
