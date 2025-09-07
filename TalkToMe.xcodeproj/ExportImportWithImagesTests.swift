import Testing
import SwiftData
import Foundation
import UIKit

@testable import TalkToMe

@Suite("Export/Import With Images")
struct ExportImportWithImagesTests {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Favorite.self, Page.self, Tile.self, Recent.self, QuickPhrase.self,
            configurations: config
        )
    }

    // 1x1 transparent PNG
    private func tinyPNGData() -> Data {
        // Base64 for a 1x1 transparent PNG
        let b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII="
        return Data(base64Encoded: b64)!
    }

    @Test("Round-trip with a tile image")
    func exportImportWithImage() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        // Seed data with an image-backed tile
        try await MainActor.run {
            let root = Page(name: "Home", order: 0, isRoot: true)
            let data = tinyPNGData()
            let relative = TileImagesStorage.savePNG(data)

            let tile = Tile(
                text: "Picture",
                symbolName: nil,
                colorHex: "#FFD6E0",
                order: 0,
                isCore: false,
                pronunciationOverride: nil,
                destinationPage: nil,
                page: root,
                imageRelativePath: relative,
                size: 1.0,
                languageCode: "en"
            )
            root.tiles.append(tile)

            context.insert(root)
            context.insert(tile)
            try context.save()

            // Sanity check file exists before export
            if let relative {
                let fileURL = TileImagesStorage.imagesDirectory.appendingPathComponent(relative)
                #expect(FileManager.default.fileExists(atPath: fileURL.path))
            }
        }

        // Export
        let exportURL = try await ExportService.exportJSON(
            modelContext: context,
            pages: try context.fetch(FetchDescriptor<Page>()),
            tiles: try context.fetch(FetchDescriptor<Tile>()),
            favorites: try context.fetch(FetchDescriptor<Favorite>())
        )

        // EXTRA: Validate the export bundle has imageBase64 for our tile
        let bundleData = try Data(contentsOf: exportURL)
        let bundle = try JSONDecoder().decode(ExportBundle.self, from: bundleData)
        let exportedPicture = bundle.tiles.first(where: { $0.text == "Picture" })
        #expect(exportedPicture != nil, "Export should include the 'Picture' tile")
        #expect(exportedPicture?.imageBase64 != nil && !(exportedPicture?.imageBase64?.isEmpty ?? true),
                "Export should embed imageBase64 for the 'Picture' tile")

        // Wipe store
        try await MainActor.run {
            for page in (try? context.fetch(FetchDescriptor<Page>())) ?? [] { context.delete(page) }
            for tile in (try? context.fetch(FetchDescriptor<Tile>())) ?? [] { context.delete(tile) }
            for fav in (try? context.fetch(FetchDescriptor<Favorite>())) ?? [] { context.delete(fav) }
            try? context.save()
        }

        // Import
        try await ExportService.import(modelContext: context, from: exportURL)

        // Validate: find the "Picture" tile and ensure it has an image on disk and belongs to a root page
        let tilesAfter: [Tile] = try await MainActor.run { try context.fetch(FetchDescriptor<Tile>()) }
        let pagesAfter: [Page] = try await MainActor.run { try context.fetch(FetchDescriptor<Page>()) }

        #expect(!tilesAfter.isEmpty)
        #expect(!pagesAfter.isEmpty)

        let pictureTile = tilesAfter.first(where: { $0.text == "Picture" })
        #expect(pictureTile != nil, "Imported tile named 'Picture' should exist")

        // Relationship: the tile should belong to some page; at least one page should be root
        #expect(pictureTile?.page != nil)
        let anyRoot = pagesAfter.first(where: { $0.isRoot })
        #expect(anyRoot != nil, "There should be a root page after import")

        // Image restored to disk with a non-empty relative path
        let relative = pictureTile?.imageRelativePath
        #expect(relative != nil && !(relative?.isEmpty ?? true))
        if let relative {
            let fileURL = TileImagesStorage.imagesDirectory.appendingPathComponent(relative)
            #expect(FileManager.default.fileExists(atPath: fileURL.path))
            #expect(UIImage(contentsOfFile: fileURL.path) != nil)
        }
    }
}
