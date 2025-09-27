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

    @Test("Do-not-change preserves casing for both directions")
    func doNotChangePreservesCasing() async throws {
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: testLang)

        MorphologyEngine.updateOverrides(for: testLang) { o in
            o.doNotChange.insert("pants")
        }

        let engine = MorphologyEngine(languageCode: testLang)

        // Title case
        #expect(engine.pluralize("Pants", conservative: false) == "Pants")
        #expect(engine.singularize("Pants", conservative: false) == "Pants")

        // All caps
        #expect(engine.pluralize("PANTS", conservative: false) == "PANTS")
        #expect(engine.singularize("PANTS", conservative: false) == "PANTS")
    }

    @Test("Do-not-change is language-scoped")
    func doNotChangeIsLanguageScoped() async throws {
        // Ensure clean slates
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: testLang)
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: "en")

        // Mark "pants" as do-not-change only for testLang
        MorphologyEngine.updateOverrides(for: testLang) { o in
            o.doNotChange.insert("pants")
        }

        // In testLang ("zz"), should not change
        let zzEngine = MorphologyEngine(languageCode: testLang)
        #expect(zzEngine.singularize("pants", conservative: false) == "pants")
        #expect(zzEngine.pluralize("pants", conservative: false) == "pants")

        // In English ("en"), default rules apply: "pants" -> "pant" by naive singularization
        let enEngine = MorphologyEngine(languageCode: "en")
        #expect(enEngine.singularize("pants", conservative: false) == "pant")
    }

    // MARK: - Additional coverage

    @Test("Override case matching for plural and past")
    func overrideCaseMatching() async throws {
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: testLang)

        MorphologyEngine.updateOverrides(for: testLang) { o in
            // Plural override
            o.plural["mouse"] = "mice"
            o.singular["mice"] = "mouse"
            // Past override
            o.past["go"] = "went"
            o.base["went"] = "go"
        }

        let engine = MorphologyEngine(languageCode: testLang)

        // Plural override case matching
        #expect(engine.pluralize("mouse", conservative: false) == "mice")
        #expect(engine.pluralize("Mouse", conservative: false) == "Mice")
        #expect(engine.pluralize("MOUSE", conservative: false) == "MICE")

        // Past override case matching
        #expect(engine.toPast("go") == "went")
        #expect(engine.toPast("Go") == "Went")
        #expect(engine.toPast("GO") == "WENT")
    }

    @Test("Plural override alone does not imply reverse singular mapping")
    func pluralOverrideDoesNotAutoCreateReverse() async throws {
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: testLang)

        // Only set a forward plural override; do NOT set the reverse singular mapping.
        MorphologyEngine.updateOverrides(for: testLang) { o in
            o.plural["gizmo"] = "gizmosx" // an unusual plural to avoid default rules
            // No: o.singular["gizmosx"] = "gizmo"
        }

        let engine = MorphologyEngine(languageCode: testLang)

        // Forward works via override
        #expect(engine.pluralize("gizmo", conservative: false) == "gizmosx")

        // Reverse should NOT magically occur; default singularization will not know about "gizmosx" -> "gizmo"
        // It should strip a trailing 's' or 'es' if any; here it should fall back to removing a trailing 'x' only via 's'/'es' paths, which do not apply.
        // So we expect it to return the input unchanged (since it doesn't end with 's' or 'es'), demonstrating no implicit reverse mapping.
        #expect(engine.singularize("gizmosx", conservative: false) == "gizmosx")

        // Now add the explicit reverse and verify it works
        MorphologyEngine.updateOverrides(for: testLang) { o in
            o.singular["gizmosx"] = "gizmo"
        }
        #expect(engine.singularize("gizmosx", conservative: false) == "gizmo")
    }

    @Test("Do-not-change with punctuation via replaceLastWord helper")
    func doNotChangeWithPunctuationInReplaceLastWord() async throws {
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: testLang)
        MorphologyEngine.updateOverrides(for: testLang) { o in
            o.doNotChange.insert("pants")
        }

        let engine = MorphologyEngine(languageCode: testLang)

        let sentence1 = "I like pants,"
        let keptPlural = engine.replaceLastWord(in: sentence1) { word in
            engine.pluralize(word, conservative: false)
        }
        #expect(keptPlural == "I like pants,")

        let sentence2 = "Those are pants!"
        let keptSingular = engine.replaceLastWord(in: sentence2) { word in
            engine.singularize(word, conservative: false)
        }
        #expect(keptSingular == "Those are pants!")
    }

    @Test("Do-not-change preserves mixed casing unchanged")
    func doNotChangePreservesMixedCasing() async throws {
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: testLang)
        MorphologyEngine.updateOverrides(for: testLang) { o in
            o.doNotChange.insert("pants")
        }

        let engine = MorphologyEngine(languageCode: testLang)
        #expect(engine.pluralize("PaNtS", conservative: false) == "PaNtS")
        #expect(engine.singularize("PaNtS", conservative: false) == "PaNtS")
    }

    @Test("Language scoping: primary language applies to subtags")
    func languageScopingPrimaryAppliesToSubtags() async throws {
        // Clean slate for English primary
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: "en")
        MorphologyEngine.setOverrides(MorphologyOverrides(), for: "es")

        // Set an override at primary "en"
        MorphologyEngine.updateOverrides(for: "en") { o in
            o.doNotChange.insert("pants")
            o.plural["child"] = "children"
            o.singular["children"] = "child"
        }

        // Engines with subtags should see the primary "en" overrides due to primary-language keying
        let enUS = MorphologyEngine(languageCode: "en-US")
        let enGB = MorphologyEngine(languageCode: "en-GB")

        #expect(enUS.singularize("pants", conservative: false) == "pants")
        #expect(enGB.singularize("pants", conservative: false) == "pants")
        #expect(enUS.pluralize("child", conservative: false) == "children")
        #expect(enGB.pluralize("child", conservative: false) == "children")

        // Spanish should not be affected
        let es = MorphologyEngine(languageCode: "es")
        #expect(es.singularize("pants", conservative: false) == "pant")
    }
}
