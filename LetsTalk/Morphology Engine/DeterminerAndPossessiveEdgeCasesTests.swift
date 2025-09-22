// DeterminerAndPossessiveEdgeCasesTests.swift
import Testing
@testable import LetsTalk

@Suite("Determiners and possessives - edge cases")
struct DeterminerAndPossessiveEdgeCasesTests {

    @Test("Determiner preferences across plural-looking and uncountable nouns")
    func determiners() async throws {
        MorphologyEngine.setLanguage("en")
        #expect(MorphologyEngine.determiner(for: "cats", preference: .indefinite) == "some")
        #expect(MorphologyEngine.determiner(for: "information", preference: .indefinite) == "some")
        #expect(MorphologyEngine.determiner(for: "cats", preference: .definite) == "the")
        #expect(MorphologyEngine.determiner(for: "cats", preference: .none) == "")
        #expect(MorphologyEngine.determiner(for: "John", preference: .definite) == "")
    }

    @Test("Possessives for s-ending words and irregular plurals")
    func possessives() async throws {
        #expect(MorphologyEngine.possessive("class") == "class'")
        #expect(MorphologyEngine.possessive("bus") == "bus'")
        #expect(MorphologyEngine.possessive("James") == "James'")
        #expect(MorphologyEngine.possessive("children") == "children's")
        #expect(MorphologyEngine.possessive("child") == "child's")
    }
}
