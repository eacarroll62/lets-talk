// TokenSplitEdgeCasesTests.swift
import Testing
@testable import LetsTalk

@Suite("Token split edge cases: quotes and mixed punctuation")
struct TokenSplitEdgeCasesTests {

    @Test("Split with smart quotes and commas")
    func quotesAndCommas() async throws {
        let (c1, t1) = MorphologyEngine.splitTrailingPunctuation("hello,”")
        #expect(c1 == "hello")
        #expect(t1 == ",”")

        let (c2, t2) = MorphologyEngine.splitTrailingPunctuation("“quoted,”")
        #expect(c2 == "“quoted")
        #expect(t2 == ",”")

        let (c3, t3) = MorphologyEngine.splitTrailingPunctuation("can't,”")
        #expect(c3 == "can't")
        #expect(t3 == ",”")
    }

    @Test("Split with mixed punctuation ?! and periods in the middle")
    func mixedPunctuation() async throws {
        let (c1, t1) = MorphologyEngine.splitTrailingPunctuation("world?!")
        #expect(c1 == "world")
        #expect(t1 == "?!")

        let (c2, t2) = MorphologyEngine.splitTrailingPunctuation("3.14,")
        #expect(c2 == "3.14")
        #expect(t2 == ",")

        let (c3, t3) = MorphologyEngine.splitTrailingPunctuation("email@example.com.")
        #expect(c3 == "email@example.com")
        #expect(t3 == ".")
    }

    @Test("replaceLastWord respects trailing punctuation across unicode quotes")
    func replaceLastWordWithQuotes() async throws {
        let s = MorphologyEngine.replaceLastWord(in: "He said, “run.”") { MorphologyEngine.toPast($0) }
        #expect(s == "He said, “ran.”")
    }
}
