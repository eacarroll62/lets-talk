import Testing
import SwiftData
import Foundation

@testable import LetsTalk

@Suite("Favorites Uniqueness & QuickPhrase Ordering")
struct FavoritesAndQuickPhrasesTests {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Favorite.self, Page.self, Tile.self, Recent.self, QuickPhrase.self,
            configurations: config
        )
    }

    // Disk-backed container to ensure uniqueness constraints are enforced
    private func makeDiskBackedContainer() throws -> ModelContainer {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftData-Uniqueness-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storeURL = tempDir.appendingPathComponent("Store.sqlite")
        let config = ModelConfiguration(url: storeURL)
        return try ModelContainer(
            for: Favorite.self, Page.self, Tile.self, Recent.self, QuickPhrase.self,
            configurations: config
        )
    }

    @Test("Favorite.text uniqueness enforced")
    func favoritesUniqueness() async throws {
        // SwiftData uniqueness constraints are available on iOS 17+ / macOS 14+
        guard #available(iOS 17, macOS 14, *) else {
            return
        }

        // Use disk-backed store because in-memory stores do not enforce uniqueness constraints.
        let container = try makeDiskBackedContainer()
        let context = ModelContext(container)

        try await MainActor.run {
            context.insert(Favorite(text: "Hello", order: 0))
            try context.save()
        }

        // Try inserting a duplicate and saving. Some configurations may throw, others may ignore/upsert.
        var didThrow = false
        do {
            try await MainActor.run {
                context.insert(Favorite(text: "Hello", order: 1))
                try context.save()
            }
        } catch {
            didThrow = true
        }

        // Regardless of throw behavior, assert that there is only one Favorite with text == "Hello".
        let duplicates: [Favorite] = try await MainActor.run {
            let predicate = #Predicate<Favorite> { $0.text == "Hello" }
            let descriptor = FetchDescriptor<Favorite>(predicate: predicate)
            return try context.fetch(descriptor)
        }
        #expect(duplicates.count == 1, "There must only be a single Favorite with the same text, even if save didn’t throw. Got \(duplicates.count).")

        // Optionally, ensure at least one enforcement mechanism happened.
        #expect(didThrow || duplicates.count == 1)
    }

    @Test("QuickPhrase ordering is stable and contiguous after reordering")
    func quickPhraseOrdering() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        try await MainActor.run {
            let qp1 = QuickPhrase(text: "One", order: 0)
            let qp2 = QuickPhrase(text: "Two", order: 1)
            let qp3 = QuickPhrase(text: "Three", order: 2)
            context.insert(qp1); context.insert(qp2); context.insert(qp3)
            try context.save()

            // Simulate moving "Three" to the front
            qp3.order = 0
            qp1.order = 1
            qp2.order = 2
            try context.save()
        }

        let fetched: [QuickPhrase] = try await MainActor.run {
            try context.fetch(FetchDescriptor<QuickPhrase>(sortBy: [SortDescriptor(\.order)]))
        }

        #expect(fetched.map { $0.text } == ["Three", "One", "Two"])
        // Ensure orders are contiguous 0...n-1
        #expect(fetched.enumerated().allSatisfy { idx, qp in qp.order == idx })
    }
}
