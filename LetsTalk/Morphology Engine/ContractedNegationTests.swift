// ContractedNegationTests.swift
import Testing
@testable import LetsTalk

@Suite("Contracted negation")
struct ContractedNegationTests {

    @Test("Contracted negation with auxiliaries")
    func contractedAuxiliaries() async throws {
        #expect(MorphologyEngine.negate(["She","is","here"], contracted: true).joined(separator: " ") == "She isn't here")
        #expect(MorphologyEngine.negate(["They","are","ready"], contracted: true).joined(separator: " ") == "They aren't ready")
        #expect(MorphologyEngine.negate(["I","was","there"], contracted: true).joined(separator: " ") == "I wasn't there")
        #expect(MorphologyEngine.negate(["You","were","late"], contracted: true).joined(separator: " ") == "You weren't late")

        #expect(MorphologyEngine.negate(["I","have","finished"], contracted: true).joined(separator: " ") == "I haven't finished")
        #expect(MorphologyEngine.negate(["He","has","eaten"], contracted: true).joined(separator: " ") == "He hasn't eaten")
        #expect(MorphologyEngine.negate(["We","had","left"], contracted: true).joined(separator: " ") == "We hadn't left")

        #expect(MorphologyEngine.negate(["I","do","know"], contracted: true).joined(separator: " ") == "I don't know")
        #expect(MorphologyEngine.negate(["He","does","like"], contracted: true).joined(separator: " ") == "He doesn't like")
        #expect(MorphologyEngine.negate(["They","did","go"], contracted: true).joined(separator: " ") == "They didn't go")

        #expect(MorphologyEngine.negate(["She","will","come"], contracted: true).joined(separator: " ") == "She won't come")
        #expect(MorphologyEngine.negate(["He","can","swim"], contracted: true).joined(separator: " ") == "He can't swim")
        #expect(MorphologyEngine.negate(["We","should","try"], contracted: true).joined(separator: " ") == "We shouldn't try")
    }

    @Test("Contracted negation without an auxiliary inserts and contracts do/does/did")
    func contractedDoSupport() async throws {
        #expect(MorphologyEngine.negate(["I","go"], contracted: true).joined(separator: " ") == "I don't go")
        #expect(MorphologyEngine.negate(["He","goes"], contracted: true).joined(separator: " ") == "He doesn't go")
        #expect(MorphologyEngine.negate(["You","went"], contracted: true).joined(separator: " ") == "You didn't go")
    }
}
