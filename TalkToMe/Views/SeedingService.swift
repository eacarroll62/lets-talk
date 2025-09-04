// SeedingService.swift

import Foundation
import SwiftData

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

        let coreWords: [(String, String?, String?)] = [
            ("I", "person.fill", "#F9D65C"),
            ("you", "person.2.fill", "#E4C1F9"),
            ("want", "hand.point.right.fill", "#AEDFF7"),
            ("like", "hand.thumbsup.fill", "#C7F9CC"),
            ("don’t", "hand.thumbsdown.fill", "#FFADAD"),
            ("more", "plus.circle.fill", "#B5E48C"),
            ("help", "hand.raised.fill", "#FFD6E0"),
            ("go", "arrow.right.circle.fill", "#ACE7FF"),
            ("stop", "stop.circle.fill", "#FFADAD"),
            ("yes", "checkmark.circle.fill", "#ACE7FF"),
            ("no", "xmark.circle.fill", "#FFADAD"),
            ("here", "mappin.circle.fill", "#AEDFF7"),
            ("there", "location.circle.fill", "#AEDFF7"),
            ("this", "hand.point.up.left.fill", "#FFD6E0"),
            ("that", "hand.point.up.left", "#FFD6E0"),
            ("what", "questionmark.circle.fill", "#E4C1F9"),
            ("where", "mappin.and.ellipse", "#E4C1F9"),
            ("now", "clock.fill", "#F9D65C"),
            ("later", "clock.badge", "#F9D65C"),
            ("eat", "fork.knife", "#FFCC99"),
            ("drink", "takeoutbag.and.cup.and.straw.fill", "#99CCFF"),
        ]

        for (idx, item) in coreWords.enumerated() {
            let tile = Tile(text: item.0, symbolName: item.1, colorHex: item.2, order: idx, isCore: true, page: root)
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

        func addLinkTile(on page: Page, text: String, symbol: String?, colorHex: String?, destination: Page) {
            if page.tiles.contains(where: { $0.destinationPage?.id == destination.id }) { return }
            let order = page.tiles.count
            let tile = Tile(text: text, symbolName: symbol, colorHex: colorHex, order: order, isCore: false, destinationPage: destination, page: page)
            modelContext.insert(tile)
            page.tiles.append(tile)
        }

        func addSpeakTile(on page: Page, text: String, symbol: String?, colorHex: String?) {
            if page.tiles.contains(where: { $0.text == text && $0.destinationPage == nil }) { return }
            let order = page.tiles.count
            let tile = Tile(text: text, symbolName: symbol, colorHex: colorHex, order: order, isCore: false, page: page)
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

        // Link tiles on Home
        addLinkTile(on: home, text: "People", symbol: "person.2.fill", colorHex: "#C7B1FF", destination: people)
        addLinkTile(on: home, text: "Actions", symbol: "figure.walk.motion", colorHex: "#9AD0F5", destination: actions)
        addLinkTile(on: home, text: "Feelings", symbol: "face.smiling", colorHex: "#FFD6E0", destination: feelings)
        addLinkTile(on: home, text: "Needs", symbol: "exclamationmark.bubble", colorHex: "#F9D65C", destination: needs)
        addLinkTile(on: home, text: "Places", symbol: "house.fill", colorHex: "#AEDFF7", destination: places)
        addLinkTile(on: home, text: "Food & Drink", symbol: "fork.knife", colorHex: "#FFCC99", destination: food)
        addLinkTile(on: home, text: "Activities", symbol: "gamecontroller", colorHex: "#ACE7FF", destination: activities)
        addLinkTile(on: home, text: "School/Work", symbol: "book.closed", colorHex: "#E4C1F9", destination: school)
        addLinkTile(on: home, text: "Time", symbol: "clock.fill", colorHex: "#F9D65C", destination: time)
        addLinkTile(on: home, text: "Describing", symbol: "textformat.size", colorHex: "#B5E48C", destination: describing)
        addLinkTile(on: home, text: "Questions", symbol: "questionmark.circle", colorHex: "#C7B1FF", destination: questions)
        addLinkTile(on: home, text: "Social", symbol: "bubble.left.and.bubble.right.fill", colorHex: "#ACE7FF", destination: social)
        addLinkTile(on: home, text: "Body/Health", symbol: "cross.case.fill", colorHex: "#FFD6E0", destination: body)
        addLinkTile(on: home, text: "Animals", symbol: "pawprint.fill", colorHex: "#C7F9CC", destination: animals)
        addLinkTile(on: home, text: "Clothing", symbol: "tshirt.fill", colorHex: "#FFE28A", destination: clothing)
        addLinkTile(on: home, text: "Weather", symbol: "cloud.sun.fill", colorHex: "#9AD0F5", destination: weather)
        addLinkTile(on: home, text: "Numbers/Colors", symbol: "paintpalette", colorHex: "#FFE28A", destination: numbersColors)
        addLinkTile(on: home, text: "Letters", symbol: "textformat.abc", colorHex: "#FFD6E0", destination: letters)

        // Seed items
        ["mom", "dad", "family", "friend", "teacher", "me", "you", "nurse", "doctor"].forEach {
            addSpeakTile(on: people, text: $0, symbol: "person.fill", colorHex: "#C7B1FF")
        }
        ["go", "come", "stop", "look", "see", "want", "like", "play", "read", "write", "open", "close", "make", "get", "put", "give", "take", "help"].forEach {
            addSpeakTile(on: actions, text: $0, symbol: "figure.walk.motion", colorHex: "#9AD0F5")
        }
        ["happy", "sad", "mad", "tired", "excited", "scared", "sick", "hurt", "bored", "calm"].forEach {
            addSpeakTile(on: feelings, text: $0, symbol: "face.smiling", colorHex: "#FFD6E0")
        }
        ["bathroom", "drink", "eat", "break", "more", "finished", "help", "pain"].forEach {
            addSpeakTile(on: needs, text: $0, symbol: "exclamationmark.bubble", colorHex: "#F9D65C")
        }
        ["home", "school", "outside", "bathroom", "kitchen", "bedroom", "park", "store", "bus"].forEach {
            addSpeakTile(on: places, text: $0, symbol: "house.fill", colorHex: "#AEDFF7")
        }

        // Food subpages
        let fruit = getOrCreatePage(name: "Fruit", parent: food)
        let vegetables = getOrCreatePage(name: "Vegetables", parent: food)
        let proteins = getOrCreatePage(name: "Proteins", parent: food)
        let snacks = getOrCreatePage(name: "Snacks", parent: food)
        let drinks = getOrCreatePage(name: "Drinks", parent: food)

        addLinkTile(on: food, text: "Fruit", symbol: "applelogo", colorHex: "#FFCC99", destination: fruit)
        addLinkTile(on: food, text: "Vegetables", symbol: "leaf.fill", colorHex: "#B5E48C", destination: vegetables)
        addLinkTile(on: food, text: "Proteins", symbol: "fork.knife.circle", colorHex: "#FFE28A", destination: proteins)
        addLinkTile(on: food, text: "Snacks", symbol: "takeoutbag.and.cup.and.straw.fill", colorHex: "#FFD6E0", destination: snacks)
        addLinkTile(on: food, text: "Drinks", symbol: "cup.and.saucer.fill", colorHex: "#99CCFF", destination: drinks)

        ["apple", "banana", "orange", "grapes"].forEach {
            addSpeakTile(on: fruit, text: $0, symbol: "leaf.fill", colorHex: "#FFCC99")
        }
        ["carrot", "corn", "peas"].forEach {
            addSpeakTile(on: vegetables, text: $0, symbol: "leaf.fill", colorHex: "#B5E48C")
        }
        ["chicken", "egg", "beans"].forEach {
            addSpeakTile(on: proteins, text: $0, symbol: "fork.knife.circle", colorHex: "#FFE28A")
        }
        ["cracker", "cookie"].forEach {
            addSpeakTile(on: snacks, text: $0, symbol: "takeoutbag.and.cup.and.straw.fill", colorHex: "#FFD6E0")
        }
        ["water", "juice", "milk"].forEach {
            addSpeakTile(on: drinks, text: $0, symbol: "cup.and.saucer.fill", colorHex: "#99CCFF")
        }

        try? modelContext.save()
    }

    private static func fetchRoot(modelContext: ModelContext) -> Page? {
        let descriptor = FetchDescriptor<Page>()
        let all = try? modelContext.fetch(descriptor)
        return all?.first(where: { $0.isRoot }) ?? all?.first
    }
}
