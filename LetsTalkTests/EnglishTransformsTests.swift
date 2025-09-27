// EnglishTransformsTests.swift
import Testing
@testable import LetsTalk

@Suite("English rules and tokenization")
struct EnglishTransformsTests {

    @Test("Regular verbs: -ing/-ed/3rd-s")
    func regularVerbInflections() async throws {
        let engine = MorphologyEngine(languageCode: "en")
        #expect(engine.toIng("make") == "making")
        #expect(engine.toPast("play") == "played")
        #expect(engine.to3rdPersonS("watch") == "watches")
    }

    @Test("Irregular verbs")
    func irregularVerbs() async throws {
        let engine = MorphologyEngine(languageCode: "en")
        #expect(engine.toPast("go") == "went")
        #expect(engine.toPast("see") == "saw")
        #expect(engine.baseVerb("went") == "go")
        #expect(engine.baseVerb("seen") == "see")
    }

    @Test("Nouns: regular, classical, and irregular")
    func nounPluralization() async throws {
        let engine = MorphologyEngine(languageCode: "en")
        #expect(engine.pluralize("cat", conservative: false) == "cats")
        #expect(engine.pluralize("child", conservative: false) == "children")
        #expect(engine.pluralize("cactus", conservative: false) == "cacti")
        #expect(engine.singularize("children", conservative: false) == "child")
        #expect(engine.singularize("cacti", conservative: false) == "cactus")
    }

    @Test("Adjectives/adverbs")
    func adjectivesAdverbs() async throws {
        let engine = MorphologyEngine(languageCode: "en")
        #expect(engine.toComparative("happy") == "happier")
        #expect(engine.toSuperlative("happy") == "happiest")
        #expect(engine.toAdverb("public") == "publicly")
        #expect(engine.adverbToAdjective("quickly") == "quick")
    }

    @Test("Articles: a vs an with vowel sound heuristics and acronyms")
    func articles() async throws {
        let engine = MorphologyEngine(languageCode: "en")
        #expect(engine.indefiniteArticle(for: "apple") == "an")
        #expect(engine.indefiniteArticle(for: "banana") == "a")
        #expect(engine.indefiniteArticle(for: "hour") == "an")
        #expect(engine.indefiniteArticle(for: "unicorn") == "a")
        #expect(engine.indefiniteArticle(for: "MRI") == "an") // vowel-sounding acronym
    }

    @Test("Pronoun variants")
    func pronounVariants() async throws {
        #expect(Set(MorphologyEngine.pronounVariants("he")).isSuperset(of: ["he","him","his","himself"]))
        // Engine policy: if input is capitalized, nominative remains capitalized; other forms are lowercase.
        #expect(Set(MorphologyEngine.pronounVariants("She")).isSuperset(of: ["She","her","hers","herself"]))
    }

    @Test("Negation and yes/no questions with and without auxiliaries")
    func clauses() async throws {
        let engine = MorphologyEngine(languageCode: "en")
        #expect(MorphologyEngine.negate(into: "I go") == "I do not go")
        #expect(MorphologyEngine.negate(into: "She is running") == "She is not running")
        #expect(engine.makeYesNoQuestion(into: "You like pizza") == "Do you like pizza")
        #expect(engine.makeYesNoQuestion(into: "They are here") == "Are they here")
    }

    @Test("Tokenization preserves trailing punctuation and replacement respects it")
    func tokenizationAndReplacement() async throws {
        let engine = MorphologyEngine(languageCode: "en")
        let input = "I like pizza!"
        let out = engine.replaceLastWord(in: input) { _ in "pizzas" }
        #expect(out == "I like pizzas!")
    }
}
