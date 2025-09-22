// MorphologyOverridesPersistenceTests.swift
import Testing
@testable import LetsTalk

@Suite("Overrides persistence via UserDefaults (language-scoped)")
struct MorphologyOverridesPersistenceTests {

    // Use a throwaway language tag so we don't touch real data.
    let testLang = "zz"

    @Test("Setting and retrieving a plural override persists across Instances")
    func pluralOverridePersists() async throws {
        // Clean slate for this language
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: testLang)

        // 1) Add an override: child -> children
        MorphologyEngine.updateOverrides(for: testLang) { o in
            o.plural["child"] = "children"
            o.singular["children"] = "child"
        }

        // 2) New engine instance should read back persisted overrides
        let engine = MorphologyEngine(languageCode: testLang)
        let out = engine.pluralize("child", conservative: false)
        #expect(out == "children")

        // 3) Case matching should be preserved by matchCase
        #expect(engine.pluralize("Child", conservative: false) == "Children")
        #expect(engine.pluralize("CHILD", conservative: false) == "CHILDREN")
    }

    @Test("Past override and base mapping")
    func pastOverrideAndBase() async throws {
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: testLang)

        MorphologyEngine.updateOverrides(for: testLang) { o in
            o.past["go"] = "went"
            // Simulate TileEditor behavior adding base for the past form
            o.base["went"] = "go"
        }

        let engine = MorphologyEngine(languageCode: testLang)
        #expect(engine.toPast("go") == "went")
        #expect(engine.baseVerb("went") == "go")
    }

    @Test("Do-not-change set blocks pluralization")
    func doNotChangePreventsPluralization() async throws {
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: testLang)

        MorphologyEngine.updateOverrides(for: testLang) { o in
            o.doNotChange.insert("pants") // treat as invariant for user
        }

        let engine = MorphologyEngine(languageCode: testLang)
        #expect(engine.pluralize("pants", conservative: false) == "pants")
        #expect(engine.singularize("pants", conservative: false) == "pants")
    }
}
