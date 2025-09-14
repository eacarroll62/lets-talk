import Testing
import Foundation

@testable import TalkToMe

@Suite("PredictionService")
struct PredictionServiceTests {

    @Test("EN suggestions honor learned bigrams/trigrams")
    @MainActor
    func englishSuggestions() async throws {
        let svc = PredictionService.shared
        svc.reset()

        // Learn sequences
        svc.learn(from: "hello world", languageCode: "en")
        svc.learn(from: "hello there", languageCode: "en")
        svc.learn(from: "hello world again", languageCode: "en")

        let sugg1 = svc.suggestions(for: "hello", languageCode: "en", limit: 3)
        // "world" should be highly ranked given two occurrences
        #expect(sugg1.contains("world"))

        let sugg2 = svc.suggestions(for: "hello world", languageCode: "en", limit: 3)
        #expect(sugg2.contains("again"))
    }

    @Test("ES model is used for Spanish language codes")
    @MainActor
    func spanishRouting() async throws {
        let svc = PredictionService.shared
        svc.reset()

        svc.learn(from: "hola mundo", languageCode: "es")
        let sugg = svc.suggestions(for: "hola", languageCode: "es", limit: 3)
        #expect(sugg.contains("mundo"))
    }

    @Test("Reset clears learned state")
    @MainActor
    func resetClears() async throws {
        let svc = PredictionService.shared
        svc.reset()

        svc.learn(from: "foo bar", languageCode: "en")
        var sugg = svc.suggestions(for: "foo", languageCode: "en", limit: 3)
        #expect(sugg.contains("bar"))

        svc.reset()
        // After reset, suggestions come from seed corpus; "bar" should be unlikely
        sugg = svc.suggestions(for: "foo", languageCode: "en", limit: 10)
        #expect(!sugg.contains("bar"))
    }
}
