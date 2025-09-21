// Swift code here
// MorphologyEngine.swift
import Foundation

enum MorphologyEngine {
    // MARK: - Public entry points (English-focused)
    static func toIng(_ verb: String) -> String {
        let lower = verb.lowercased()
        if let irr = irregularParticiple[lower] { return matchCase(of: verb, to: irr) }
        return matchCase(of: verb, to: regularIng(lower))
    }
    
    static func toPast(_ verb: String) -> String {
        let lower = verb.lowercased()
        if let irr = irregularPast[lower] { return matchCase(of: verb, to: irr) }
        return matchCase(of: verb, to: regularPast(lower))
    }
    
    static func to3rdPersonS(_ verb: String) -> String {
        let lower = verb.lowercased()
        if let irr = irregular3rd[lower] { return matchCase(of: verb, to: irr) }
        return matchCase(of: verb, to: regular3rd(lower))
    }
    
    static func baseVerb(_ verb: String) -> String {
        let lower = verb.lowercased()
        if let lemma = irregularLemma[lower] { return matchCase(of: verb, to: lemma) }
        
        // -ing → base, un-double final consonant when applicable
        if lower.hasSuffix("ing") {
            var stem = String(lower.dropLast(3))
            // Un-double final consonant (running -> run), but never un-double y/w/x
            if hasDoubledFinalConsonant(stem) {
                stem.removeLast()
            }
            return matchCase(of: verb, to: stem)
        }
        
        // -ied → -y (carried -> carry)
        if lower.hasSuffix("ied") {
            let stem = String(lower.dropLast(3)) + "y"
            return matchCase(of: verb, to: stem)
        }
        
        // -ed handling
        if lower.hasSuffix("ed") {
            if String(lower.dropLast()).hasSuffix("e") {
                let stem = String(lower.dropLast(1))
                return matchCase(of: verb, to: stem)
            } else {
                var stem = String(lower.dropLast(2))
                if hasDoubledFinalConsonant(stem) {
                    stem.removeLast()
                }
                return matchCase(of: verb, to: stem)
            }
        }
        
        // 3rd person singular -ies/-es/-s
        if lower.hasSuffix("ies") {
            let stem = String(lower.dropLast(3)) + "y"
            return matchCase(of: verb, to: stem)
        }
        if lower.hasSuffix("es") {
            let stem = String(lower.dropLast(2))
            if takesES(stem) {
                return matchCase(of: verb, to: stem)
            } else {
                return matchCase(of: verb, to: String(lower.dropLast()))
            }
        }
        if lower.hasSuffix("s") {
            return matchCase(of: verb, to: String(lower.dropLast()))
        }
        
        return verb
    }
    
    // MARK: - Nouns: pluralization/singularization (enhanced)
    static func pluralize(_ noun: String) -> String {
        let lower = noun.lowercased()
        // Invariant or uncountable: return as-is
        if invariantPlurals.contains(lower) || uncountables.contains(lower) {
            return noun
        }
        // Irregulars/classicals
        if let irr = irregularPlurals[lower] { return matchCase(of: noun, to: irr) }
        
        // -y -> -ies (consonant + y)
        if lower.hasSuffix("y"), let prev = lower.dropLast().last, !"aeiou".contains(prev) {
            return matchCase(of: noun, to: String(lower.dropLast()) + "ies")
        }
        
        // -f/-fe -> -ves (with exceptions)
        if lower.hasSuffix("f") || lower.hasSuffix("fe") {
            if fFeTakesS.contains(lower) {
                return matchCase(of: noun, to: lower + "s")
            } else {
                if lower.hasSuffix("fe") {
                    return matchCase(of: noun, to: String(lower.dropLast(2)) + "ves")
                } else {
                    return matchCase(of: noun, to: String(lower.dropLast(1)) + "ves")
                }
            }
        }
        
        // Classical endings handled by irregularPlurals above, but also handle -us -> -i fallback for common forms
        if lower.hasSuffix("us"), classicalUsToI.contains(lower) {
            return matchCase(of: noun, to: String(lower.dropLast(2)) + "i")
        }
        if lower.hasSuffix("is"), classicalIsToEs.contains(lower) {
            return matchCase(of: noun, to: String(lower.dropLast(2)) + "es")
        }
        if (lower.hasSuffix("on") || lower.hasSuffix("um")), classicalOnUmToA.contains(lower) {
            return matchCase(of: noun, to: String(lower.dropLast(2)) + "a")
        }
        if (lower.hasSuffix("ix") || lower.hasSuffix("ex")), classicalIxExToIces.contains(lower) {
            return matchCase(of: noun, to: String(lower.dropLast(2)) + "ices")
        }
        
        // -o endings: exceptions take just -s, otherwise -es
        if lower.hasSuffix("o") {
            if oTakesS.contains(lower) {
                return matchCase(of: noun, to: lower + "s")
            } else {
                return matchCase(of: noun, to: lower + "es")
            }
        }
        
        // sibilants and others: -es
        if lower.hasSuffix("s") || lower.hasSuffix("x") || lower.hasSuffix("z") || lower.hasSuffix("ch") || lower.hasSuffix("sh") {
            return matchCase(of: noun, to: lower + "es")
        }
        
        // Default
        return matchCase(of: noun, to: lower + "s")
    }
    
    static func singularize(_ noun: String) -> String {
        let lower = noun.lowercased()
        // Invariant or uncountable: return as-is
        if invariantPlurals.contains(lower) || uncountables.contains(lower) {
            return noun
        }
        // Irregulars/classicals (plural->singular)
        if let base = irregularSingulars[lower] { return matchCase(of: noun, to: base) }
        
        // -ies -> -y
        if lower.hasSuffix("ies"), lower.count > 3 {
            let stem = String(lower.dropLast(3)) + "y"
            return matchCase(of: noun, to: stem)
        }
        
        // -ves -> -f/-fe; we need to decide which to use; default to -f, but use -fe for known items
        if lower.hasSuffix("ves"), lower.count > 3 {
            let stem = String(lower.dropLast(3))
            if takesFeWhenSingular.contains(stem) {
                return matchCase(of: noun, to: stem + "fe")
            } else {
                return matchCase(of: noun, to: stem + "f")
            }
        }
        
        // Classical plurals
        if lower.hasSuffix("i"), classicalIToUs.contains(lower) {
            return matchCase(of: noun, to: String(lower.dropLast(1)) + "us")
        }
        if lower.hasSuffix("es"), classicalEsToIs.contains(lower) {
            return matchCase(of: noun, to: String(lower.dropLast(2)) + "is")
        }
        if lower.hasSuffix("a"), classicalAToOnUm.contains(lower) {
            // Heuristic: prefer -on for known -on words, otherwise -um
            let base = String(lower.dropLast(1))
            if classicalAToOn.contains(lower) {
                return matchCase(of: noun, to: base + "on")
            } else {
                return matchCase(of: noun, to: base + "um")
            }
        }
        if lower.hasSuffix("ices"), classicalIcesToIxEx.contains(lower) {
            let base = String(lower.dropLast(4))
            // Prefer -ix for known -ix, else -ex
            if classicalIcesToIx.contains(lower) {
                return matchCase(of: noun, to: base + "ix")
            } else {
                return matchCase(of: noun, to: base + "ex")
            }
        }
        
        // -es cases (sibilants and -o default)
        if lower.hasSuffix("es"), lower.count > 2 {
            let stem = String(lower.dropLast(2))
            return matchCase(of: noun, to: stem)
        }
        // Simple -s
        if lower.hasSuffix("s"), lower.count > 1 {
            return matchCase(of: noun, to: String(lower.dropLast()))
        }
        return noun
    }
    
    // MARK: - Noun phrase helpers
    // Possessives: child -> child's; children -> children's; dogs -> dogs'
    static func possessive(_ noun: String) -> String {
        let lower = noun.lowercased()
        // If it's an irregular plural without -s (children, men), add 's
        if let singular = irregularSingulars[lower], !lower.hasSuffix("s") {
            return matchCase(of: noun, to: lower + "'s")
        }
        // If it looks like a regular plural ending in s, add apostrophe only
        if lower.hasSuffix("s") {
            return matchCase(of: noun, to: lower + "'")
        }
        // Default singular: 's
        return matchCase(of: noun, to: lower + "'s")
    }
    
    // Article selection (a/an) based on pronunciation heuristics
    static func indefiniteArticle(for word: String) -> String {
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.split(whereSeparator: { $0.isWhitespace }).first.map(String.init) else {
            return "a"
        }
        return startsWithVowelSound(first) ? "an" : "a"
    }
    
    enum DeterminerPreference { case definite, indefinite, none }
    
    // Choose "the", "a/an", or "" based on preference and noun properties
    static func determiner(for nounPhrase: String, preference: DeterminerPreference) -> String {
        let head = headNoun(of: nounPhrase)
        let lowerHead = head.lowercased()
        
        // Proper name heuristic: single capitalized token -> usually no article
        if isProperName(head) {
            return ""
        }
        
        switch preference {
        case .definite:
            return "the"
        case .indefinite:
            // Plurals and uncountables often take no article; prefer "some"
            if invariantPlurals.contains(lowerHead) || uncountables.contains(lowerHead) {
                return "some"
            }
            // If already plural by simple heuristic, use "some"
            if looksPlural(lowerHead) && irregularSingulars[lowerHead] == nil {
                return "some"
            }
            // Singular countable -> a/an
            return indefiniteArticle(for: head)
        case .none:
            return ""
        }
    }
    
    // MARK: - Verb morphology and clause helpers (existing)
    enum Person { case first, second, third }
    enum Number { case singular, plural }
    enum Tense { case present, past, future }
    enum Aspect { case simple, progressive, perfect, perfectProgressive }
    enum Voice { case active, passive }
    
    static func conjugate(lemma: String, person: Person, number: Number, tense: Tense, aspect: Aspect = .simple, voice: Voice = .active) -> String {
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
                let be = beForm(person: person, number: number, tense: tense)
                return be + " " + toIng(base)
            case .perfect:
                let have = haveForm(person: person, number: number, tense: tense)
                return have + " " + pastParticiple(base)
            case .perfectProgressive:
                let have = haveForm(person: person, number: number, tense: tense)
                return have + " been " + toIng(base)
            }
        case .passive:
            switch aspect {
            case .simple:
                switch tense {
                case .present:
                    return beForm(person: person, number: number, tense: .present) + " " + pastParticiple(base)
                case .past:
                    return beForm(person: person, number: number, tense: .past) + " " + pastParticiple(base)
                case .future:
                    return "will be " + pastParticiple(base)
                }
            case .progressive:
                switch tense {
                case .present:
                    return beForm(person: person, number: number, tense: .present) + " being " + pastParticiple(base)
                case .past:
                    return beForm(person: person, number: number, tense: .past) + " being " + pastParticiple(base)
                case .future:
                    return "will be being " + pastParticiple(base)
                }
            case .perfect:
                switch tense {
                case .present:
                    return haveForm(person: person, number: number, tense: .present) + " been " + pastParticiple(base)
                case .past:
                    return haveForm(person: person, number: number, tense: .past) + " been " + pastParticiple(base)
                case .future:
                    return "will have been " + pastParticiple(base)
                }
            case .perfectProgressive:
                switch tense {
                case .present:
                    return haveForm(person: person, number: number, tense: .present) + " been being " + pastParticiple(base)
                case .past:
                    return haveForm(person: person, number: number, tense: .past) + " been being " + pastParticiple(base)
                case .future:
                    return "will have been being " + pastParticiple(base)
                }
            }
        }
    }
    
    static func negate(_ words: [String], contracted: Bool = false) -> [String] {
        guard !words.isEmpty else { return ["do", contracted ? "n't" : "not"] }
        if let auxIndex = words.firstIndex(where: { auxiliaries.contains($0.lowercased()) }) {
            var out = words
            let auxLower = words[auxIndex].lowercased()
            if contracted, let contraction = contractionFor(aux: auxLower) {
                out[auxIndex] = contractedForm(aux: auxLower, original: out[auxIndex], contraction: contraction)
            } else {
                out.insert("not", at: auxIndex + 1)
            }
            return out
        }
        var out = words
        let main = words.last ?? ""
        let subjWords = Array(words.dropLast())
        let mainLower = main.lowercased()
        let looksPast = isPastForm(mainLower)
        let base = baseVerb(mainLower)
        let (person, number) = personNumber(for: subjWords)
        let doAux: String = looksPast ? "did" : ((person == .third && number == .singular) ? "does" : "do")
        out.removeLast()
        if contracted, let contraction = contractionFor(aux: doAux) {
            out.append(contractedForm(aux: doAux, original: doAux, contraction: contraction))
        } else {
            out.append(doAux)
            out.append("not")
        }
        out.append(base)
        return out
    }
    
    static func makeYesNoQuestion(_ words: [String]) -> [String] {
        guard !words.isEmpty else { return [] }
        if let auxIndex = words.firstIndex(where: { auxiliaries.contains($0.lowercased()) }) {
            var out = words
            let aux = out.remove(at: auxIndex)
            out.insert(capitalizeFirst(aux), at: 0)
            return out
        }
        let main = words.last ?? ""
        let subject = Array(words.dropLast())
        let looksPast = isPastForm(main.lowercased())
        let (person, number) = personNumber(for: subject)
        let doAux = looksPast ? "did" : ((person == .third && number == .singular) ? "does" : "do")
        let base = baseVerb(main)
        var out: [String] = []
        out.append(capitalizeFirst(doAux))
        out.append(contentsOf: subject)
        out.append(base)
        return out
    }
    
    static func makeWhQuestion(_ words: [String], wh: String) -> [String] {
        guard !words.isEmpty else { return [wh.capitalized] }
        var inverted = makeYesNoQuestion(words)
        if !inverted.isEmpty { inverted[0] = decapitalizeFirst(inverted[0]) }
        var out: [String] = []
        out.append(capitalizeFirst(wh))
        out.append(contentsOf: inverted)
        return out
    }
    
    // Text variants
    static func negate(into text: String, contracted: Bool = false) -> String {
        let words = tokenizePreserving(text)
        let out = negate(words, contracted: contracted)
        return out.joined(separator: " ")
    }
    
    static func makeYesNoQuestion(into text: String) -> String {
        let words = tokenizePreserving(text)
        let out = makeYesNoQuestion(words)
        return out.joined(separator: " ")
    }
    
    static func makeWhQuestion(into text: String, wh: String) -> String {
        let words = tokenizePreserving(text)
        let out = makeWhQuestion(words, wh: wh)
        return out.joined(separator: " ")
    }
    
    // MARK: - Adjective Inflection
    static func toComparative(_ adjective: String) -> String {
        let lower = adjective.lowercased()
        if let irr = irregularComparatives[lower] {
            return matchCase(of: adjective, to: irr)
        }
        if lower.hasSuffix("y"), let prev = lower.dropLast().last, !"aeiou".contains(prev) {
            return matchCase(of: adjective, to: String(lower.dropLast()) + "ier")
        }
        if syllableCount(lower) == 1 && lower.count <= 5 {
            if shouldDoubleFinalConsonant(lower) {
                return matchCase(of: adjective, to: lower + String(lower.last!) + "er")
            }
            return matchCase(of: adjective, to: lower + "er")
        }
        if syllableCount(lower) == 2 && lower.hasSuffix("y") {
            return matchCase(of: adjective, to: String(lower.dropLast()) + "ier")
        }
        return matchCase(of: adjective, to: "more " + lower)
    }
    
    static func toSuperlative(_ adjective: String) -> String {
        let lower = adjective.lowercased()
        if let irr = irregularSuperlatives[lower] {
            return matchCase(of: adjective, to: irr)
        }
        if lower.hasSuffix("y"), let prev = lower.dropLast().last, !"aeiou".contains(prev) {
            return matchCase(of: adjective, to: String(lower.dropLast()) + "iest")
        }
        if syllableCount(lower) == 1 && lower.count <= 5 {
            if shouldDoubleFinalConsonant(lower) {
                return matchCase(of: adjective, to: lower + String(lower.last!) + "est")
            }
            return matchCase(of: adjective, to: lower + "est")
        }
        if syllableCount(lower) == 2 && lower.hasSuffix("y") {
            return matchCase(of: adjective, to: String(lower.dropLast()) + "iest")
        }
        return matchCase(of: adjective, to: "most " + lower)
    }
    
    // MARK: - Adjective/Adverb Conversion
    static func toAdverb(_ adjective: String) -> String {
        let lower = adjective.lowercased()
        if let irr = irregularAdjectiveToAdverb[lower] {
            return matchCase(of: adjective, to: irr)
        }
        if lower.hasSuffix("y"), let prev = lower.dropLast().last, !"aeiou".contains(prev) {
            return matchCase(of: adjective, to: String(lower.dropLast()) + "ily")
        }
        if lower.hasSuffix("ic") {
            return matchCase(of: adjective, to: lower + "ally")
        }
        if lower.hasSuffix("le"), let prev = lower.dropLast(2).last, !"aeiou".contains(prev) {
            return matchCase(of: adjective, to: String(lower.dropLast()) + "y")
        }
        return matchCase(of: adjective, to: lower + "ly")
    }

    static func adverbToAdjective(_ adverb: String) -> String {
        let lower = adverb.lowercased()
        if let irr = irregularAdverbToAdjective[lower] {
            return matchCase(of: adverb, to: irr)
        }
        if lower.hasSuffix("ily") {
            return matchCase(of: adverb, to: String(lower.dropLast(3)) + "y")
        }
        if lower.hasSuffix("ally") {
            return matchCase(of: adverb, to: String(lower.dropLast(4)) + "ic")
        }
        if lower.hasSuffix("ly") {
            return matchCase(of: adverb, to: String(lower.dropLast(2)))
        }
        return adverb
    }
    
    // Irregulars for adjective inflection
    private static let irregularComparatives: [String: String] = [
        "good": "better", "well": "better", "bad": "worse", "far": "farther", "little": "less", "much": "more", "many": "more"
    ]
    private static let irregularSuperlatives: [String: String] = [
        "good": "best", "well": "best", "bad": "worst", "far": "farthest", "little": "least", "much": "most", "many": "most"
    ]
    private static let irregularAdjectiveToAdverb: [String: String] = [
        "good": "well", "fast": "fast", "hard": "hard", "late": "late", "early": "early"
    ]
    private static let irregularAdverbToAdjective: [String: String] = [
        "well": "good", "fast": "fast", "hard": "hard", "late": "late", "early": "early"
    ]
    
    // Syllable count estimation (very basic heuristic)
    private static func syllableCount(_ word: String) -> Int {
        let pattern = "[aeiouy]+"
        let range = NSRange(location: 0, length: word.utf16.count)
        let matches = (try? NSRegularExpression(pattern: pattern).matches(in: word, range: range)) ?? []
        return max(matches.count, 1)
    }
    
    // MARK: - Token helpers
    
    static func replaceLastWord(in text: String, with transform: (String) -> String) -> String {
        var parts = tokenizePreserving(text)
        guard let last = parts.last else { return text }
        let transformed = transform(last)
        parts[parts.count - 1] = transformed
        return parts.joined(separator: " ")
    }
    
    static func appendWord(_ word: String, to text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return word }
        return trimmed + " " + word
    }
    
    static func insertNot(into text: String) -> String {
        let words = tokenizePreserving(text)
        let out = insertNot(in: words)
        return out.joined(separator: " ")
    }
    
    static func negateSimpleVerb(in text: String) -> String {
        let words = tokenizePreserving(text)
        let out = negateSimpleVerb(in: words)
        return out.joined(separator: " ")
    }
    
    static func lastWord(_ text: String) -> String? {
        tokenizePreserving(text).last
    }
    
    // MARK: - Pronoun variants
    
    // Returns canonical pronoun forms for the given token:
    // [subject, object, possessive adjective, possessive pronoun, reflexive]
    // Casing behavior:
    // - If original is ALL CAPS, returns ALL CAPS forms.
    // - If original is Capitalized, returns Capitalized forms (preserving "I").
    // - Otherwise, returns canonical forms (with "I" capitalized, others lowercase).
    static func pronounVariants(_ token: String) -> [String] {
        let lower = token.lowercased()
        guard let forms = pronounMap[lower] else {
            // Not a known pronoun; just return the token itself.
            return [token]
        }
        // All caps
        if token == token.uppercased() {
            return forms.map { $0.uppercased() }
        }
        // Capitalized (Title-case single token)
        let isCapitalized: Bool = {
            guard let first = token.first else { return false }
            return String(first) == String(first).uppercased()
                && token.dropFirst().rangeOfCharacter(from: CharacterSet.uppercaseLetters) == nil
        }()
        if isCapitalized {
            return forms.map { form in
                if form == "I" { return "I" } // keep canonical
                guard let f = form.first else { return form }
                return String(f).uppercased() + form.dropFirst()
            }
        }
        // Default: return canonical forms (already include "I" capitalized)
        return forms
    }
    
    // MARK: - Internals
    
    private static func tokenizePreserving(_ text: String) -> [String] {
        text.split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }
    
    // Subject analysis
    private static func personNumber(for subjectTokens: [String]) -> (Person, Number) {
        let lowers = subjectTokens.map { $0.lowercased() }
        if lowers.contains("i") { return (.first, .singular) }
        if lowers.contains("we") { return (.first, .plural) }
        if lowers.contains("you") { return (.second, .plural) }
        if lowers.contains("he") || lowers.contains("she") || lowers.contains("it") { return (.third, .singular) }
        if lowers.contains("they") { return (.third, .plural) }
        if lowers.contains("and") { return (.third, .plural) }
        let filtered = subjectTokens.filter { !$0.isEmpty }
        if let head = filtered.last {
            let headLower = head.lowercased()
            if headLower.hasSuffix("s") && !["is", "was", "this"].contains(headLower) {
                return (.third, .plural)
            }
            if filtered.count == 1, let first = head.first, String(first) == String(first).uppercased() {
                return (.third, .singular)
            }
        }
        return (subjectTokens.count <= 1 ? .third : .third, subjectTokens.count <= 1 ? .singular : .plural)
    }
    
    private static func is3rdPersonSubject(_ words: [String]) -> Bool {
        let subjectTokens: [String] = words.count >= 2 ? Array(words.dropLast()) : words
        let (person, number) = personNumber(for: subjectTokens)
        return person == .third && number == .singular
    }
    
    private static func regularIng(_ lower: String) -> String {
        if lower.hasSuffix("ie") {
            return String(lower.dropLast(2)) + "ying"
        }
        if lower.hasSuffix("e"), !lower.hasSuffix("ee") {
            return String(lower.dropLast()) + "ing"
        }
        if shouldDoubleFinalConsonant(lower) {
            return lower + String(lower.last!) + "ing"
        }
        return lower + "ing"
    }
    
    private static func regularPast(_ lower: String) -> String {
        if lower.hasSuffix("e") { return lower + "d" }
        if lower.hasSuffix("y"), let prev = lower.dropLast().last, !"aeiou".contains(prev) {
            return String(lower.dropLast()) + "ied"
        }
        if shouldDoubleFinalConsonant(lower) {
            return lower + String(lower.last!) + "ed"
        }
        return lower + "ed"
    }
    
    private static func regular3rd(_ lower: String) -> String {
        if lower.hasSuffix("y"), let prev = lower.dropLast().last, !"aeiou".contains(prev) {
            return String(lower.dropLast()) + "ies"
        }
        if lower.hasSuffix("s") || lower.hasSuffix("x") || lower.hasSuffix("z") || lower.hasSuffix("ch") || lower.hasSuffix("sh") || lower.hasSuffix("o") {
            return lower + "es"
        }
        return lower + "s"
    }
    
    private static func shouldDoubleFinalConsonant(_ lower: String) -> Bool {
        guard let last = lower.last else { return false }
        guard let mid = lower.dropLast().last else { return false }
        guard let first = lower.dropLast(2).last else { return false }
        let vowels = "aeiou"
        if "ywx".contains(last) { return false }
        return !vowels.contains(first) && vowels.contains(mid) && !vowels.contains(last)
    }
    
    private static func hasDoubledFinalConsonant(_ word: String) -> Bool {
        guard word.count >= 2 else { return false }
        let last = word.last!
        if "ywx".contains(last) { return false }
        let prev = word[word.index(before: word.endIndex)]
        return last == prev && last.isLetter && !"aeiou".contains(last)
    }
    
    private static func takesES(_ stem: String) -> Bool {
        if stem.hasSuffix("s") || stem.hasSuffix("x") || stem.hasSuffix("z") || stem.hasSuffix("ch") || stem.hasSuffix("sh") || stem.hasSuffix("o") {
            return true
        }
        return false
    }
    
    private static func matchCase(of original: String, to replacement: String) -> String {
        if original == original.uppercased() {
            return replacement.uppercased()
        }
        if let first = original.first, String(first) == String(first).uppercased() {
            guard !replacement.isEmpty else { return replacement }
            let firstRep = replacement.prefix(1).uppercased()
            return firstRep + replacement.dropFirst()
        }
        return replacement
    }
    
    private static func beForm(person: Person, number: Number, tense: Tense) -> String {
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
    
    private static func haveForm(person: Person, number: Number, tense: Tense) -> String {
        switch tense {
        case .present:
            return (person == .third && number == .singular) ? "has" : "have"
        case .past:
            return "had"
        case .future:
            return "will have"
        }
    }
    
    private static func pastParticiple(_ lower: String) -> String {
        if let irr = irregularPastParticiple[lower] { return irr }
        return regularPast(lower)
    }
    
    private static func isPastForm(_ lower: String) -> Bool {
        if irregularPast.values.contains(lower) { return true }
        if lower.hasSuffix("ed") { return true }
        return false
    }
    
    private static func contractionFor(aux: String) -> String? {
        contractions[aux]
    }
    
    private static func contractedForm(aux: String, original: String, contraction: String) -> String {
        if original == original.uppercased() {
            return contraction.uppercased()
        }
        if let first = original.first, String(first) == String(first).uppercased() {
            let firstChar = String(contraction.prefix(1)).uppercased()
            return firstChar + contraction.dropFirst()
        }
        return contraction
    }
    
    private static func capitalizeFirst(_ word: String) -> String {
        guard let first = word.first else { return word }
        return String(first).uppercased() + word.dropFirst()
    }
    
    private static func decapitalizeFirst(_ word: String) -> String {
        guard let first = word.first else { return word }
        return String(first).lowercased() + word.dropFirst()
    }
    
    // Provide array-based helpers used by text variants
    private static func insertNot(in words: [String]) -> [String] {
        // If an auxiliary exists, just insert "not" after it; otherwise fall back to do-support.
        if let auxIndex = words.firstIndex(where: { auxiliaries.contains($0.lowercased()) }) {
            var out = words
            out.insert("not", at: auxIndex + 1)
            return out
        }
        return negate(words, contracted: false)
    }
    
    private static func negateSimpleVerb(in words: [String]) -> [String] {
        // Minimal implementation: delegate to negate without contractions.
        return negate(words, contracted: false)
    }
    
    // MARK: - Data
    
    // Irregular verbs (expanded)
    private static let irregularPast: [String: String] = [
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
    
    private static let irregularPastParticiple: [String: String] = [
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
    
    private static let irregularParticiple: [String: String] = [
        "be": "being", "see": "seeing", "flee": "fleeing", "die": "dying"
    ]
    
    private static let irregular3rd: [String: String] = [
        "be": "is", "am": "is", "are": "is", "have": "has", "do": "does", "go": "goes",
        "say":"says","fly":"flies","try":"tries","deny":"denies","study":"studies"
    ]
    
    private static let irregularLemma: [String: String] = {
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
    private static let irregularPlurals: [String: String] = [
        // Provided irregulars
        "child": "children", "person": "people", "man": "men", "woman": "women",
        "mouse": "mice", "goose": "geese", "tooth": "teeth", "foot": "feet",
        // Classical/learned forms
        "cactus":"cacti","focus":"foci","fungus":"fungi","nucleus":"nuclei","radius":"radii","stimulus":"stimuli","syllabus":"syllabi","alumnus":"alumni",
        "analysis":"analyses","diagnosis":"diagnoses","crisis":"crises","axis":"axes","basis":"bases","thesis":"theses","parenthesis":"parentheses","hypothesis":"hypotheses",
        "phenomenon":"phenomena","criterion":"criteria","datum":"data","medium":"media",
        "index":"indices","appendix":"appendices","matrix":"matrices","vertex":"vertices"
    ]
    
    private static let irregularSingulars: [String: String] = {
        var m: [String: String] = [:]
        for (s, p) in irregularPlurals { m[p] = s }
        return m
    }()
    
    // Invariant plurals and uncountables
    private static let invariantPlurals: Set<String> = [
        "sheep","fish","deer","series","species","aircraft","salmon","trout","bison","moose","swine"
    ]
    
    private static let uncountables: Set<String> = [
        "information","equipment","furniture","luggage","baggage","advice","rice","money","news","bread","butter","cheese","coffee","tea","water","milk","sand","traffic","homework","work"
    ]
    
    // -f/-fe exceptions that take just +s
    private static let fFeTakesS: Set<String> = [
        "roof","belief","chef","chief","proof","cliff","reef","gulf","handkerchief","safe"
    ]
    // When plural is -ves, whether the singular should recover -fe (e.g., knife -> knives)
    private static let takesFeWhenSingular: Set<String> = [
        "kni","wi","li","shel"
    ]
    
    // Classical sets for rule-based fallbacks
    private static let classicalUsToI: Set<String> = [
        "cactus","focus","fungus","nucleus","radius","stimulus","syllabus","alumnus"
    ]
    private static let classicalIToUs: Set<String> = [
        "cacti","foci","fungi","nuclei","radii","stimuli","syllabi","alumni"
    ]
    private static let classicalIsToEs: Set<String> = [
        "analysis","diagnosis","crisis","axis","basis","thesis","parenthesis","hypothesis"
    ]
    private static let classicalEsToIs: Set<String> = [
        "analyses","diagnoses","crises","axes","bases","theses","parentheses","hypotheses"
    ]
    private static let classicalOnUmToA: Set<String> = [
        "phenomenon","criterion","datum","medium","bacterium"
    ]
    private static let classicalAToOnUm: Set<String> = [
        "phenomena","criteria","data","media","bacteria"
    ]
    private static let classicalAToOn: Set<String> = [
        "phenomena","criteria" // prefer -on for these
    ]
    private static let classicalIxExToIces: Set<String> = [
        "index","appendix","matrix","vertex"
    ]
    private static let classicalIcesToIxEx: Set<String> = [
        "indices","appendices","matrices","vertices"
    ]
    private static let classicalIcesToIx: Set<String> = [
        "indices","appendices","matrices","vertices" // all prefer -ix/-ex; we'll default to -ix for index/appendix/matrix/vertex
    ]
    
    // -o exceptions that take just +s
    private static let oTakesS: Set<String> = [
        "piano","photo","halo","solo","soprano","radio","studio","video","zoo","kilo","memo","avocado","taco"
    ]
    
    // MARK: - Noun helpers (pronunciation / head extraction)
    private static func headNoun(of phrase: String) -> String {
        // Very naive: take the last token
        return tokenizePreserving(phrase).last ?? phrase
    }
    
    private static func isProperName(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        if token.count > 1, token == token.uppercased() { return true } // acronym
        let first = token.first!
        return String(first) == String(first).uppercased() && token.dropFirst().rangeOfCharacter(from: CharacterSet.uppercaseLetters) == nil
    }
    
    private static func looksPlural(_ lower: String) -> Bool {
        if invariantPlurals.contains(lower) { return true }
        if irregularSingulars[lower] != nil { return true }
        return lower.hasSuffix("s")
    }
    
    private static func startsWithVowelSound(_ word: String) -> Bool {
        let w = word.trimmingCharacters(in: .punctuationCharacters)
        if w.isEmpty { return false }
        let lower = w.lowercased()
        
        // Silent h words
        let silentH: Set<String> = ["honest","honor","honour","hour","heir","herb"]
        for h in silentH {
            if lower.hasPrefix(h) { return true }
        }
        
        // Words that start with vowel letter but consonant sound (y/you, w/one)
        let consonantSoundVowelStart: Set<String> = ["university","unit","user","european","eulogy","euphemism","eureka","ubiquitous","unicorn","unique","one","once","ouija"]
        for c in consonantSoundVowelStart {
            if lower.hasPrefix(c) { return false }
        }
        
        // Acronyms pronounced with initial vowel sound letters (F, L, M, N, R, S, X)
        if w == w.uppercased() {
            if let first = w.first, "AEFHILMNORSX".contains(first) {
                return true
            } else {
                return false
            }
        }
        
        // Default vowel check
        if let first = lower.first, "aeiou".contains(first) {
            return true
        }
        return false
    }
    
    // MARK: - Auxiliaries/Contractions/Pronouns (existing)
    private static let auxiliaries: Set<String> = [
        "am","is","are","was","were","be","been","being",
        "do","does","did",
        "have","has","had",
        "can","will","shall","may","might","must","should","would","could"
    ]
    
    private static let contractions: [String: String] = [
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
    
    private static let pronounMap: [String: [String]] = [
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
}

