//
//  Tile.swift
//  TalkToMe
//
//  Created by Eric Carroll on 9/3/25.
//

import Foundation
import SwiftData

@Model
final class Tile: Identifiable {
    var id: UUID
    var text: String
    var symbolName: String?
    var colorHex: String?
    var order: Int
    var isCore: Bool
    var pronunciationOverride: String?

    // Relationships inferred by SwiftData
    var destinationPage: Page?
    var page: Page?

    // New: image storage (relative path inside app documents), per-tile size, and language
    var imageRelativePath: String?
    var size: Double? // 0.5 ... 2.0 (multiplier); nil = default
    var languageCode: String? // e.g., "en", "es"

    // New: Fitzgerald Key POS tag (persisted as raw string for SwiftData)
    var partOfSpeechRaw: String?

    init(
        id: UUID = UUID(),
        text: String,
        symbolName: String? = nil,
        colorHex: String? = nil,
        order: Int,
        isCore: Bool = false,
        pronunciationOverride: String? = nil,
        destinationPage: Page? = nil,
        page: Page? = nil,
        imageRelativePath: String? = nil,
        size: Double? = nil,
        languageCode: String? = nil,
        partOfSpeechRaw: String? = nil
    ) {
        self.id = id
        self.text = text
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.order = order
        self.isCore = isCore
        self.pronunciationOverride = pronunciationOverride
        self.destinationPage = destinationPage
        self.page = page
        self.imageRelativePath = imageRelativePath
        self.size = size
        self.languageCode = languageCode
        self.partOfSpeechRaw = partOfSpeechRaw
    }
}

extension Tile {
    // Resolve an absolute URL from the stored relative path in Documents/TileImages
    var imageURL: URL? {
        guard let relative = imageRelativePath else { return nil }
        return TileImagesStorage.imagesDirectory.appendingPathComponent(relative)
    }

    // Computed POS wrapper
    var partOfSpeech: PartOfSpeech? {
        get {
            guard let raw = partOfSpeechRaw else { return nil }
            return PartOfSpeech(rawValue: raw)
        }
        set {
            partOfSpeechRaw = newValue?.rawValue
        }
    }
}

enum TileImagesStorage {
    static var imagesDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dir = docs.appendingPathComponent("TileImages", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func savePNG(_ data: Data) -> String? {
        let filename = UUID().uuidString + ".png"
        let url = imagesDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
            return filename
        } catch {
            print("Failed to save tile image: \(error)")
            return nil
        }
    }

    static func delete(relativePath: String?) {
        guard let relativePath else { return }
        let url = imagesDirectory.appendingPathComponent(relativePath)
        try? FileManager.default.removeItem(at: url)
    }
}
