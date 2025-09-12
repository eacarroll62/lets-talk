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
    private struct PageSnapshot {
        var id: UUID
        var name: String
        var order: Int
        var isRoot: Bool
        var parentID: UUID?
        var childrenIDs: [UUID]
        var tileIDs: [UUID]
    }

    private struct TileSnapshot {
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
        var imageURL: URL?
        var partOfSpeechRaw: String?
    }

    private struct FavoriteSnapshot {
        var text: String
        var order: Int
    }

    static func exportJSON(modelContext: ModelContext,
                           pages: [Page],
                           tiles: [Tile],
                           favorites: [Favorite]) async throws -> URL {
        // Take a snapshot of data we need on the main actor (SwiftData models should be used on main)
        let pageSnapshots: [PageSnapshot] = await MainActor.run {
            pages.map { p in
                PageSnapshot(
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

        let tileSnapshots: [TileSnapshot] = await MainActor.run {
            tiles.map { t in
                TileSnapshot(
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
                    partOfSpeechRaw: t.partOfSpeechRaw
                )
            }
        }

        let favoriteSnapshots: [FavoriteSnapshot] = await MainActor.run {
            favorites.map { FavoriteSnapshot(text: $0.text, order: $0.order) }
        }

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

            let exportTiles: [ExportBundle.ExportTile] = try tileSnapshots.map { ts in
                let imageBase64: String? = {
                    guard let url = ts.imageURL, let data = try? Data(contentsOf: url) else { return nil }
                    return data.base64EncodedString()
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
            let data = try JSONEncoder().encode(bundle)

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

        // Mutate SwiftData models on the main actor
        try await MainActor.run {
            // Build lookup maps
            var pageMap: [UUID: Page] = [:]
            var tileMap: [UUID: Tile] = [:]

            // Create pages
            for ep in bundle.pages {
                let page = Page(name: ep.name, order: ep.order, isRoot: ep.isRoot)
                page.id = ep.id
                modelContext.insert(page)
                pageMap[ep.id] = page
            }
            // Resolve parent/children relationships
            for ep in bundle.pages {
                guard let page = pageMap[ep.id] else { continue }
                if let pid = ep.parentID { page.parent = pageMap[pid] }
                page.children = ep.childrenIDs.compactMap { pageMap[$0] }
            }

            // Create tiles (save images first)
            for et in bundle.tiles {
                var relative: String? = nil
                if let b64 = et.imageBase64, let data = Data(base64Encoded: b64) {
                    relative = TileImagesStorage.savePNG(data)
                }
                let tile = Tile(
                    id: et.id,
                    text: et.text,
                    symbolName: et.symbolName,
                    colorHex: et.colorHex,
                    order: et.order,
                    isCore: et.isCore,
                    pronunciationOverride: et.pronunciationOverride,
                    destinationPage: nil, // resolve later
                    page: nil,            // resolve later
                    imageRelativePath: relative,
                    size: et.size,
                    languageCode: et.languageCode,
                    partOfSpeechRaw: et.partOfSpeechRaw
                )
                modelContext.insert(tile)
                tileMap[et.id] = tile
            }

            // Resolve tile relationships
            for et in bundle.tiles {
                guard let tile = tileMap[et.id] else { continue }
                if let destID = et.destinationPageID { tile.destinationPage = pageMap[destID] }
                if let pageID = et.pageID {
                    tile.page = pageMap[pageID]
                    pageMap[pageID]?.tiles.append(tile)
                }
            }

            // Favorites
            for ef in bundle.favorites {
                let fav = Favorite(text: ef.text, order: ef.order)
                modelContext.insert(fav)
            }

            try modelContext.save()
        }
    }
}
