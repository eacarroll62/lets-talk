//
//  ExportService.swift
//  Let's Talk
//
//  Created by Eric Carroll on 9/4/25.
//

import Foundation
import SwiftData
import UIKit

struct ExportBundle: Codable {
    struct ExportPage: Codable {
        var id: UUID
        var name: String
        var order: Int
        var isRoot: Bool
        var parentID: UUID?
        var childrenIDs: [UUID]
        var tileIDs: [UUID]
    }

    struct ExportTile: Codable {
        var id: UUID
        var text: String
        var symbolName: String?
        var colorHex: String?
        var order: Int
        var isCore: Bool
        var pronunciationOverride: String?
        var destinationPageID: UUID?
        var pageID: UUID?
        var size: Double?
        var languageCode: String?
        // image embedded as base64 (PNG)
        var imageBase64: String?
        // New: POS raw value
        var partOfSpeechRaw: String?
    }

    struct ExportFavorite: Codable {
        var text: String
        var order: Int
    }

    var pages: [ExportPage]
    var tiles: [ExportTile]
    var favorites: [ExportFavorite]
    var version: Int = 2
}

enum ExportService {

    // Snapshot types to safely move work off the main actor
    fileprivate struct PageSnapshot: Sendable {
        var id: UUID
        var name: String
        var order: Int
        var isRoot: Bool
        var parentID: UUID?
        var childrenIDs: [UUID]
        var tileIDs: [UUID]
    }

    fileprivate struct TileSnapshot: Sendable {
        var id: UUID
        var text: String
        var symbolName: String?
        var colorHex: String?
        var order: Int
        var isCore: Bool
        var pronunciationOverride: String?
        var destinationPageID: UUID?
        var pageID: UUID?
        var size: Double?
        var languageCode: String?
        // Prefer URL, but also keep the relative path for fallback
        var imageURL: URL?
        var imageRelativePath: String?
        var partOfSpeechRaw: String?
    }

    fileprivate struct FavoriteSnapshot: Sendable {
        var text: String
        var order: Int
    }

    static func exportJSON(modelContext: ModelContext,
                           pages: [Page],
                           tiles: [Tile],
                           favorites: [Favorite]) async throws -> URL {
        // Take a snapshot of data we need on the main actor (SwiftData models should be used on main)
        let pageSnapshots: [PageSnapshot] = await makePageSnapshots(from: pages)
        let tileSnapshots: [TileSnapshot] = await makeTileSnapshots(from: tiles)
        let favoriteSnapshots: [FavoriteSnapshot] = await makeFavoriteSnapshots(from: favorites)

        // Perform file IO and JSON encoding off the main actor
        let url: URL = try await Task.detached(priority: .userInitiated) { () throws -> URL in
            let exportPages: [ExportBundle.ExportPage] = pageSnapshots.map { ps in
                ExportBundle.ExportPage(
                    id: ps.id,
                    name: ps.name,
                    order: ps.order,
                    isRoot: ps.isRoot,
                    parentID: ps.parentID,
                    childrenIDs: ps.childrenIDs,
                    tileIDs: ps.tileIDs
                )
            }

            let exportTiles: [ExportBundle.ExportTile] = tileSnapshots.map { ts in
                let imageBase64: String? = {
                    // Try URL first
                    if let url = ts.imageURL, let data = try? Data(contentsOf: url) {
                        return data.base64EncodedString()
                    }
                    // Fallback to relative path if present
                    if let rel = ts.imageRelativePath {
                        let url = TileImagesStorage.imagesDirectory.appendingPathComponent(rel)
                        if let data = try? Data(contentsOf: url) {
                            return data.base64EncodedString()
                        }
                    }
                    return nil
                }()
                return ExportBundle.ExportTile(
                    id: ts.id,
                    text: ts.text,
                    symbolName: ts.symbolName,
                    colorHex: ts.colorHex,
                    order: ts.order,
                    isCore: ts.isCore,
                    pronunciationOverride: ts.pronunciationOverride,
                    destinationPageID: ts.destinationPageID,
                    pageID: ts.pageID,
                    size: ts.size,
                    languageCode: ts.languageCode,
                    imageBase64: imageBase64,
                    partOfSpeechRaw: ts.partOfSpeechRaw
                )
            }

            let exportFavorites: [ExportBundle.ExportFavorite] = favoriteSnapshots.map { fs in
                ExportBundle.ExportFavorite(text: fs.text, order: fs.order)
            }

            let bundle = ExportBundle(pages: exportPages, tiles: exportTiles, favorites: exportFavorites)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(bundle)

            let url = FileManager.default.temporaryDirectory.appendingPathComponent("LetsTalkExport.json")
            try data.write(to: url, options: .atomic)
            return url
        }.value

        return url
    }

    static func `import`(modelContext: ModelContext, from url: URL) async throws {
        // Read and decode JSON off the main actor
        let bundle: ExportBundle = try await Task.detached(priority: .userInitiated) {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ExportBundle.self, from: data)
        }.value

        // Apply to SwiftData models on the main actor without capturing modelContext in a @Sendable closure
        try await apply(bundle: bundle, into: modelContext)
    }

    @MainActor
    private static func apply(bundle: ExportBundle, into modelContext: ModelContext) throws {
        // Build lookup maps
        var pageMap: [UUID: Page] = [:]
        var tileMap: [UUID: Tile] = [:]

        // Helper to fetch an existing Page by id
        func existingPage(with id: UUID) -> Page? {
            let predicate = #Predicate<Page> { $0.id == id }
            var fd = FetchDescriptor<Page>(predicate: predicate)
            fd.fetchLimit = 1
            return try? modelContext.fetch(fd).first
        }

        // Helper to fetch an existing Tile by id
        func existingTile(with id: UUID) -> Tile? {
            let predicate = #Predicate<Tile> { $0.id == id }
            var fd = FetchDescriptor<Tile>(predicate: predicate)
            fd.fetchLimit = 1
            return try? modelContext.fetch(fd).first
        }

        // Create or reuse pages (preserve IDs by constructing with id:)
        for ep in bundle.pages {
            if let page = existingPage(with: ep.id) {
                // Reuse and update basic fields
                page.name = ep.name
                page.order = ep.order
                page.isRoot = ep.isRoot
                pageMap[ep.id] = page
            } else {
                let page = Page(
                    id: ep.id,
                    name: ep.name,
                    order: ep.order,
                    isRoot: ep.isRoot
                )
                modelContext.insert(page)
                pageMap[ep.id] = page
            }
        }

        // Resolve parent relationships (set one side only)
        for ep in bundle.pages {
            guard let page = pageMap[ep.id] else { continue }
            if let pid = ep.parentID {
                page.parent = pageMap[pid]
            } else {
                page.parent = nil
            }
        }

        // Create or reuse tiles (restore images first), preserve IDs by constructing with id:
        for et in bundle.tiles {
            var relative: String? = nil
            if let b64 = et.imageBase64, let data = Data(base64Encoded: b64) {
                relative = TileImagesStorage.savePNG(data)
            }

            if let tile = existingTile(with: et.id) {
                // Reuse and update fields
                tile.text = et.text
                tile.symbolName = et.symbolName
                tile.colorHex = et.colorHex
                tile.order = et.order
                tile.isCore = et.isCore
                tile.pronunciationOverride = et.pronunciationOverride
                tile.size = et.size
                tile.languageCode = et.languageCode
                tile.partOfSpeechRaw = et.partOfSpeechRaw
                if relative != nil {
                    // Replace image path only if we restored an image
                    tile.imageRelativePath = relative
                }
                tileMap[et.id] = tile
            } else {
                let tile = Tile(
                    id: et.id,
                    text: et.text,
                    symbolName: et.symbolName,
                    colorHex: et.colorHex,
                    order: et.order,
                    isCore: et.isCore,
                    pronunciationOverride: et.pronunciationOverride,
                    destinationPage: nil,
                    page: nil,
                    imageRelativePath: relative,
                    size: et.size,
                    languageCode: et.languageCode,
                    partOfSpeechRaw: et.partOfSpeechRaw
                )
                modelContext.insert(tile)
                tileMap[et.id] = tile
            }
        }

        // Resolve tile relationships (set both sides where appropriate)
        for et in bundle.tiles {
            guard let tile = tileMap[et.id] else { continue }
            if let destID = et.destinationPageID {
                tile.destinationPage = pageMap[destID]
            } else {
                tile.destinationPage = nil
            }
            if let pageID = et.pageID, let page = pageMap[pageID] {
                tile.page = page
            } else {
                tile.page = nil
            }
        }

        // Populate children and tiles arrays on pages using exported IDs
        for ep in bundle.pages {
            guard let page = pageMap[ep.id] else { continue }
            page.children = ep.childrenIDs.compactMap { pageMap[$0] }
            page.tiles = ep.tileIDs.compactMap { tileMap[$0] }
        }

        // Favorites
        for ef in bundle.favorites {
            // Avoid violating Favorite.text uniqueness on import; add only if not present
            let predicate = #Predicate<Favorite> { $0.text == ef.text }
            var fd = FetchDescriptor<Favorite>(predicate: predicate)
            fd.fetchLimit = 1
            if (try? modelContext.fetch(fd).first) == nil {
                modelContext.insert(Favorite(text: ef.text, order: ef.order))
            }
        }

        try modelContext.save()
    }
}

// MARK: - Main-actor snapshot helpers
@MainActor
private func makePageSnapshots(from pages: [Page]) -> [ExportService.PageSnapshot] {
    pages.map { p in
        ExportService.PageSnapshot(
            id: p.id,
            name: p.name,
            order: p.order,
            isRoot: p.isRoot,
            parentID: p.parent?.id,
            childrenIDs: p.children.map { $0.id },
            tileIDs: p.tiles.map { $0.id }
        )
    }
}

@MainActor
private func makeTileSnapshots(from tiles: [Tile]) -> [ExportService.TileSnapshot] {
    tiles.map { t in
        ExportService.TileSnapshot(
            id: t.id,
            text: t.text,
            symbolName: t.symbolName,
            colorHex: t.colorHex,
            order: t.order,
            isCore: t.isCore,
            pronunciationOverride: t.pronunciationOverride,
            destinationPageID: t.destinationPage?.id,
            pageID: t.page?.id,
            size: t.size,
            languageCode: t.languageCode,
            imageURL: t.imageURL,
            imageRelativePath: t.imageRelativePath,
            partOfSpeechRaw: t.partOfSpeechRaw
        )
    }
}

@MainActor
private func makeFavoriteSnapshots(from favorites: [Favorite]) -> [ExportService.FavoriteSnapshot] {
    favorites.map { ExportService.FavoriteSnapshot(text: $0.text, order: $0.order) }
}

