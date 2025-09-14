import Testing
import SwiftData
import Foundation

@testable import TalkToMe

@Suite("Favorites Uniqueness & QuickPhrase Ordering")
struct FavoritesAndQuickPhrasesTests {

    private func makeInMemoryContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Favorite.self, Page.self, Tile.self, Recent.self, QuickPhrase.self,
            configurations: config
        )
    }

    @Test("Favorite.text uniqueness: only one item with the same text exists after save")
    func favoritesUniqueness() async throws {
        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        try await MainActor.run {
            context.insert(Favorite(text: "Hello", order: 0))
            try context.save()
        }

        // Attempt to insert duplicate text; some stores may throw, some may upsert/replace.
        await MainActor.run {
            context.insert(Favorite(text: "Hello", order: 1))
            try? context.save()
        }

        // Assert that at most one Favorite with text == "Hello" exists
        let predicate = #Predicate<Favorite> { $0.text == "Hello" }
        let desc = FetchDescriptor<Favorite>(predicate: predicate)
        let matches = try await MainActor.run { try context.fetch(desc) }
        #expect(matches.count == 1, "There should be exactly one Favorite with text 'Hello'")
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
        #expect(fetched.enumerated().allSatisfy { idx, qp in qp.order == idx })
    }
}
