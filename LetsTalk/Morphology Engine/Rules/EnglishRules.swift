//
//  EnglishRules.swift
//  LetsTalk
//
//  Created by Eric Carroll on 9/23/25.
//

import Foundation

struct EnglishRules: MorphologyRules {
    let languageCode: String

    func supports(_ feature: MorphologyEngine.Feature) -> Bool { true }

    // MARK: Verbs

    func toIng(_ verb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.ing[verb.lowercased()] { return EnglishRules.matchCase(of: verb, to: o) }
        let lower = verb.lowercased()
        if let irr = EnglishRules.irregularParticiple[lower] { return EnglishRules.matchCase(of: verb, to: irr) }
        return EnglishRules.matchCase(of: verb, to: EnglishRules.regularIng(lower))
    }

    func toPast(_ verb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.past[verb.lowercased()] { return EnglishRules.matchCase(of: verb, to: o) }
        let lower = verb.lowercased()
        if let irr = EnglishRules.irregularPast[lower] { return EnglishRules.matchCase(of: verb, to: irr) }
        return EnglishRules.matchCase(of: verb, to: EnglishRules.regularPast(lower))
    }

    func to3rdPersonS(_ verb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.thirdS[verb.lowercased()] { return EnglishRules.matchCase(of: verb, to: o) }
        let lower = verb.lowercased()
        if let irr = EnglishRules.irregular3rd[lower] { return EnglishRules.matchCase(of: verb, to: irr) }
        return EnglishRules.matchCase(of: verb, to: EnglishRules.regular3rd(lower))
    }

    func baseVerb(_ verb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.base[verb.lowercased()] { return EnglishRules.matchCase(of: verb, to: o) }
        let lower = verb.lowercased()
        if let lemma = EnglishRules.irregularLemma[lower] { return EnglishRules.matchCase(of: verb, to: lemma) }

        if lower.hasSuffix("ing") {
            var stem = String(lower.dropLast(3))
            if EnglishRules.hasDoubledFinalConsonant(stem) { stem.removeLast() }
            return EnglishRules.matchCase(of: verb, to: stem)
        }
        if lower.hasSuffix("ied") {
            let stem = String(lower.dropLast(3)) + "y"
            return EnglishRules.matchCase(of: verb, to: stem)
        }
        if lower.hasSuffix("ed") {
            if String(lower.dropLast()).hasSuffix("e") {
                let stem = String(lower.dropLast(1))
                return EnglishRules.matchCase(of: verb, to: stem)
            } else {
                var stem = String(lower.dropLast(2))
                if EnglishRules.hasDoubledFinalConsonant(stem) { stem.removeLast() }
                return EnglishRules.matchCase(of: verb, to: stem)
            }
        }
        if lower.hasSuffix("ies") {
            let stem = String(lower.dropLast(3)) + "y"
            return EnglishRules.matchCase(of: verb, to: stem)
        }
        if lower.hasSuffix("es") {
            let stem = String(lower.dropLast(2))
            if EnglishRules.takesES(stem) { return EnglishRules.matchCase(of: verb, to: stem) }
            return EnglishRules.matchCase(of: verb, to: String(lower.dropLast()))
        }
        if lower.hasSuffix("s") {
            return EnglishRules.matchCase(of: verb, to: String(lower.dropLast()))
        }
        return verb
    }

    // MARK: Nouns

    func pluralize(_ noun: String, conservative: Bool, overrides: MorphologyOverrides) -> String {
        let lower = noun.lowercased()
        if overrides.doNotChange.contains(lower) { return noun }
        if let o = overrides.plural[lower] { return EnglishRules.matchCase(of: noun, to: o) }

        if conservative && EnglishRules.isProperName(noun) { return noun }
        if EnglishRules.invariantPlurals.contains(lower) || EnglishRules.uncountables.contains(lower) { return noun }
        if let irr = EnglishRules.irregularPlurals[lower] { return EnglishRules.matchCase(of: noun, to: irr) }

        if lower.hasSuffix("y"), let prev = lower.dropLast().last, !"aeiou".contains(prev) {
            return EnglishRules.matchCase(of: noun, to: String(lower.dropLast()) + "ies")
        }
        if lower.hasSuffix("f") || lower.hasSuffix("fe") {
            if EnglishRules.fFeTakesS.contains(lower) {
                return EnglishRules.matchCase(of: noun, to: lower + "s")
            } else {
                if lower.hasSuffix("fe") {
                    return EnglishRules.matchCase(of: noun, to: String(lower.dropLast(2)) + "ves")
                } else {
                    return EnglishRules.matchCase(of: noun, to: String(lower.dropLast(1)) + "ves")
                }
            }
        }
        if lower.hasSuffix("us"), EnglishRules.classicalUsToI.contains(lower) {
            return EnglishRules.matchCase(of: noun, to: String(lower.dropLast(2)) + "i")
        }
        if lower.hasSuffix("is"), EnglishRules.classicalIsToEs.contains(lower) {
            return EnglishRules.matchCase(of: noun, to: String(lower.dropLast(2)) + "es")
        }
        if (lower.hasSuffix("on") || lower.hasSuffix("um")), EnglishRules.classicalOnUmToA.contains(lower) {
            return EnglishRules.matchCase(of: noun, to: String(lower.dropLast(2)) + "a")
        }
        if (lower.hasSuffix("ix") || lower.hasSuffix("ex")), EnglishRules.classicalIxExToIces.contains(lower) {
            return EnglishRules.matchCase(of: noun, to: String(lower.dropLast(2)) + "ices")
        }
        if lower.hasSuffix("o") {
            if EnglishRules.oTakesS.contains(lower) {
                return EnglishRules.matchCase(of: noun, to: lower + "s")
            } else {
                return EnglishRules.matchCase(of: noun, to: lower + "es")
            }
        }
        if lower.hasSuffix("s") || lower.hasSuffix("x") || lower.hasSuffix("z") || lower.hasSuffix("ch") || lower.hasSuffix("sh") {
            return EnglishRules.matchCase(of: noun, to: lower + "es")
        }
        if conservative {
            if lower.hasSuffix("y"), let prev = lower.dropLast().last, "aeiou".contains(prev) { return noun }
        }
        return EnglishRules.matchCase(of: noun, to: lower + "s")
    }

    func singularize(_ noun: String, conservative: Bool, overrides: MorphologyOverrides) -> String {
        let lower = noun.lowercased()
        if overrides.doNotChange.contains(lower) { return noun }
        if let o = overrides.singular[lower] { return EnglishRules.matchCase(of: noun, to: o) }

        if conservative && EnglishRules.isProperName(noun) { return noun }
        if EnglishRules.invariantPlurals.contains(lower) || EnglishRules.uncountables.contains(lower) { return noun }
        if let base = EnglishRules.irregularSingulars[lower] { return EnglishRules.matchCase(of: noun, to: base) }

        if lower.hasSuffix("ies"), lower.count > 3 {
            let stem = String(lower.dropLast(3)) + "y"
            return EnglishRules.matchCase(of: noun, to: stem)
        }
        if lower.hasSuffix("ves"), lower.count > 3 {
            let stem = String(lower.dropLast(3))
            if EnglishRules.takesFeWhenSingular.contains(stem) {
                return EnglishRules.matchCase(of: noun, to: stem + "fe")
            } else {
                return EnglishRules.matchCase(of: noun, to: stem + "f")
            }
        }
        if lower.hasSuffix("i"), EnglishRules.classicalIToUs.contains(lower) {
            return EnglishRules.matchCase(of: noun, to: String(lower.dropLast(1)) + "us")
        }
        if lower.hasSuffix("es"), EnglishRules.classicalEsToIs.contains(lower) {
            return EnglishRules.matchCase(of: noun, to: String(lower.dropLast(2)) + "is")
        }
        if lower.hasSuffix("a"), EnglishRules.classicalAToOnUm.contains(lower) {
            let base = String(lower.dropLast(1))
            if EnglishRules.classicalAToOn.contains(lower) {
                return EnglishRules.matchCase(of: noun, to: base + "on")
            } else {
                return EnglishRules.matchCase(of: noun, to: base + "um")
            }
        }
        if lower.hasSuffix("ices"), EnglishRules.classicalIcesToIxEx.contains(lower) {
            let base = String(lower.dropLast(4))
            if EnglishRules.classicalIcesToIx.contains(lower) {
                return EnglishRules.matchCase(of: noun, to: base + "ix"
                )
            } else {
                return EnglishRules.matchCase(of: noun, to: base + "ex")
            }
        }
        if lower.hasSuffix("es"), lower.count > 2 {
            let stem = String(lower.dropLast(2))
            return EnglishRules.matchCase(of: noun, to: stem)
        }
        if lower.hasSuffix("s"), lower.count > 1 {
            return EnglishRules.matchCase(of: noun, to: String(lower.dropLast()))
        }
        return noun
    }

    func possessive(_ noun: String, overrides: MorphologyOverrides) -> String {
        let lower = noun.lowercased()
        if lower.isEmpty { return noun }
        if let _ = EnglishRules.irregularSingulars[lower], !lower.hasSuffix("s") { return EnglishRules.matchCase(of: noun, to: lower + "'s") }
        if lower.hasSuffix("s") { return EnglishRules.matchCase(of: noun, to: lower + "'") }
        return EnglishRules.matchCase(of: noun, to: lower + "'s")
    }

    // MARK: Adjectives/Adverbs

    func toComparative(_ adjective: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.comparative[adjective.lowercased()] { return EnglishRules.matchCase(of: adjective, to: o) }
        let lower = adjective.lowercased()
        if let irr = EnglishRules.irregularComparatives[lower] { return EnglishRules.matchCase(of: adjective, to: irr) }
        if lower.hasSuffix("y"), let prev = lower.dropLast().last, !"aeiou".contains(prev) {
            return EnglishRules.matchCase(of: adjective, to: String(lower.dropLast()) + "ier")
        }
        if EnglishRules.syllableCount(lower) == 1 && lower.count <= 5 {
            if EnglishRules.shouldDoubleFinalConsonant(lower) {
                return EnglishRules.matchCase(of: adjective, to: lower + String(lower.last!) + "er")
            }
            return EnglishRules.matchCase(of: adjective, to: lower + "er")
        }
        if EnglishRules.syllableCount(lower) == 2 && lower.hasSuffix("y") {
            return EnglishRules.matchCase(of: adjective, to: String(lower.dropLast()) + "ier")
        }
        return EnglishRules.matchCase(of: adjective, to: "more " + lower)
    }

    func toSuperlative(_ adjective: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.superlative[adjective.lowercased()] { return EnglishRules.matchCase(of: adjective, to: o) }
        let lower = adjective.lowercased()
        if let irr = EnglishRules.irregularSuperlatives[lower] { return EnglishRules.matchCase(of: adjective, to: irr) }
        if lower.hasSuffix("y"), let prev = lower.dropLast().last, !"aeiou".contains(prev) {
            return EnglishRules.matchCase(of: adjective, to: String(lower.dropLast()) + "iest")
        }
        if EnglishRules.syllableCount(lower) == 1 && lower.count <= 5 {
            if EnglishRules.shouldDoubleFinalConsonant(lower) {
                return EnglishRules.matchCase(of: adjective, to: lower + String(lower.last!) + "est")
            }
            return EnglishRules.matchCase(of: adjective, to: lower + "est")
        }
        if EnglishRules.syllableCount(lower) == 2 && lower.hasSuffix("y") {
            return EnglishRules.matchCase(of: adjective, to: String(lower.dropLast()) + "iest")
        }
        return EnglishRules.matchCase(of: adjective, to: "most " + lower)
    }

    func toAdverb(_ adjective: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.adverb[adjective.lowercased()] { return EnglishRules.matchCase(of: adjective, to: o) }
        let lower = adjective.lowercased()
        if let irr = EnglishRules.irregularAdjectiveToAdverb[lower] { return EnglishRules.matchCase(of: adjective, to: irr) }
        if lower.hasSuffix("y"), let prev = lower.dropLast().last, !"aeiou".contains(prev) {
            return EnglishRules.matchCase(of: adjective, to: String(lower.dropLast()) + "ily")
        }
        if lower.hasSuffix("ic") { return EnglishRules.matchCase(of: adjective, to: lower + "ally") }
        if lower.hasSuffix("le"), let prev = lower.dropLast(2).last, !"aeiou".contains(prev) {
            return EnglishRules.matchCase(of: adjective, to: String(lower.dropLast()) + "y")
        }
        return EnglishRules.matchCase(of: adjective, to: lower + "ly")
    }

    func adverbToAdjective(_ adverb: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.adjective[adverb.lowercased()] { return EnglishRules.matchCase(of: adverb, to: o) }
        let lower = adverb.lowercased()
        if let irr = EnglishRules.irregularAdverbToAdjective[lower] { return EnglishRules.matchCase(of: adverb, to: irr) }
        if lower.hasSuffix("ily") { return EnglishRules.matchCase(of: adverb, to: String(lower.dropLast(3)) + "y") }
        if lower.hasSuffix("ally") { return EnglishRules.matchCase(of: adverb, to: String(lower.dropLast(4)) + "ic") }
        if lower.hasSuffix("ly") { return EnglishRules.matchCase(of: adverb, to: String(lower.dropLast(2))) }
        return adverb
    }

    // MARK: Clauses

    func negate(_ words: [String], contracted: Bool) -> [String] {
        guard !words.isEmpty else { return ["do", contracted ? "n't" : "not"] }
        if let auxIndex = words.firstIndex(where: { EnglishRules.auxiliaries.contains($0.lowercased()) }) {
            var out = words
            let auxLower = words[auxIndex].lowercased()
            if contracted, let contraction = EnglishRules.contractionFor(aux: auxLower) {
                out[auxIndex] = EnglishRules.contractedForm(aux: auxLower, original: out[auxIndex], contraction: contraction)
            } else {
                out.insert("not", at: auxIndex + 1)
            }
            return out
        }
        var out = words
        let main = words.last ?? ""
        let subjWords = Array(words.dropLast())
        let mainLower = main.lowercased()
        let looksPast = EnglishRules.isPastForm(mainLower)
        let base = baseVerb(mainLower, overrides: MorphologyOverrides())
        let (person, number) = EnglishRules.personNumber(for: subjWords)
        let doAux: String = looksPast ? "did" : ((person == .third && number == .singular) ? "does" : "do")
        out.removeLast()
        if contracted, let contraction = EnglishRules.contractionFor(aux: doAux) {
            out.append(EnglishRules.contractedForm(aux: doAux, original: doAux, contraction: contraction))
        } else {
            out.append(doAux)
            out.append("not")
        }
        out.append(base)
        return out
    }

    func makeYesNoQuestion(_ words: [String]) -> [String] {
        guard !words.isEmpty else { return [] }
        if let auxIndex = words.firstIndex(where: { EnglishRules.auxiliaries.contains($0.lowercased()) }) {
            var out = words
            let aux = out.remove(at: auxIndex)
            // Decapitalize the first subject token if it's a pronoun (except "I")
            if !out.isEmpty {
                let first = out[0]
                let lower = first.lowercased()
                if lower != "i", EnglishRules.pronounMap[lower] != nil {
                    out[0] = EnglishRules.decapitalizeFirst(first)
                }
            }
            out.insert(EnglishRules.capitalizeFirst(aux), at: 0)
            return out
        }
        let main = words.last ?? ""
        var subject = Array(words.dropLast())
        let looksPast = EnglishRules.isPastForm(main.lowercased())
        let (person, number) = EnglishRules.personNumber(for: subject)
        let doAux = looksPast ? "did" : ((person == .third && number == .singular) ? "does" : "do")
        let base = baseVerb(main, overrides: MorphologyOverrides())
        // Decapitalize the first subject token if it's a pronoun (except "I")
        if !subject.isEmpty {
            let first = subject[0]
            let lower = first.lowercased()
            if lower != "i", EnglishRules.pronounMap[lower] != nil {
                subject[0] = EnglishRules.decapitalizeFirst(first)
            }
        }
        var out: [String] = []
        out.append(EnglishRules.capitalizeFirst(doAux))
        out.append(contentsOf: subject)
        out.append(base)
        return out
    }

    func makeWhQuestion(_ words: [String], wh: String) -> [String] {
        guard !words.isEmpty else { return [wh.capitalized] }
        var inverted = makeYesNoQuestion(words)
        if !inverted.isEmpty { inverted[0] = EnglishRules.decapitalizeFirst(inverted[0]) }
        var out: [String] = []
        out.append(EnglishRules.capitalizeFirst(wh))
        out.append(contentsOf: inverted)
        return out
    }

    // MARK: Articles

    func indefiniteArticle(for word: String, overrides: MorphologyOverrides) -> String {
        if let o = overrides.article[word.lowercased()] { return o }
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) else { return "a" }
        return EnglishRules.startsWithVowelSound(first) ? "an" : "a"
    }

    func determiner(for nounPhrase: String, preference: MorphologyEngine.DeterminerPreference, overrides: MorphologyOverrides) -> String {
        if let o = overrides.article[nounPhrase.lowercased()] { return o }
        let head = EnglishRules.headNoun(of: nounPhrase)
        let lowerHead = head.lowercased()
        if EnglishRules.isProperName(head) { return "" }
        switch preference {
        case .definite: return "the"
        case .indefinite:
                if EnglishRules.invariantPlurals.contains(lowerHead) || EnglishRules.uncountables.contains(lowerHead) { return "some" }
                if EnglishRules.looksPlural(lowerHead) && EnglishRules.irregularSingulars[lowerHead] == nil { return "some" }
            return indefiniteArticle(for: head, overrides: overrides)
        case .none: return ""
        }
    }

    // MARK: Pronouns

    func pronounVariants(_ token: String) -> [String] {
        let lower = token.lowercased()
        guard let forms = EnglishRules.pronounMap[lower] else { return [token] }

        // If ALL CAPS (length > 1), return ALL CAPS variants (keep acronyms style).
        if token == token.uppercased(), token.count > 1 {
            return forms.map { $0.uppercased() }
        }

        // If Titlecase (first uppercase, rest not uppercase) and length > 1,
        // capitalize only the nominative form; keep other forms lowercase.
        let isTitlecase: Bool = {
            guard token.count > 1, let first = token.first else { return false }
            let rest = token.dropFirst()
            let firstIsUpper = String(first) == String(first).uppercased()
            let restHasUpper = rest.rangeOfCharacter(from: CharacterSet.uppercaseLetters) != nil
            return firstIsUpper && !restHasUpper
        }()
        if isTitlecase {
            return forms.enumerated().map { idx, form in
                idx == 0 ? EnglishRules.capitalizeFirst(form) : form.lowercased()
            }
        }

        // Default: return the canonical forms from the map (already lowercase except "I").
        return forms
    }

    // MARK: Conjugation

    func conjugate(lemma: String,
                   person: MorphologyEngine.Person,
                   number: MorphologyEngine.Number,
                   tense: MorphologyEngine.Tense,
                   aspect: MorphologyEngine.Aspect,
                   voice: MorphologyEngine.Voice,
                   overrides: MorphologyOverrides) -> String {
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

    // MARK: Internals (English)

    // Utilities and data are provided at the end of this file via extension EnglishRules { … }
}

