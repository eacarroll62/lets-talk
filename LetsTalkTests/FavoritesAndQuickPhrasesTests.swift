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

    @Test("Favorite.text uniqueness enforced")
    func favoritesUniqueness() async throws {
        // SwiftData uniqueness constraints are only available on iOS 17+
        guard #available(iOS 17, *) else {
            return
        }

        let container = try makeInMemoryContainer()
        let context = ModelContext(container)

        try await MainActor.run {
            context.insert(Favorite(text: "Hello", order: 0))
            try context.save()
        }

        await #expect(throws: Error.self) {
            try await MainActor.run {
                context.insert(Favorite(text: "Hello", order: 1))
                try context.save()
            }
        }
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
