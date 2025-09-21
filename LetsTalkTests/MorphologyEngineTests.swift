// MorphologyEngineTests.swift
import Testing
@testable import LetsTalk

@Suite("MorphologyEngine")
struct MorphologyEngineTests {

    @Test("Verb -ing forms (regular and irregular)")
    func testIng() async throws {
        #expect(MorphologyEngine.toIng("play") == "playing")
        #expect(MorphologyEngine.toIng("make") == "making")
        #expect(MorphologyEngine.toIng("tie") == "tying")
        #expect(MorphologyEngine.toIng("RUN") == "RUNNING")
        #expect(MorphologyEngine.toIng("see") == "seeing") // irregular participle list
    }

    @Test("Verb past forms (regular and irregular)")
    func testPast() async throws {
        #expect(MorphologyEngine.toPast("play") == "played")
        #expect(MorphologyEngine.toPast("like") == "liked")
        #expect(MorphologyEngine.toPast("stop") == "stopped")
        #expect(MorphologyEngine.toPast("carry") == "carried")
        #expect(MorphologyEngine.toPast("go") == "went")
        #expect(MorphologyEngine.toPast("DRINK") == "DRANK")
    }

    @Test("Verb 3rd person singular")
    func testThirdPersonS() async throws {
        #expect(MorphologyEngine.to3rdPersonS("play") == "plays")
        #expect(MorphologyEngine.to3rdPersonS("go") == "goes")
        #expect(MorphologyEngine.to3rdPersonS("carry") == "carries")
        #expect(MorphologyEngine.to3rdPersonS("wash") == "washes")
        #expect(MorphologyEngine.to3rdPersonS("HAVE") == "HAS")
    }

    @Test("Base verb heuristic")
    func testBaseVerb() async throws {
        #expect(MorphologyEngine.baseVerb("running") == "run")
        #expect(MorphologyEngine.baseVerb("carried") == "carry")
        #expect(MorphologyEngine.baseVerb("liked") == "like")
        #expect(MorphologyEngine.baseVerb("goes") == "go")
        #expect(MorphologyEngine.baseVerb("WENT") == "GO")
    }

    @Test("Pluralization and singularization")
    func testNouns() async throws {
        #expect(MorphologyEngine.pluralize("cat") == "cats")
        #expect(MorphologyEngine.pluralize("bus") == "buses")
        #expect(MorphologyEngine.pluralize("baby") == "babies")
        #expect(MorphologyEngine.pluralize("child") == "children")

        #expect(MorphologyEngine.singularize("cats") == "cat")
        #expect(MorphologyEngine.singularize("buses") == "bus")
        #expect(MorphologyEngine.singularize("babies") == "baby")
        #expect(MorphologyEngine.singularize("children") == "child")
    }

    @Test("Pronoun variants preserve capitalization")
    func testPronouns() async throws {
        let forms = MorphologyEngine.pronounVariants("I")
        #expect(forms.contains("I"))
        #expect(forms.contains("me"))
        #expect(forms.contains("my"))
        #expect(forms.contains("mine"))
        #expect(forms.contains("myself"))

        let they = MorphologyEngine.pronounVariants("They")
        #expect(they.contains("They"))
        #expect(they.contains("them"))
        #expect(they.contains("their"))
        #expect(they.contains("theirs"))
        #expect(they.contains("themselves"))
    }

    @Test("Negation insertion and simple auxiliary negation")
    func testNegation() async throws {
        let inserted = MorphologyEngine.insertNot(in: ["I","am","hungry"])
        #expect(inserted == ["I","am","not","hungry"])

        let appended = MorphologyEngine.insertNot(in: ["I","want"])
        #expect(appended == ["I","want","not"])

        let simpleNeg = MorphologyEngine.negateSimpleVerb(in: ["He","likes"])
        #expect(simpleNeg == ["He","does","not","like"])
    }

    @Test("Replace last word in sentence")
    func testReplaceLastWord() async throws {
        let s1 = MorphologyEngine.replaceLastWord(in: "I like play") { MorphologyEngine.toIng($0) }
        #expect(s1 == "I like playing")

        let s2 = MorphologyEngine.replaceLastWord(in: "Go") { MorphologyEngine.toPast($0) }
        #expect(s2 == "Went")
    }
}
