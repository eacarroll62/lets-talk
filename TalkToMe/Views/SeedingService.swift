// SeedingService.swift

import Foundation
import SwiftData

@MainActor
enum SeedingService {

    static func seedAllIfNeeded(modelContext: ModelContext, pages: [Page]) {
        // If there are no pages, build everything
        if pages.isEmpty {
            seedHome(modelContext: modelContext)
            seedCategories(modelContext: modelContext)
            seedQuickPhrases(modelContext: modelContext)
        } else {
            // If Home exists but categories not linked, add them
            seedCategoriesIfNeeded(modelContext: modelContext, pages: pages)
            // If no quick phrases, seed them
            seedQuickPhrasesIfNeeded(modelContext: modelContext, modelContextPages: pages)
        }
    }

    static func reseedAll(modelContext: ModelContext) {
        // Delete all tile images
        TileImagesStorage.delete(relativePath: nil) // noop if nil; delete folder contents manually below
        // Remove entire images directory
        let dir = TileImagesStorage.imagesDirectory
        try? FileManager.default.removeItem(at: dir)

        // Wipe SwiftData entities
        try? deleteAll(Favorite.self, modelContext: modelContext)
        try? deleteAll(Recent.self, modelContext: modelContext)
        try? deleteAll(QuickPhrase.self, modelContext: modelContext)
        try? deleteAll(Tile.self, modelContext: modelContext)
        try? deleteAll(Page.self, modelContext: modelContext)

        // Recreate starter content
        seedHome(modelContext: modelContext)
        seedCategories(modelContext: modelContext)
        seedQuickPhrases(modelContext: modelContext)

        try? modelContext.save()
    }

    // MARK: - Private helpers

    private static func deleteAll<T>(_ type: T.Type, modelContext: ModelContext) throws where T: PersistentModel {
        let descriptor = FetchDescriptor<T>()
        let items = try modelContext.fetch(descriptor)
        for item in items {
            modelContext.delete(item)
        }
    }

    private static func seedHome(modelContext: ModelContext) {
        let root = Page(name: "Home", order: 0, isRoot: true)
        modelContext.insert(root)

        // text, symbol, POS
        let coreWords: [(String, String?, PartOfSpeech?)] = [
            ("I", "person.fill", .pronoun),
            ("you", "person.2.fill", .pronoun),
            ("want", "hand.point.right.fill", .verb),
            ("like", "hand.thumbsup.fill", .verb),
            ("don’t", "hand.thumbsdown.fill", .negation),
            ("more", "plus.circle.fill", .determiner),
            ("help", "hand.raised.fill", .social),
            ("go", "arrow.right.circle.fill", .verb),
            ("stop", "stop.circle.fill", .verb),
            ("yes", "checkmark.circle.fill", .social),
            ("no", "xmark.circle.fill", .negation),
            ("here", "mappin.circle.fill", .adverb),
            ("there", "location.circle.fill", .adverb),
            ("this", "hand.point.up.left.fill", .determiner),
            ("that", "hand.point.up.left", .determiner),
            ("what", "questionmark.circle.fill", .question),
            ("where", "mappin.and.ellipse", .question),
            ("now", "clock.fill", .adverb),
            ("later", "clock.badge", .adverb),
            ("eat", "fork.knife", .verb),
            ("drink", "takeoutbag.and.cup.and.straw.fill", .verb),
        ]

        for (idx, item) in coreWords.enumerated() {
            let color = item.2.map { FitzgeraldKey.colorHex(for: $0) }
            let tile = Tile(
                text: item.0,
                symbolName: item.1,
                colorHex: color,
                order: idx,
                isCore: true,
                page: root,
                partOfSpeechRaw: item.2?.rawValue
            )
            modelContext.insert(tile)
            root.tiles.append(tile)
        }

        try? modelContext.save()
    }

    private static func seedQuickPhrases(modelContext: ModelContext) {
        let defaults = ["Yes", "No", "Please", "Thank you", "Help"]
        for (idx, text) in defaults.enumerated() {
            modelContext.insert(QuickPhrase(text: text, order: idx))
        }
        try? modelContext.save()
    }

    private static func seedQuickPhrasesIfNeeded(modelContext: ModelContext, modelContextPages: [Page]) {
        let hasAny = ((try? modelContext.fetchCount(FetchDescriptor<QuickPhrase>())) ?? 0) > 0
        guard !hasAny else { return }
        seedQuickPhrases(modelContext: modelContext)
    }

    private static func seedCategories(modelContext: ModelContext) {
        guard let home = fetchRoot(modelContext: modelContext) else { return }
        let pages = (try? modelContext.fetch(FetchDescriptor<Page>())) ?? []
        seedCategoriesImpl(modelContext: modelContext, home: home, pages: pages)
    }

    private static func seedCategoriesIfNeeded(modelContext: ModelContext, pages: [Page]) {
        guard let home = pages.first(where: { $0.isRoot }) ?? pages.first else { return }
        let existingHomeLinks = Set(home.tiles.compactMap { $0.destinationPage?.name })
        let categoryNames = [
            "People", "Actions", "Feelings", "Needs", "Places",
            "Food & Drink", "Activities", "School/Work", "Time",
            "Describing", "Questions", "Social", "Body/Health",
            "Animals", "Clothing", "Weather", "Numbers/Colors", "Letters"
        ]
        let hasAnyCategoryLinked = !existingHomeLinks.intersection(categoryNames).isEmpty
        guard !hasAnyCategoryLinked else { return }

        seedCategoriesImpl(modelContext: modelContext, home: home, pages: pages)
    }

    private static func seedCategoriesImpl(modelContext: ModelContext, home: Page, pages: [Page]) {
        func getOrCreatePage(name: String, parent: Page?) -> Page {
            if let found = pages.first(where: { $0.name == name }) {
                if found.parent == nil, let parent { found.parent = parent }
                return found
            }
            let order = ((pages.map { $0.order }.max() ?? -1) + 1)
            let p = Page(name: name, order: order, isRoot: false)
            p.parent = parent
            modelContext.insert(p)
            return p
        }

        func addLinkTile(on page: Page, text: String, symbol: String?, pos: PartOfSpeech? = nil, destination: Page) {
            if page.tiles.contains(where: { $0.destinationPage?.id == destination.id }) { return }
            let order = page.tiles.count
            let colorHex = pos.map { FitzgeraldKey.colorHex(for: $0) } ?? "#C7B1FF"
            let tile = Tile(text: text,
                            symbolName: symbol,
                            colorHex: colorHex,
                            order: order,
                            isCore: false,
                            destinationPage: destination,
                            page: page,
                            partOfSpeechRaw: pos?.rawValue)
            modelContext.insert(tile)
            page.tiles.append(tile)
        }

        func addSpeakTile(on page: Page, text: String, symbol: String?, pos: PartOfSpeech? = nil) {
            if page.tiles.contains(where: { $0.text == text && $0.destinationPage == nil }) { return }
            let order = page.tiles.count
            let colorHex = pos.map { FitzgeraldKey.colorHex(for: $0) } ?? "#C7B1FF"
            let tile = Tile(text: text,
                            symbolName: symbol,
                            colorHex: colorHex,
                            order: order,
                            isCore: false,
                            page: page,
                            partOfSpeechRaw: pos?.rawValue)
            modelContext.insert(tile)
            page.tiles.append(tile)
        }

        // Create top categories
        let people = getOrCreatePage(name: "People", parent: home)
        let actions = getOrCreatePage(name: "Actions", parent: home)
        let feelings = getOrCreatePage(name: "Feelings", parent: home)
        let needs = getOrCreatePage(name: "Needs", parent: home)
        let places = getOrCreatePage(name: "Places", parent: home)
        let food = getOrCreatePage(name: "Food & Drink", parent: home)
        let activities = getOrCreatePage(name: "Activities", parent: home)
        let school = getOrCreatePage(name: "School/Work", parent: home)
        let time = getOrCreatePage(name: "Time", parent: home)
        let describing = getOrCreatePage(name: "Describing", parent: home)
        let questions = getOrCreatePage(name: "Questions", parent: home)
        let social = getOrCreatePage(name: "Social", parent: home)
        let body = getOrCreatePage(name: "Body/Health", parent: home)
        let animals = getOrCreatePage(name: "Animals", parent: home)
        let clothing = getOrCreatePage(name: "Clothing", parent: home)
        let weather = getOrCreatePage(name: "Weather", parent: home)
        let numbersColors = getOrCreatePage(name: "Numbers/Colors", parent: home)
        let letters = getOrCreatePage(name: "Letters", parent: home)

        // Link tiles on Home (use POS where it makes sense)
        addLinkTile(on: home, text: "People", symbol: "person.2.fill", pos: .pronoun, destination: people)
        addLinkTile(on: home, text: "Actions", symbol: "figure.walk.motion", pos: .verb, destination: actions)
        addLinkTile(on: home, text: "Feelings", symbol: "face.smiling", pos: .adjective, destination: feelings)
        addLinkTile(on: home, text: "Needs", symbol: "exclamationmark.bubble", pos: .social, destination: needs)
        addLinkTile(on: home, text: "Places", symbol: "house.fill", pos: .preposition, destination: places)
        addLinkTile(on: home, text: "Food & Drink", symbol: "fork.knife", pos: .noun, destination: food)
        addLinkTile(on: home, text: "Activities", symbol: "gamecontroller", pos: .verb, destination: activities)
        addLinkTile(on: home, text: "School/Work", symbol: "book.closed", pos: .noun, destination: school)
        addLinkTile(on: home, text: "Time", symbol: "clock.fill", pos: .adverb, destination: time)
        addLinkTile(on: home, text: "Describing", symbol: "textformat.size", pos: .adjective, destination: describing)
        addLinkTile(on: home, text: "Questions", symbol: "questionmark.circle", pos: .question, destination: questions)
        addLinkTile(on: home, text: "Social", symbol: "bubble.left.and.bubble.right.fill", pos: .social, destination: social)
        addLinkTile(on: home, text: "Body/Health", symbol: "cross.case.fill", pos: .noun, destination: body)
        addLinkTile(on: home, text: "Animals", symbol: "pawprint.fill", pos: .noun, destination: animals)
        addLinkTile(on: home, text: "Clothing", symbol: "tshirt.fill", pos: .noun, destination: clothing)
        addLinkTile(on: home, text: "Weather", symbol: "cloud.sun.fill", pos: .noun, destination: weather)
        addLinkTile(on: home, text: "Numbers/Colors", symbol: "paintpalette", pos: .adjective, destination: numbersColors)
        addLinkTile(on: home, text: "Letters", symbol: "textformat.abc", pos: .noun, destination: letters)

        // Seed items
        ["mom", "dad", "family", "friend", "teacher", "me", "you", "nurse", "doctor"].forEach {
            addSpeakTile(on: people, text: $0, symbol: "person.fill", pos: .noun)
        }
        ["go", "come", "stop", "look", "see", "want", "like", "play", "read", "write", "open", "close", "make", "get", "put", "give", "take", "help"].forEach {
            addSpeakTile(on: actions, text: $0, symbol: "figure.walk.motion", pos: .verb)
        }
        ["happy", "sad", "mad", "tired", "excited", "scared", "sick", "hurt", "bored", "calm"].forEach {
            addSpeakTile(on: feelings, text: $0, symbol: "face.smiling", pos: .adjective)
        }
        ["bathroom", "drink", "eat", "break", "more", "finished", "help", "pain"].forEach {
            addSpeakTile(on: needs, text: $0, symbol: "exclamationmark.bubble", pos: .social)
        }
        ["home", "school", "outside", "bathroom", "kitchen", "bedroom", "park", "store", "bus"].forEach {
            addSpeakTile(on: places, text: $0, symbol: "house.fill", pos: .noun)
        }

        // Food subpages
        let fruit = getOrCreatePage(name: "Fruit", parent: food)
        let vegetables = getOrCreatePage(name: "Vegetables", parent: food)
        let proteins = getOrCreatePage(name: "Proteins", parent: food)
        let snacks = getOrCreatePage(name: "Snacks", parent: food)
        let drinks = getOrCreatePage(name: "Drinks", parent: food)

        addLinkTile(on: food, text: "Fruit", symbol: "applelogo", pos: .noun, destination: fruit)
        addLinkTile(on: food, text: "Vegetables", symbol: "leaf.fill", pos: .noun, destination: vegetables)
        addLinkTile(on: food, text: "Proteins", symbol: "fork.knife.circle", pos: .noun, destination: proteins)
        addLinkTile(on: food, text: "Snacks", symbol: "takeoutbag.and.cup.and.straw.fill", pos: .noun, destination: snacks)
        addLinkTile(on: food, text: "Drinks", symbol: "cup.and.saucer.fill", pos: .noun, destination: drinks)

        ["apple", "banana", "orange", "grapes"].forEach {
            addSpeakTile(on: fruit, text: $0, symbol: "leaf.fill", pos: .noun)
        }
        ["carrot", "corn", "peas"].forEach {
            addSpeakTile(on: vegetables, text: $0, symbol: "leaf.fill", pos: .noun)
        }
        ["chicken", "egg", "beans"].forEach {
            addSpeakTile(on: proteins, text: $0, symbol: "fork.knife.circle", pos: .noun)
        }
        ["cracker", "cookie"].forEach {
            addSpeakTile(on: snacks, text: $0, symbol: "takeoutbag.and.cup.and.straw.fill", pos: .noun)
        }
        ["water", "juice", "milk"].forEach {
            addSpeakTile(on: drinks, text: $0, symbol: "cup.and.saucer.fill", pos: .noun)
        }

        try? modelContext.save()
    }

    private static func fetchRoot(modelContext: ModelContext) -> Page? {
        let descriptor = FetchDescriptor<Page>()
        let all = try? modelContext.fetch(descriptor)
        return all?.first(where: { $0.isRoot }) ?? all?.first
    }
}
