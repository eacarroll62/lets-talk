//
//  PredictionService.swift
//  Let's Talk
//
//  Created by Eric Carroll on 9/4/25.
//

import Foundation

@MainActor
final class PredictionService {
    static let shared = PredictionService()

    // Language-aware n-gram models
    private var unigramsEN: [String: Int] = [:]
    private var bigramsEN: [String: [String: Int]] = [:]
    private var trigramsEN: [String: [String: Int]] = [:] // key: "w1 w2" -> next word counts

    private var unigramsES: [String: Int] = [:]
    private var bigramsES: [String: [String: Int]] = [:]
    private var trigramsES: [String: [String: Int]] = [:]

    private init() {
        seedBaseCorpus()
    }

    func reset() {
        unigramsEN.removeAll(); bigramsEN.removeAll(); trigramsEN.removeAll()
        unigramsES.removeAll(); bigramsES.removeAll(); trigramsES.removeAll()
        seedBaseCorpus()
    }

    // Public: learn from arrays of texts (e.g., tiles and favorites)
    func learn(from texts: [String], languageCode: String) {
        for t in texts { learn(from: t, languageCode: languageCode) }
    }

    // Train from a piece of text (space-separated tokens).
    func learn(from text: String, languageCode: String) {
        let tokens = tokenize(text)
        guard !tokens.isEmpty else { return }

        var (unigrams, bigrams, trigrams) = langModels(languageCode)

        for i in 0..<tokens.count {
            let w = tokens[i]
            unigrams[w, default: 0] += 1

            if i + 1 < tokens.count {
                let next = tokens[i + 1]
                var bmap = bigrams[w] ?? [:]
                bmap[next, default: 0] += 1
                bigrams[w] = bmap
            }
            if i + 2 < tokens.count {
                let w1 = tokens[i], w2 = tokens[i + 1], next2 = tokens[i + 2]
                let key = "\(w1) \(w2)"
                var tmap = trigrams[key] ?? [:]
                tmap[next2, default: 0] += 1
                trigrams[key] = tmap
            }
        }

        setLangModels(languageCode, unigrams: unigrams, bigrams: bigrams, trigrams: trigrams)
    }

    // Suggest up to N next words using trigram > bigram > unigram backoff
    func suggestions(for text: String, languageCode: String, limit: Int = 5) -> [String] {
        let tokens = tokenize(text)
        let (unigrams, bigrams, trigrams) = langModels(languageCode)

        if tokens.count >= 2 {
            let key = "\(tokens[tokens.count - 2]) \(tokens[tokens.count - 1])"
            if let map = trigrams[key], !map.isEmpty {
                return map.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
            }
        }
        if let last = tokens.last, let map = bigrams[last], !map.isEmpty {
            return map.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
        }
        return unigrams.sorted { $0.value > $1.value }.prefix(limit).map { $0.key }
    }

    // MARK: - Helpers

    private func tokenize(_ text: String) -> [String] {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    private func langModels(_ code: String) -> ([String: Int], [String: [String: Int]], [String: [String: Int]]) {
        if code.hasPrefix("es") || code == "es" {
            return (unigramsES, bigramsES, trigramsES)
        } else {
            return (unigramsEN, bigramsEN, trigramsEN)
        }
    }

    private func setLangModels(_ code: String,
                               unigrams: [String: Int],
                               bigrams: [String: [String: Int]],
                               trigrams: [String: [String: Int]]) {
        if code.hasPrefix("es") || code == "es" {
            unigramsES = unigrams
            bigramsES = bigrams
            trigramsES = trigrams
        } else {
            unigramsEN = unigrams
            bigramsEN = bigrams
            trigramsEN = trigrams
        }
    }

    private func seedBaseCorpus() {
        // English seeds
        let enPhrases = [
            "i want more",
            "i need help",
            "yes please",
            "no thank you",
            "i like this",
            "i do not like this",
            "can you help",
            "i feel happy",
            "i feel sad",
            "i am hungry",
            "i am thirsty"
        ]
        enPhrases.forEach { learn(from: $0, languageCode: "en") }

        // Spanish seeds
        let esPhrases = [
            "yo quiero mas",
            "necesito ayuda",
            "si por favor",
            "no gracias",
            "me gusta esto",
            "no me gusta esto",
            "puedes ayudarme",
            "me siento feliz",
            "me siento triste",
            "tengo hambre",
            "tengo sed"
        ]
        esPhrases.forEach { learn(from: $0, languageCode: "es") }
    }
}
