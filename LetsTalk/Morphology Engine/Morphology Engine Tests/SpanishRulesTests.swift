// SpanishRulesTests.swift
import Testing
@testable import LetsTalk

@Suite("Spanish rules: basic nouns and articles")
struct SpanishRulesTests {

    @Test("Pluralization basics: vowel + s, consonant + es, z -> ces")
    func pluralizationBasics() async throws {
        let engine = MorphologyEngine(languageCode: "es")
        #expect(engine.pluralize("libro", conservative: false) == "libros")
        #expect(engine.pluralize("papel", conservative: false) == "papeles")
        #expect(engine.pluralize("luz", conservative: false) == "luces")

        // Case preservation
        #expect(engine.pluralize("Libro", conservative: false) == "Libros")
        #expect(engine.pluralize("LUZ", conservative: false) == "LUCES")
    }

    @Test("Singularization basics matching the above")
    func singularizationBasics() async throws {
        let engine = MorphologyEngine(languageCode: "es")
        #expect(engine.singularize("libros", conservative: false) == "libro")
        #expect(engine.singularize("papeles", conservative: false) == "papel")
        #expect(engine.singularize("luces", conservative: false) == "luz")

        // Case preservation
        #expect(engine.singularize("Libros", conservative: false) == "Libro")
        #expect(engine.singularize("LUCES", conservative: false) == "LUZ")
    }

    @Test("doNotChange and overrides precedence")
    func doNotChangeAndOverrides() async throws {
        let lang = "es"
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: lang)
        MorphologyEngine.updateOverrides(for: lang) { o in
            o.doNotChange.insert("luz")
            o.plural["papel"] = "papéles" // force a custom form to verify precedence
            o.singular["papéles"] = "papel"
        }

        let engine = MorphologyEngine(languageCode: lang)

        // doNotChange wins
        #expect(engine.pluralize("luz", conservative: false) == "luz")
        #expect(engine.singularize("luz", conservative: false) == "luz")

        // Overrides win over rules
        #expect(engine.pluralize("papel", conservative: false) == "papéles")
        #expect(engine.singularize("papéles", conservative: false) == "papel")
    }

    @Test("Articles default and determiner heuristics")
    func articlesAndDeterminers() async throws {
        let engine = MorphologyEngine(languageCode: "es")

        // Indefinite article default
        #expect(engine.indefiniteArticle(for: "libro") == "un")

        // Determiners: crude plural/singular
        #expect(engine.determiner(for: "libro", preference: .definite) == "el")
        #expect(engine.determiner(for: "libros", preference: .definite) == "los")
        #expect(engine.determiner(for: "libro", preference: .indefinite) == "un")
        #expect(engine.determiner(for: "libros", preference: .indefinite) == "unos")

        // Override precedence
        MorphologyEngine.updateOverrides(for: "es") { o in
            o.article["libro"] = "el"
            o.article["libros"] = "unos"
        }
        #expect(engine.determiner(for: "libro", preference: .definite) == "el")
        #expect(engine.determiner(for: "libros", preference: .indefinite) == "unos")
    }

    @Test("Language routing uses Spanish for es-ES")
    func languageRouting() async throws {
        let engine = MorphologyEngine(languageCode: "es-ES")
        #expect(engine.pluralize("luz", conservative: false) == "luces")
        #expect(engine.singularize("luces", conservative: false) == "luz")
    }
}

