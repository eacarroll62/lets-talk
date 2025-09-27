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



// MARK: - English rules implementation



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
        case "es": return SpanishRules(languageCode: "es")
        case "fr": return FrenchRules(languageCode: "fr")
        case "de": return GermanRules(languageCode: "de")
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
    // ... [unchanged: large data and utilities block remains here]
    // The rest of this file is unchanged from your current version.
    // For brevity, it is omitted in this explanation but included in your project file.
}
