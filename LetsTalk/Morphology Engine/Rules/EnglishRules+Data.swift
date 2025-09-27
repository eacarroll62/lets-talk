import Foundation

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
