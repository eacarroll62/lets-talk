// GermanRules.swift
import Foundation

struct GermanRules: MorphologyRules {
    func conjugate(lemma: String, person: MorphologyEngine.Person, number: MorphologyEngine.Number, tense: MorphologyEngine.Tense, aspect: MorphologyEngine.Aspect, voice: MorphologyEngine.Voice, overrides: MorphologyOverrides) -> String {
        // MVP: pass-through for German; apply overrides or real conjugation in future.
        return lemma
    }
    
    let languageCode: String

    func supports(_ feature: MorphologyEngine.Feature) -> Bool { true }

    // MARK: - Verbs (MVP: pass-through with override support)

    func toIng(_ verb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.ing[verb.lowercased()] { return GermanRules.matchCase(of: verb, to: o) }
        return verb
    }

    func toPast(_ verb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.past[verb.lowercased()] { return GermanRules.matchCase(of: verb, to: o) }
        return verb
    }

    func to3rdPersonS(_ verb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.thirdS[verb.lowercased()] { return GermanRules.matchCase(of: verb, to: o) }
        return verb
    }

    func baseVerb(_ verb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.base[verb.lowercased()] { return GermanRules.matchCase(of: verb, to: o) }
        return verb
    }

    // MARK: - Nouns (MVP: pass-through with overrides)

    func pluralize(_ noun: String, conservative: Bool, overrides: MorphologyOverrides) -> String {
        let lower = noun.lowercased()
        if overrides.doNotChange.contains(lower) { return noun }
        if let o = overrides.plural[lower] { return GermanRules.matchCase(of: noun, to: o) }
        if conservative && EnglishRules.isProperName(noun) { return noun }
        return noun
    }

    func singularize(_ noun: String, conservative: Bool, overrides: MorphologyOverrides) -> String {
        let lower = noun.lowercased()
        if overrides.doNotChange.contains(lower) { return noun }
        if let o = overrides.singular[lower] { return GermanRules.matchCase(of: noun, to: o) }
        if conservative && EnglishRules.isProperName(noun) { return noun }
        return noun
    }

    func possessive(_ noun: String, overrides: MorphologyOverrides) -> String {
        // German doesn’t use English ’s; pass through.
        return noun
    }

    // MARK: - Adjectives/Adverbs (MVP with overrides)

    func toComparative(_ adjective: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.comparative[adjective.lowercased()] { return GermanRules.matchCase(of: adjective, to: o) }
        return adjective
    }

    func toSuperlative(_ adjective: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.superlative[adjective.lowercased()] { return GermanRules.matchCase(of: adjective, to: o) }
        return adjective
    }

    func toAdverb(_ adjective: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.adverb[adjective.lowercased()] { return GermanRules.matchCase(of: adjective, to: o) }
        return adjective
    }

    func adverbToAdjective(_ adverb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.adjective[adverb.lowercased()] { return GermanRules.matchCase(of: adverb, to: o) }
        return adverb
    }

    // MARK: - Clauses (MVP: pass-through)

    func negate(_ words: [String], contracted: Bool) -> [String] {
        // German negation (“nicht/kein”) depends on structure; pass through for MVP.
        return words
    }

    func makeYesNoQuestion(_ words: [String]) -> [String] {
        // German uses verb-first inversion; pass through for MVP.
        return words
    }

    func makeWhQuestion(_ words: [String], wh: String) -> [String] {
        var out: [String] = []
        out.append(GermanRules.capitalizeFirst(wh))
        out.append(contentsOf: words)
        return out
    }

    // MARK: - Articles

    func indefiniteArticle(for word: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.article[word.lowercased()] { return o }
        // Placeholder: “ein” (gender-agnostic default for MVP)
        return "ein"
    }

    func determiner(for nounPhrase: String, preference: MorphologyEngine.DeterminerPreference, overrides: MorphologyOverrides) -> String {
        if let o = overrides.article[nounPhrase.lowercased()] { return o }
        let head = EnglishRules.headNoun(of: nounPhrase)
        if EnglishRules.isProperName(head) { return "" }
        switch preference {
        case .definite: return "der"
        case .indefinite: return indefiniteArticle(for: head, overrides: overrides)
        case .none: return ""
        }
    }

    // MARK: - Pronouns

    func pronounVariants(_ token: String) -> [String] {
        // MVP: pass-through
        return [token]
    }

    // MARK: - Utilities

    static func matchCase(of original: String, to replacement: String) -> String {
        if original == original.uppercased() { return replacement.uppercased() }
        if let first = original.first, String(first) == String(first).uppercased() {
            guard !replacement.isEmpty else { return replacement }
            let firstRep = replacement.prefix(1).uppercased()
            return firstRep + replacement.dropFirst()
        }
        return replacement
    }

    static func capitalizeFirst(_ word: String) -> String {
        guard let first = word.first else { return word }
        return String(first).uppercased() + word.dropFirst()
    }
}
