// ConjugationTests.swift
import Testing
@testable import LetsTalk

@Suite("Conjugation coverage: active/passive, all aspects")
struct ConjugationTests {

    @Test("Active: simple present/past/future")
    func activeSimple() async throws {
        #expect(MorphologyEngine.conjugate(lemma: "go", person: .first, number: .singular, tense: .present) == "go")
        #expect(MorphologyEngine.conjugate(lemma: "go", person: .third, number: .singular, tense: .present) == "goes")
        #expect(MorphologyEngine.conjugate(lemma: "play", person: .second, number: .plural, tense: .past) == "played")
        #expect(MorphologyEngine.conjugate(lemma: "eat", person: .first, number: .plural, tense: .future) == "will eat")
    }

    @Test("Active: progressive/perfect/perfect progressive")
    func activeAspects() async throws {
        #expect(MorphologyEngine.conjugate(lemma: "run", person: .first, number: .singular, tense: .present, aspect: .progressive) == "am running")
        #expect(MorphologyEngine.conjugate(lemma: "run", person: .third, number: .singular, tense: .past, aspect: .progressive) == "was running")
        #expect(MorphologyEngine.conjugate(lemma: "write", person: .third, number: .plural, tense: .present, aspect: .perfect) == "have written")
        #expect(MorphologyEngine.conjugate(lemma: "write", person: .third, number: .singular, tense: .present, aspect: .perfect) == "has written")
        #expect(MorphologyEngine.conjugate(lemma: "play", person: .second, number: .singular, tense: .past, aspect: .perfectProgressive) == "had been playing")
        #expect(MorphologyEngine.conjugate(lemma: "play", person: .first, number: .plural, tense: .future, aspect: .perfectProgressive) == "will have been playing")
    }

    @Test("Passive: simple/progressive/perfect across tenses")
    func passiveAspects() async throws {
        // simple passive
        #expect(MorphologyEngine.conjugate(lemma: "eat", person: .third, number: .singular, tense: .present, voice: .passive) == "is eaten")
        #expect(MorphologyEngine.conjugate(lemma: "eat", person: .first, number: .plural, tense: .past, voice: .passive) == "were eaten")
        #expect(MorphologyEngine.conjugate(lemma: "make", person: .second, number: .singular, tense: .future, voice: .passive) == "will be made")

        // progressive passive
        #expect(MorphologyEngine.conjugate(lemma: "write", person: .first, number: .singular, tense: .present, aspect: .progressive, voice: .passive) == "am being written")
        #expect(MorphologyEngine.conjugate(lemma: "write", person: .third, number: .singular, tense: .past, aspect: .progressive, voice: .passive) == "was being written")

        // perfect passive
        #expect(MorphologyEngine.conjugate(lemma: "make", person: .third, number: .plural, tense: .future, aspect: .perfect, voice: .passive) == "will have been made")
        #expect(MorphologyEngine.conjugate(lemma: "steal", person: .first, number: .plural, tense: .present, aspect: .perfect, voice: .passive) == "have been stolen")
    }
}
