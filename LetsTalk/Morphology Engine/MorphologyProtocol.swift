//
//  Morphology Protocol.swift
//  LetsTalk
//
//  Created by Eric Carroll on 9/23/25.
//

import Foundation

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

    // Conjugation (moved from engine for language parity)
    func conjugate(lemma: String,
                   person: MorphologyEngine.Person,
                   number: MorphologyEngine.Number,
                   tense: MorphologyEngine.Tense,
                   aspect: MorphologyEngine.Aspect,
                   voice: MorphologyEngine.Voice,
                   overrides: MorphologyOverrides) -> String
}
