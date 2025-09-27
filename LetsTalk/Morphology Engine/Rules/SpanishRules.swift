// SpanishRules.swift
import Foundation

struct SpanishRules: MorphologyRules {
    func conjugate(lemma: String, person: MorphologyEngine.Person, number: MorphologyEngine.Number, tense: MorphologyEngine.Tense, aspect: MorphologyEngine.Aspect, voice: MorphologyEngine.Voice, overrides: MorphologyOverrides) -> String {
        // Placeholder: reuse English-style auxiliary scaffolding with Spanish verb surface forms pass-through.
        // This mirrors MorphologyEngine's current English conjugation logic so callers get consistent behavior.
        let base = lemma.lowercased()
        switch voice {
        case .active:
            switch aspect {
            case .simple:
                switch tense {
                case .present:
                    if person == .third && number == .singular {
                        return to3rdPersonS(base, overrides: overrides)
                    } else {
                        return base
                    }
                case .past:
                    return toPast(base, overrides: overrides)
                case .future:
                    return "will " + base
                }
            case .progressive:
                let be = EnglishRules.beForm(person: person, number: number, tense: tense)
                return be + " " + toIng(base, overrides: overrides)
            case .perfect:
                let have = EnglishRules.haveForm(person: person, number: number, tense: tense)
                return have + " " + EnglishRules.pastParticiple(base)
            case .perfectProgressive:
                let have = EnglishRules.haveForm(person: person, number: number, tense: tense)
                return have + " been " + toIng(base, overrides: overrides)
            }
        case .passive:
            switch aspect {
            case .simple:
                switch tense {
                case .present:
                    return EnglishRules.beForm(person: person, number: number, tense: .present) + " " + EnglishRules.pastParticiple(base)
                case .past:
                    return EnglishRules.beForm(person: person, number: number, tense: .past) + " " + EnglishRules.pastParticiple(base)
                case .future:
                    return "will be " + EnglishRules.pastParticiple(base)
                }
            case .progressive:
                switch tense {
                case .present:
                    return EnglishRules.beForm(person: person, number: number, tense: .present) + " being " + EnglishRules.pastParticiple(base)
                case .past:
                    return EnglishRules.beForm(person: person, number: number, tense: .past) + " being " + EnglishRules.pastParticiple(base)
                case .future:
                    return "will be being " + EnglishRules.pastParticiple(base)
                }
            case .perfect:
                switch tense {
                case .present:
                    return EnglishRules.haveForm(person: person, number: number, tense: .present) + " been " + EnglishRules.pastParticiple(base)
                case .past:
                    return EnglishRules.haveForm(person: person, number: number, tense: .past) + " been " + EnglishRules.pastParticiple(base)
                case .future:
                    return "will have been " + EnglishRules.pastParticiple(base)
                }
            case .perfectProgressive:
                switch tense {
                case .present:
                    return EnglishRules.haveForm(person: person, number: number, tense: .present) + " been being " + EnglishRules.pastParticiple(base)
                case .past:
                    return EnglishRules.haveForm(person: person, number: number, tense: .past) + " been being " + EnglishRules.pastParticiple(base)
                case .future:
                    return "will have been being " + EnglishRules.pastParticiple(base)
                }
            }
        }
    }
    
    let languageCode: String

    func supports(_ feature: MorphologyEngine.Feature) -> Bool { true }

    // MARK: - Verbs (placeholder: pass-through with override support)

    func toIng(_ verb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.ing[verb.lowercased()] { return SpanishRules.matchCase(of: verb, to: o) }
        return verb
    }

    func toPast(_ verb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.past[verb.lowercased()] { return SpanishRules.matchCase(of: verb, to: o) }
        return verb
    }

    func to3rdPersonS(_ verb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.thirdS[verb.lowercased()] { return SpanishRules.matchCase(of: verb, to: o) }
        return verb
    }

    func baseVerb(_ verb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.base[verb.lowercased()] { return SpanishRules.matchCase(of: verb, to: o) }
        return verb
    }

    // MARK: - Nouns (basic Spanish rules)

    func pluralize(_ noun: String, conservative: Bool, overrides: MorphologyOverrides) -> String {
        let lower = noun.lowercased()
        if overrides.doNotChange.contains(lower) { return noun }
        if let o = overrides.plural[lower] { return SpanishRules.matchCase(of: noun, to: o) }

        if conservative && EnglishRules.isProperName(noun) { return noun }

        guard let last = lower.last else { return noun }
        // z -> ces
        if last == "z" {
            let stem = String(lower.dropLast())
            return SpanishRules.matchCase(of: noun, to: stem + "ces")
        }
        // vowel + s
        if "aeiouáéíóú".contains(last) {
            return SpanishRules.matchCase(of: noun, to: lower + "s")
        }
        // default: +es
        return SpanishRules.matchCase(of: noun, to: lower + "es")
    }

    func singularize(_ noun: String, conservative: Bool, overrides: MorphologyOverrides) -> String {
        let lower = noun.lowercased()
        if overrides.doNotChange.contains(lower) { return noun }
        if let o = overrides.singular[lower] { return SpanishRules.matchCase(of: noun, to: o) }

        if conservative && EnglishRules.isProperName(noun) { return noun }

        if lower.hasSuffix("ces"), lower.count > 3 {
            // luces -> luz
            let stem = String(lower.dropLast(3))
            return SpanishRules.matchCase(of: noun, to: stem + "z")
        }
        if lower.hasSuffix("es"), lower.count > 2 {
            // papel -> papeles -> papel
            let stem = String(lower.dropLast(2))
            return SpanishRules.matchCase(of: noun, to: stem)
        }
        if lower.hasSuffix("s"), lower.count > 1 {
            let stem = String(lower.dropLast(1))
            return SpanishRules.matchCase(of: noun, to: stem)
        }
        return noun
    }

    func possessive(_ noun: String, overrides: MorphologyOverrides) -> String {
        // Spanish doesn't use possessive 's; pass through.
        return noun
    }

    // MARK: - Adjectives/Adverbs (placeholder with overrides)

    func toComparative(_ adjective: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.comparative[adjective.lowercased()] { return SpanishRules.matchCase(of: adjective, to: o) }
        return adjective
    }

    func toSuperlative(_ adjective: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.superlative[adjective.lowercased()] { return SpanishRules.matchCase(of: adjective, to: o) }
        return adjective
    }

    func toAdverb(_ adjective: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.adverb[adjective.lowercased()] { return SpanishRules.matchCase(of: adjective, to: o) }
        return adjective
    }

    func adverbToAdjective(_ adverb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.adjective[adverb.lowercased()] { return SpanishRules.matchCase(of: adverb, to: o) }
        return adverb
    }

    // MARK: - Clauses (placeholder: pass-through)

    func negate(_ words: [String], contracted: Bool) -> [String] {
        // Minimal: if there is at least one word, insert "no" before the last token (verb placeholder).
        guard !words.isEmpty else { return ["no"] }
        var out = words
        out.insert("no", at: max(0, out.count - 1))
        return out
    }

    func makeYesNoQuestion(_ words: [String]) -> [String] {
        // Spanish uses intonation; return unchanged.
        return words
    }

    func makeWhQuestion(_ words: [String], wh: String) -> [String] {
        // Prepend WH word capitalized as a simple heuristic.
        var out: [String] = []
        out.append(SpanishRules.capitalizeFirst(wh))
        out.append(contentsOf: words)
        return out
    }

    // MARK: - Articles

    func indefiniteArticle(for word: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.article[word.lowercased()] { return o }
        // Default to "un" as a gender-neutral placeholder.
        return "un"
    }

    func determiner(for nounPhrase: String, preference: MorphologyEngine.DeterminerPreference, overrides: MorphologyOverrides) -> String {
        if let o = overrides.article[nounPhrase.lowercased()] { return o }
        let head = EnglishRules.headNoun(of: nounPhrase)
        let lower = head.lowercased()
        if EnglishRules.isProperName(head) { return "" }

        let isPlural = SpanishRules.looksPlural(lower)
        switch preference {
        case .definite:
            return isPlural ? "los" : "el"
        case .indefinite:
            return isPlural ? "unos" : "un"
        case .none:
            return ""
        }
    }

    // MARK: - Pronouns

    func pronounVariants(_ token: String) -> [String] {
        // Placeholder: return token as the only variant.
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

    static func looksPlural(_ lower: String) -> Bool {
        // Very simple heuristic: words ending with "s" are plural (common in Spanish).
        return lower.hasSuffix("s")
    }
}
