import Testing
import SwiftData
import Foundation
import UIKit

@testable import LetsTalk

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
        let (rootID, tileID, savedRelative) = try await MainActor.run { () -> (UUID, UUID, String?) in
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
            return (root.id, tile.id, relative)
        }

        // Sanity check file exists before export
        if let relative = savedRelative {
            let fileURL = TileImagesStorage.imagesDirectory.appendingPathComponent(relative)
            #expect(FileManager.default.fileExists(atPath: fileURL.path))
        }

        // Export
        let exportURL = try await ExportService.exportJSON(
            modelContext: context,
            pages: try context.fetch(FetchDescriptor<Page>()),
            tiles: try context.fetch(FetchDescriptor<Tile>()),
            favorites: try context.fetch(FetchDescriptor<Favorite>())
        )

        // Wipe store
        try await MainActor.run {
            for page in (try? context.fetch(FetchDescriptor<Page>())) ?? [] { context.delete(page) }
            for tile in (try? context.fetch(FetchDescriptor<Tile>())) ?? [] { context.delete(tile) }
            for fav in (try? context.fetch(FetchDescriptor<Favorite>())) ?? [] { context.delete(fav) }
            try? context.save()
        }

        // Import
        try await ExportService.import(modelContext: context, from: exportURL)

        // Validate
        let pagesAfter = try context.fetch(FetchDescriptor<Page>())
        let tilesAfter = try context.fetch(FetchDescriptor<Tile>())

        #expect(pagesAfter.count == 1)
        #expect(tilesAfter.count == 1)

        let rootAfter = pagesAfter.first(where: { $0.isRoot })
        let tileAfter = tilesAfter.first

        #expect(rootAfter?.id == rootID)
        #expect(tileAfter?.id == tileID)
        #expect(tileAfter?.page?.id == rootAfter?.id)

        // Image restored to disk with a non-empty relative path
        let relative = tileAfter?.imageRelativePath
        #expect(relative != nil && !(relative?.isEmpty ?? true))
        if let relative {
            let fileURL = TileImagesStorage.imagesDirectory.appendingPathComponent(relative)
            #expect(FileManager.default.fileExists(atPath: fileURL.path))
            // Also validate it decodes to a UIImage
            #expect(UIImage(contentsOfFile: fileURL.path) != nil)
        }
    }
}
