// MorphologyEngine.swift
// Phase 1: Rules-protocol split + language-scoped overrides + NLTokenizer tokenization.
// Keeps static façade for backward compatibility with existing call sites.

import Foundation
import NaturalLanguage

// MARK: - Overrides

struct MorphologyOverrides: Sendable, Codable {
    // Language-scoped override dictionaries, all keys are lowercased.
    var doNotChange: Set<String> = []

    var plural: [String: String] = [:]       // noun -> plural
    var singular: [String: String] = [:]     // plural -> singular

    var past: [String: String] = [:]         // verb -> past
    var thirdS: [String: String] = [:]       // verb -> 3rd person singular
    var ing: [String: String] = [:]          // verb -> -ing
    var base: [String: String] = [:]         // inflected -> base/lemma

    var comparative: [String: String] = [:]  // adj -> comparative
    var superlative: [String: String] = [:]  // adj -> superlative
    var adverb: [String: String] = [:]       // adj -> adverb
    var adjective: [String: String] = [:]    // adv -> adjective

    var article: [String: String] = [:]      // head word or phrase -> "a"/"an"/"the"/"some"/""
}

// Simple language-scoped store with UserDefaults persistence.
final class OverridesStore {
    static let shared = OverridesStore()

    private var byLanguage: [String: MorphologyOverrides] = [:]
    private let lock = NSLock()
    private let defaults = UserDefaults.standard
    private let keyPrefix = "MorphOverrides."

    // Public API

    func setOverrides(_ overrides: MorphologyOverrides, for language: String) {
        lock.lock(); defer { lock.unlock() }
        let key = languageKey(language)
        byLanguage[key] = overrides
        persist(overrides, for: key)
    }

    func update(_ language: String, mutate: (inout MorphologyOverrides) -> Void) {
        lock.lock(); defer { lock.unlock() }
        let key = languageKey(language)
        var current = byLanguage[key] ?? load(for: key) ?? MorphologyOverrides()
        mutate(&current)
        byLanguage[key] = current
        persist(current, for: key)
    }

    func get(for language: String) -> MorphologyOverrides {
        lock.lock(); defer { lock.unlock() }
        let key = languageKey(language)
        if let cached = byLanguage[key] { return cached }
        if let loaded = load(for: key) {
            byLanguage[key] = loaded
            return loaded
        }
        let empty = MorphologyOverrides()
        byLanguage[key] = empty
        return empty
    }

    // Internals

    private func persist(_ overrides: MorphologyOverrides, for key: String) {
        do {
            let data = try JSONEncoder().encode(overrides)
            defaults.set(data, forKey: keyPrefix + key)
        } catch {
            // Best-effort; if encoding fails, we just keep it in-memory.
            #if DEBUG
            print("OverridesStore persist error for \(key): \(error)")
            #endif
        }
    }

    private func load(for key: String) -> MorphologyOverrides? {
        guard let data = defaults.data(forKey: keyPrefix + key) else { return nil }
        do {
            return try JSONDecoder().decode(MorphologyOverrides.self, from: data)
        } catch {
            #if DEBUG
            print("OverridesStore load error for \(key): \(error)")
            #endif
            return nil
        }
    }

    private func languageKey(_ raw: String) -> String {
        if let dash = raw.firstIndex(of: "-") {
            return String(raw[..<dash]).lowercased()
        }
        return raw.lowercased()
    }
}

// MARK: - Rules protocol

protocol MorphologyRules {
    var languageCode: String { get }
    func supports(_ feature: MorphologyEngine.Feature) -> Bool

    // Core transforms
    func toIng(_ verb: String, overrides: MorphologyOverrides) -> String
    func toPast(_ verb: String, overrides: MorphologyOverrides) -> String
    func to3rdPersonS(_ verb: String, overrides: MorphologyOverrides) -> String
    func baseVerb(_ verb: String, overrides: MorphologyOverrides) -> String

    func pluralize(_ noun: String, conservative: Bool, overrides: MorphologyOverrides) -> String
    func singularize(_ noun: String, conservative: Bool, overrides: MorphologyOverrides) -> String
    func possessive(_ noun: String, overrides: MorphologyOverrides) -> String

    func toComparative(_ adjective: String, overrides: MorphologyOverrides) -> String
    func toSuperlative(_ adjective: String, overrides: MorphologyOverrides) -> String
    func toAdverb(_ adjective: String, overrides: MorphologyOverrides) -> String
    func adverbToAdjective(_ adverb: String, overrides: MorphologyOverrides) -> String

    // Clause helpers (array-based)
    func negate(_ words: [String], contracted: Bool) -> [String]
    func makeYesNoQuestion(_ words: [String]) -> [String]
    func makeWhQuestion(_ words: [String], wh: String) -> [String]

    // Articles
    func indefiniteArticle(for word: String, overrides: MorphologyOverrides) -> String
    func determiner(for nounPhrase: String, preference: MorphologyEngine.DeterminerPreference, overrides: MorphologyOverrides) -> String

    // Pronouns
    func pronounVariants(_ token: String) -> [String]
}

// MARK: - English rules implementation

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
            out.insert(EnglishRules.capitalizeFirst(aux), at: 0)
            return out
        }
        let main = words.last ?? ""
        let subject = Array(words.dropLast())
        let looksPast = EnglishRules.isPastForm(main.lowercased())
        let (person, number) = EnglishRules.personNumber(for: subject)
        let doAux = looksPast ? "did" : ((person == .third && number == .singular) ? "does" : "do")
        let base = baseVerb(main, overrides: MorphologyOverrides())
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
        if token == token.uppercased() { return forms.map { $0.uppercased() } }
        let isCapitalized: Bool = {
            guard let first = token.first else { return false }
            return String(first) == String(first).uppercased()
                && token.dropFirst().rangeOfCharacter(from: CharacterSet.uppercaseLetters) == nil
        }()
        if isCapitalized {
            return forms.map { form in
                if form == "I" { return "I" }
                guard let f = form.first else { return form }
                return String(f).uppercased() + form.dropFirst()
            }
        }
        return forms
    }

    // MARK: Internals (English)

    // Utilities and data are provided at the end of this file via extension EnglishRules { … }
}

// MARK: - Engine façade

final class MorphologyEngine {

    enum Feature {
        case verbs, nouns, adjectivesAdverbs, clauses, articles, pronouns, tokenization
    }

    enum Person { case first, second, third }
    enum Number { case singular, plural }
    enum Tense { case present, past, future }
    enum Aspect { case simple, progressive, perfect, perfectProgressive }
    enum Voice { case active, passive }
    enum DeterminerPreference { case definite, indefinite, none }

    // Shared singleton for backward compatibility
    static let shared = MorphologyEngine(languageCode: "en")

    // Instance state
    private(set) var languageCode: String
    private var rules: MorphologyRules

    init(languageCode: String) {
        self.languageCode = MorphologyEngine.primaryLanguage(from: languageCode)
        self.rules = MorphologyEngine.makeRules(for: self.languageCode)
    }

    // Language control (static façade)
    static func setLanguage(_ code: String) {
        shared.setLanguage(code)
    }

    func setLanguage(_ code: String) {
        let primary = MorphologyEngine.primaryLanguage(from: code)
        languageCode = primary
        rules = MorphologyEngine.makeRules(for: primary)
    }

    private static func makeRules(for primaryLanguage: String) -> MorphologyRules {
        switch primaryLanguage {
        case "en": return EnglishRules(languageCode: "en")
        default:
            // Placeholder: pass-through rules for unsupported languages
            return EnglishRules(languageCode: "en") // keep English behavior as safe default for now
        }
    }

    private static func primaryLanguage(from raw: String) -> String {
        if let dash = raw.firstIndex(of: "-") { return String(raw[..<dash]).lowercased() }
        return raw.lowercased()
    }

    // MARK: - Static façade (unchanged API)

    static func toIng(_ verb: String) -> String { shared.toIng(verb) }
    static func toPast(_ verb: String) -> String { shared.toPast(verb) }
    static func to3rdPersonS(_ verb: String) -> String { shared.to3rdPersonS(verb) }
    static func baseVerb(_ verb: String) -> String { shared.baseVerb(verb) }

    static func pluralize(_ noun: String, conservative: Bool = false) -> String { shared.pluralize(noun, conservative: conservative) }
    static func singularize(_ noun: String, conservative: Bool = false) -> String { shared.singularize(noun, conservative: conservative) }
    static func possessive(_ noun: String) -> String { shared.possessive(noun) }

    static func toComparative(_ adjective: String) -> String { shared.toComparative(adjective) }
    static func toSuperlative(_ adjective: String) -> String { shared.toSuperlative(adjective) }
    static func toAdverb(_ adjective: String) -> String { shared.toAdverb(adjective) }
    static func adverbToAdjective(_ adverb: String) -> String { shared.adverbToAdjective(adverb) }

    static func conjugate(lemma: String, person: Person, number: Number, tense: Tense, aspect: Aspect = .simple, voice: Voice = .active) -> String {
        shared.conjugate(lemma: lemma, person: person, number: number, tense: tense, aspect: aspect, voice: voice)
    }

    static func negate(_ words: [String], contracted: Bool = false) -> [String] { shared.negate(words, contracted: contracted) }
    static func makeYesNoQuestion(_ words: [String]) -> [String] { shared.makeYesNoQuestion(words) }
    static func makeWhQuestion(_ words: [String], wh: String) -> [String] { shared.makeWhQuestion(words, wh: wh) }

    static func negate(into text: String, contracted: Bool = false) -> String { shared.negate(into: text, contracted: contracted) }
    static func makeYesNoQuestion(into text: String) -> String { shared.makeYesNoQuestion(into: text) }
    static func makeWhQuestion(into text: String, wh: String) -> String { shared.makeWhQuestion(into: text, wh: wh) }

    static func replaceLastWord(in text: String, with transform: (String) -> String) -> String { shared.replaceLastWord(in: text, with: transform) }
    static func appendWord(_ word: String, to text: String) -> String { shared.appendWord(word, to: text) }
    static func insertNot(into text: String) -> String { shared.insertNot(into: text) }
    static func negateSimpleVerb(in text: String) -> String { shared.negateSimpleVerb(in: text) }
    static func lastWord(_ text: String) -> String? { shared.lastWord(text) }

    static func indefiniteArticle(for word: String) -> String { shared.indefiniteArticle(for: word) }
    static func determiner(for nounPhrase: String, preference: DeterminerPreference) -> String { shared.determiner(for: nounPhrase, preference: preference) }

    static func pronounVariants(_ token: String) -> [String] { shared.pronounVariants(token) }

    // Overrides API
    static func setOverrides(_ overrides: MorphologyOverrides, for language: String) {
        OverridesStore.shared.setOverrides(overrides, for: language)
    }

    static func updateOverrides(for language: String, mutate: (inout MorphologyOverrides) -> Void) {
        OverridesStore.shared.update(language, mutate: mutate)
    }

    // MARK: - Instance methods (delegate to rules + overrides)

    func toIng(_ verb: String) -> String {
        rules.toIng(verb, overrides: overrides())
    }
    func toPast(_ verb: String) -> String {
        rules.toPast(verb, overrides: overrides())
    }
    func to3rdPersonS(_ verb: String) -> String {
        rules.to3rdPersonS(verb, overrides: overrides())
    }
    func baseVerb(_ verb: String) -> String {
        rules.baseVerb(verb, overrides: overrides())
    }

    func pluralize(_ noun: String, conservative: Bool) -> String {
        rules.pluralize(noun, conservative: conservative, overrides: overrides())
    }
    func singularize(_ noun: String, conservative: Bool) -> String {
        rules.singularize(noun, conservative: conservative, overrides: overrides())
    }
    func possessive(_ noun: String) -> String {
        rules.possessive(noun, overrides: overrides())
    }

    func toComparative(_ adjective: String) -> String {
        rules.toComparative(adjective, overrides: overrides())
    }
    func toSuperlative(_ adjective: String) -> String {
        rules.toSuperlative(adjective, overrides: overrides())
    }
    func toAdverb(_ adjective: String) -> String {
        rules.toAdverb(adjective, overrides: overrides())
    }
    func adverbToAdjective(_ adverb: String) -> String {
        rules.adverbToAdjective(adverb, overrides: overrides())
    }

    func conjugate(lemma: String, person: Person, number: Number, tense: Tense, aspect: Aspect = .simple, voice: Voice = .active) -> String {
        // English-only detailed handling for now; future languages will plug in here.
        let base = lemma.lowercased()
        switch voice {
        case .active:
            switch aspect {
            case .simple:
                switch tense {
                case .present:
                    if person == .third && number == .singular {
                        return to3rdPersonS(base)
                    } else {
                        return base
                    }
                case .past:
                    return toPast(base)
                case .future:
                    return "will " + base
                }
            case .progressive:
                let be = EnglishRules.beForm(person: person, number: number, tense: tense)
                return be + " " + toIng(base)
            case .perfect:
                let have = EnglishRules.haveForm(person: person, number: number, tense: tense)
                return have + " " + EnglishRules.pastParticiple(base)
            case .perfectProgressive:
                let have = EnglishRules.haveForm(person: person, number: number, tense: tense)
                return have + " been " + toIng(base)
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

    func negate(_ words: [String], contracted: Bool) -> [String] {
        rules.negate(words, contracted: contracted)
    }
    func makeYesNoQuestion(_ words: [String]) -> [String] {
        rules.makeYesNoQuestion(words)
    }
    func makeWhQuestion(_ words: [String], wh: String) -> [String] {
        rules.makeWhQuestion(words, wh: wh)
    }

    func negate(into text: String, contracted: Bool) -> String {
        let words = MorphologyEngine.wordsFrom(text, language: languageCode)
        let out = negate(words, contracted: contracted)
        return out.joined(separator: " ")
    }
    func makeYesNoQuestion(into text: String) -> String {
        let words = MorphologyEngine.wordsFrom(text, language: languageCode)
        let out = makeYesNoQuestion(words)
        return out.joined(separator: " ")
    }
    func makeWhQuestion(into text: String, wh: String) -> String {
        let words = MorphologyEngine.wordsFrom(text, language: languageCode)
        let out = makeWhQuestion(words, wh: wh)
        return out.joined(separator: " ")
    }

    func replaceLastWord(in text: String, with transform: (String) -> String) -> String {
        let tokens = MorphologyEngine.tokenizeWords(in: text, language: languageCode)
        guard !tokens.isEmpty else { return text }
        for tok in tokens.reversed() {
            let (core, trail) = MorphologyEngine.splitTrailingPunctuation(tok.text)
            if !core.isEmpty {
                let transformed = transform(core)
                let replacement = transformed + trail
                return MorphologyEngine.replaceRange(in: text, range: tok.range, with: replacement)
            }
        }
        return text
    }

    func appendWord(_ word: String, to text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return word }
        return trimmed + " " + word
    }

    func insertNot(into text: String) -> String {
        let words = MorphologyEngine.wordsFrom(text, language: languageCode)
        let out = EnglishRules.insertNot(in: words)
        return out.joined(separator: " ")
    }

    func negateSimpleVerb(in text: String) -> String {
        let words = MorphologyEngine.wordsFrom(text, language: languageCode)
        let out = EnglishRules.negateSimpleVerb(in: words)
        return out.joined(separator: " ")
    }

    func lastWord(_ text: String) -> String? {
        let tokens = MorphologyEngine.tokenizeWords(in: text, language: languageCode)
        for tok in tokens.reversed() {
            let (core, _) = MorphologyEngine.splitTrailingPunctuation(tok.text)
            if !core.isEmpty { return core }
        }
        return nil
    }

    func indefiniteArticle(for word: String) -> String {
        rules.indefiniteArticle(for: word, overrides: overrides())
    }
    func determiner(for nounPhrase: String, preference: DeterminerPreference) -> String {
        rules.determiner(for: nounPhrase, preference: preference, overrides: overrides())
    }

    func pronounVariants(_ token: String) -> [String] {
        rules.pronounVariants(token)
    }

    // MARK: - Internals

    private func overrides() -> MorphologyOverrides {
        OverridesStore.shared.get(for: languageCode)
    }

    // Tokenization helpers
    private struct Token {
        let range: Range<String.Index>
        let text: String
    }

    private static func tokenizeWords(in text: String, language: String) -> [Token] {
        var tokens: [Token] = []
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        if #available(iOS 16.0, macOS 13.0, *) {
            tokenizer.setLanguage(NLLanguage(rawValue: language))
        }
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let piece = String(text[range])
            tokens.append(Token(range: range, text: piece))
            return true
        }
        return tokens
    }

    private static func wordsFrom(_ text: String, language: String) -> [String] {
        tokenizeWords(in: text, language: language)
            .map { token in
                let (core, _) = splitTrailingPunctuation(token.text)
                return core.isEmpty ? token.text : core
            }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func replaceRange(in text: String, range: Range<String.Index>, with replacement: String) -> String {
        var s = text
        s.replaceSubrange(range, with: replacement)
        return s
    }

    // Split trailing punctuation from token
    static func splitTrailingPunctuation(_ token: String) -> (String, String) {
        guard !token.isEmpty else { return ("", "") }
        var scalars = token.unicodeScalars
        var splitIndex = scalars.endIndex
        while splitIndex > scalars.startIndex {
            let prev = scalars.index(before: splitIndex)
            let s = scalars[prev]
            if CharacterSet.alphanumerics.contains(s) || s == "'" { break }
            splitIndex = prev
        }
        let core = String(scalars[..<splitIndex])
        let trail = String(scalars[splitIndex...])
        return (core, trail)
    }
}

// MARK: - English rule data and utilities (shared with EnglishRules)

extension EnglishRules {
    // Irregular verbs (expanded)
    static let irregularPast: [String: String] = [
        "arise":"arose","awake":"awoke","be":"was","bear":"bore","beat":"beat","become":"became","begin":"began",
        "bend":"bent","bet":"bet","bind":"bound","bite":"bit","bleed":"bled","blow":"blew","break":"broke",
        "bring":"brought","build":"built","burn":"burned","burst":"burst","buy":"bought","catch":"caught",
        "choose":"chose","come":"came","cost":"cost","cut":"cut","deal":"dealt","dig":"dug","do":"did",
        "draw":"drew","dream":"dreamed","drink":"drank","drive":"drove","eat":"ate","fall":"fell","feed":"fed",
        "feel":"felt","fight":"fought","find":"found","fly":"flew","forget":"forgot","forgive":"forgave",
        "freeze":"froze","get":"got","give":"gave","go":"went","grow":"grew","hang":"hung","have":"had",
        "hear":"heard","hide":"hid","hit":"hit","hold":"held","hurt":"hurt","keep":"kept","know":"knew",
        "lay":"laid","lead":"led","leave":"left","lend":"lent","let":"let","lie":"lay","light":"lit","lose":"lost",
        "make":"made","mean":"meant","meet":"met","pay":"paid","put":"put","read":"read","ride":"rode",
        "ring":"rang","rise":"rose","run":"ran","say":"said","see":"saw","sell":"sold","send":"sent","set":"set",
        "shake":"shook","shine":"shone","shoot":"shot","show":"showed","shut":"shut","sing":"sang","sit":"sat",
        "sleep":"slept","speak":"spoke","spend":"spent","stand":"stood","steal":"stole","swim":"swam",
        "take":"took","teach":"taught","tear":"tore","tell":"told","think":"thought","throw":"threw",
        "understand":"understood","wake":"woke","wear":"wore","win":"won","write":"wrote"
    ]

    static let irregularPastParticiple: [String: String] = [
        "arise":"arisen","awake":"awoken","be":"been","bear":"borne","beat":"beaten","become":"become",
        "begin":"begun","bend":"bent","bet":"bet","bind":"bound","bite":"bitten","bleed":"bled","blow":"blown",
        "break":"broken","bring":"brought","build":"built","burn":"burned","burst":"burst","buy":"bought",
        "catch":"caught","choose":"chosen","come":"come","cost":"cost","cut":"cut","deal":"dealt","dig":"dug",
        "do":"done","draw":"drawn","dream":"dreamed","drink":"drunk","drive":"driven","eat":"eaten","fall":"fallen",
        "feed":"fed","feel":"felt","fight":"fought","find":"found","fly":"flown","forget":"forgotten",
        "forgive":"forgiven","freeze":"frozen","get":"gotten","give":"given","go":"gone","grow":"grown",
        "hang":"hung","have":"had","hear":"heard","hide":"hidden","hit":"hit","hold":"held","hurt":"hurt",
        "keep":"kept","know":"known","lay":"laid","lead":"led","leave":"left","lend":"lent","let":"let",
        "lie":"lain","light":"lit","lose":"lost","make":"made","mean":"meant","meet":"met","pay":"paid",
        "put":"put","read":"read","ride":"ridden","ring":"rung","rise":"risen","run":"run","say":"said","see":"seen",
        "sell":"sold","send":"sent","set":"set","shake":"shaken","shine":"shone","shoot":"shot","show":"shown",
        "shut":"shut","sing":"sung","sit":"sat","sleep":"slept","speak":"spoken","spend":"spent","stand":"stood",
        "steal":"stolen","swim":"swum","take":"taken","teach":"taught","tear":"torn","tell":"told","think":"thought",
        "throw":"thrown","understand":"understood","wake":"woken","wear":"worn","win":"won","write":"written"
    ]

    static let irregularParticiple: [String: String] = [
        "be": "being", "see": "seeing", "flee": "fleeing", "die": "dying"
    ]

    static let irregular3rd: [String: String] = [
        "be": "is", "am": "is", "are": "is", "have": "has", "do": "does", "go": "goes",
        "say":"says","fly":"flies","try":"tries","deny":"denies","study":"studies"
    ]

    static let irregularLemma: [String: String] = {
        var m: [String:String] = [:]
        for (base, past) in irregularPast { m[past] = base }
        for (base, pp) in irregularPastParticiple { m[pp] = base }
        for (base, s3) in irregular3rd { m[s3] = base }
        m["was"] = "be"; m["were"] = "be"; m["is"] = "be"; m["am"] = "be"; m["are"] = "be"; m["been"] = "be"; m["being"] = "be"
        m["has"] = "have"; m["had"] = "have"
        m["does"] = "do"; m["did"] = "do"; m["done"] = "do"
        return m
    }()

    // Noun data
    static let irregularPlurals: [String: String] = [
        "child": "children", "person": "people", "man": "men", "woman": "women",
        "mouse": "mice", "goose": "geese", "tooth": "teeth", "foot": "feet",
        "cactus":"cacti","focus":"foci","fungus":"fungi","nucleus":"nuclei","radius":"radii","stimulus":"stimuli","syllabus":"syllabi","alumnus":"alumni",
        "analysis":"analyses","diagnosis":"diagnoses","crisis":"crises","axis":"axes","basis":"bases","thesis":"theses","parenthesis":"parentheses","hypothesis":"hypotheses",
        "phenomenon":"phenomena","criterion":"criteria","datum":"data","medium":"media",
        "index":"indices","appendix":"appendices","matrix":"matrices","vertex":"vertices"
    ]

    static let irregularSingulars: [String: String] = {
        var m: [String: String] = [:]
        for (s, p) in irregularPlurals { m[p] = s }
        return m
    }()

    // Invariant plurals and uncountables
    static let invariantPlurals: Set<String> = [
        "sheep","fish","deer","series","species","aircraft","salmon","trout","bison","moose","swine"
    ]

    static let uncountables: Set<String> = [
        "information","equipment","furniture","luggage","baggage","advice","rice","money","news","bread","butter","cheese","coffee","tea","water","milk","sand","traffic","homework","work"
    ]

    // -f/-fe exceptions that take just +s
    static let fFeTakesS: Set<String> = [
        "roof","belief","chef","chief","proof","cliff","reef","gulf","handkerchief","safe"
    ]
    // When plural is -ves, whether the singular should recover -fe
    static let takesFeWhenSingular: Set<String> = [
        "kni","wi","li","shel"
    ]

    // Classical sets
    static let classicalUsToI: Set<String> = [
        "cactus","focus","fungus","nucleus","radius","stimulus","syllabus","alumnus"
    ]
    static let classicalIToUs: Set<String> = [
        "cacti","foci","fungi","nuclei","radii","stimuli","syllabi","alumni"
    ]
    static let classicalIsToEs: Set<String> = [
        "analysis","diagnosis","crisis","axis","basis","thesis","parenthesis","hypothesis"
    ]
    static let classicalEsToIs: Set<String> = [
        "analyses","diagnoses","crises","axes","bases","theses","parentheses","hypotheses"
    ]
    static let classicalOnUmToA: Set<String> = [
        "phenomenon","criterion","datum","medium","bacterium"
    ]
    static let classicalAToOnUm: Set<String> = [
        "phenomena","criteria","data","media","bacteria"
    ]
    static let classicalAToOn: Set<String> = [
        "phenomena","criteria"
    ]
    static let classicalIxExToIces: Set<String> = [
        "index","appendix","matrix","vertex"
    ]
    static let classicalIcesToIxEx: Set<String> = [
        "indices","appendices","matrices","vertices"
    ]
    static let classicalIcesToIx: Set<String> = [
        "indices","appendices","matrices","vertices"
    ]

    // -o exceptions that take just +s
    static let oTakesS: Set<String> = [
        "piano","photo","halo","solo","soprano","radio","studio","video","zoo","kilo","memo","avocado","taco"
    ]

    // Auxiliaries/Contractions/Pronouns
    static let auxiliaries: Set<String> = [
        "am","is","are","was","were","be","been","being",
        "do","does","did",
        "have","has","had",
        "can","will","shall","may","might","must","should","would","could"
    ]

    static let contractions: [String: String] = [
        "am": "am not",
        "is": "isn't",
        "are": "aren't",
        "was": "wasn't",
        "were": "weren't",
        "do": "don't",
        "does": "doesn't",
        "did": "didn't",
        "have": "haven't",
        "has": "hasn't",
        "had": "hadn't",
        "can": "can't",
        "will": "won't",
        "would": "wouldn't",
        "should": "shouldn't",
        "could": "couldn't",
        "might": "mightn't",
        "must": "mustn't"
    ]

    static let particles: Set<String> = [
        "up","off","out","in","over","on","away","back","down","through","about","around","along","together","apart","by","for","after","into","onto","under","around"
    ]

    static let pronounMap: [String: [String]] = [
        "i": ["I","me","my","mine","myself"],
        "you": ["you","you","your","yours","yourself"],
        "he": ["he","him","his","his","himself"],
        "she": ["she","her","her","hers","herself"],
        "it": ["it","it","its","its","itself"],
        "we": ["we","us","our","ours","ourselves"],
        "they": ["they","them","their","theirs","themselves"],
        "me": ["I","me","my","mine","myself"],
        "him": ["he","him","his","his","himself"],
        "her": ["she","her","her","hers","herself"],
        "us": ["we","us","our","ours","ourselves"],
        "them": ["they","them","their","theirs","themselves"]
    ]

    // Irregular adjective/adverb forms
    static let irregularComparatives: [String: String] = [
        "good": "better",
        "well": "better",
        "bad": "worse",
        "far": "farther"
    ]

    static let irregularSuperlatives: [String: String] = [
        "good": "best",
        "well": "best",
        "bad": "worst",
        "far": "farthest"
    ]

    static let irregularAdjectiveToAdverb: [String: String] = [
        "good": "well",
        "fast": "fast",
        "hard": "hard",
        "public": "publicly" // override -ic -> -ally rule
    ]

    static let irregularAdverbToAdjective: [String: String] = [
        "well": "good",
        "fast": "fast",
        "hard": "hard"
    ]

    // Utilities
    static func matchCase(of original: String, to replacement: String) -> String {
        if original == original.uppercased() { return replacement.uppercased() }
        if let first = original.first, String(first) == String(first).uppercased() {
            guard !replacement.isEmpty else { return replacement }
            let firstRep = replacement.prefix(1).uppercased()
            return firstRep + replacement.dropFirst()
        }
        return replacement
    }

    static func regularIng(_ lower: String) -> String {
        if lower.hasSuffix("ie") { return String(lower.dropLast(2)) + "ying" }
        if lower.hasSuffix("e"), !lower.hasSuffix("ee") { return String(lower.dropLast()) + "ing" }
        if shouldDoubleFinalConsonant(lower) { return lower + String(lower.last!) + "ing" }
        return lower + "ing"
    }

    static func regularPast(_ lower: String) -> String {
        if lower.hasSuffix("e") { return lower + "d" }
        if lower.hasSuffix("y"), let prev = lower.dropLast().last, !"aeiou".contains(prev) {
            return String(lower.dropLast()) + "ied"
        }
        if shouldDoubleFinalConsonant(lower) { return lower + String(lower.last!) + "ed" }
        return lower + "ed"
    }

    static func regular3rd(_ lower: String) -> String {
        if lower.hasSuffix("y"), let prev = lower.dropLast().last, !"aeiou".contains(prev) {
            return String(lower.dropLast()) + "ies"
        }
        if lower.hasSuffix("s") || lower.hasSuffix("x") || lower.hasSuffix("z") || lower.hasSuffix("ch") || lower.hasSuffix("sh") || lower.hasSuffix("o") {
            return lower + "es"
        }
        return lower + "s"
    }

    static func shouldDoubleFinalConsonant(_ lower: String) -> Bool {
        guard let last = lower.last else { return false }
        guard let mid = lower.dropLast().last else { return false }
        guard let first = lower.dropLast(2).last else { return false }
        let vowels = "aeiou"
        if "ywx".contains(last) { return false }
        return !vowels.contains(first) && vowels.contains(mid) && !vowels.contains(last)
    }

    static func hasDoubledFinalConsonant(_ word: String) -> Bool {
        guard word.count >= 2 else { return false }
        let last = word.last!
        if "ywx".contains(last) { return false }
        let prev = word[word.index(before: word.endIndex)]
        return last == prev && last.isLetter && !"aeiou".contains(last)
    }

    static func takesES(_ stem: String) -> Bool {
        if stem.hasSuffix("s") || stem.hasSuffix("x") || stem.hasSuffix("z") || stem.hasSuffix("ch") || stem.hasSuffix("sh") || stem.hasSuffix("o") {
            return true
        }
        return false
    }

    static func beForm(person: MorphologyEngine.Person, number: MorphologyEngine.Number, tense: MorphologyEngine.Tense) -> String {
        switch tense {
        case .present:
            switch (person, number) {
            case (.first, .singular): return "am"
            case (.second, _): return "are"
            case (.third, .singular): return "is"
            default: return "are"
            }
        case .past:
            switch (person, number) {
            case (.first, .singular): return "was"
            case (.third, .singular): return "was"
            default: return "were"
            }
        case .future:
            return "will be"
        }
    }

    static func haveForm(person: MorphologyEngine.Person, number: MorphologyEngine.Number, tense: MorphologyEngine.Tense) -> String {
        switch tense {
        case .present:
            return (person == .third && number == .singular) ? "has" : "have"
        case .past:
            return "had"
        case .future:
            return "will have"
        }
    }

    static func pastParticiple(_ lower: String) -> String {
        if let irr = irregularPastParticiple[lower] { return irr }
        return regularPast(lower)
    }

    static func isPastForm(_ lower: String) -> Bool {
        if irregularPast.values.contains(lower) { return true }
        if lower.hasSuffix("ed") { return true }
        return false
    }

    static func contractionFor(aux: String) -> String? {
        contractions[aux]
    }

    static func contractedForm(aux: String, original: String, contraction: String) -> String {
        if original == original.uppercased() { return contraction.uppercased() }
        if let first = original.first, String(first) == String(first).uppercased() {
            let firstChar = String(contraction.prefix(1)).uppercased()
            return firstChar + contraction.dropFirst()
        }
        return contraction
    }

    static func capitalizeFirst(_ word: String) -> String {
        guard let first = word.first else { return word }
        return String(first).uppercased() + word.dropFirst()
    }

    static func decapitalizeFirst(_ word: String) -> String {
        guard let first = word.first else { return word }
        return String(first).lowercased() + word.dropFirst()
    }

    // Noun helpers
    static func headNoun(of phrase: String) -> String {
        phrase.split(whereSeparator: { $0.isWhitespace }).last.map(String.init) ?? phrase
    }

    static func isProperName(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        if token.count > 1, token == token.uppercased() { return true }
        let first = token.first!
        return String(first) == String(first).uppercased() && token.dropFirst().rangeOfCharacter(from: CharacterSet.uppercaseLetters) == nil
    }

    static func looksPlural(_ lower: String) -> Bool {
        if invariantPlurals.contains(lower) { return true }
        if irregularSingulars[lower] != nil { return true }
        return lower.hasSuffix("s")
    }

    static func startsWithVowelSound(_ word: String) -> Bool {
        let w = word.trimmingCharacters(in: .punctuationCharacters)
        if w.isEmpty { return false }
        let lower = w.lowercased()

        let silentH: Set<String> = ["honest","honor","honour","hour","heir","herb"]
        for h in silentH { if lower.hasPrefix(h) { return true } }

        let consonantSoundVowelStart: Set<String> = ["university","unit","user","european","eulogy","euphemism","eureka","ubiquitous","unicorn","unique","one","once","ouija"]
        for c in consonantSoundVowelStart { if lower.hasPrefix(c) { return false } }

        if w == w.uppercased() {
            if let first = w.first, "AEFHILMNORSX".contains(first) { return true }
            else { return false }
        }
        if let first = lower.first, "aeiou".contains(first) { return true }
        return false
    }

    // Array helpers used by engine
    static func insertNot(in words: [String]) -> [String] {
        guard !words.isEmpty else { return ["not"] }
        if let auxIndex = words.firstIndex(where: { auxiliaries.contains($0.lowercased()) }) {
            var out = words
            out.insert("not", at: auxIndex + 1)
            return out
        }
        var out = words
        out.append("not")
        return out
    }

    static func negateSimpleVerb(in words: [String]) -> [String] {
        EnglishRules(languageCode: "en").negate(words, contracted: false)
    }

    // Simple English syllable counter heuristic
    static func syllableCount(_ word: String) -> Int {
        let lower = word.lowercased()
        if lower.isEmpty { return 0 }
        let vowels = Set("aeiouy")
        var count = 0
        var prevWasVowel = false
        for ch in lower {
            let isVowel = vowels.contains(ch)
            if isVowel && !prevWasVowel { count += 1 }
            prevWasVowel = isVowel
        }
        // Silent 'e' at end
        if lower.hasSuffix("e"), !lower.hasSuffix("le"), count > 1 {
            count -= 1
        }
        return max(1, count)
    }

    // Person/number heuristic from a simple subject array
    static func personNumber(for subjectWords: [String]) -> (MorphologyEngine.Person, MorphologyEngine.Number) {
        guard let first = subjectWords.first?.lowercased() else { return (.third, .plural) }
        switch first {
        case "i": return (.first, .singular)
        case "you": return (.second, .singular)
        case "he","she","it","this","that": return (.third, .singular)
        case "we": return (.first, .plural)
        case "they","these","those": return (.third, .plural)
        default:
            // If it looks like a proper name (capitalized single token), treat as 3rd singular
            if isProperName(subjectWords.first ?? "") { return (.third, .singular) }
            // Default to plural
            return (.third, .plural)
        }
    }
}
