//
//  AACColorMigration.swift
//  Let's Talk
//
//  Utilities to migrate/apply AAC color schemes to existing tiles,
//  and optionally infer Part of Speech for common words.
//

import Foundation
import SwiftData

@MainActor
enum AACColorMigration {

    struct Result {
        let updatedTiles: Int
        let assignedPOS: Int
    }

    // Apply the given scheme's colors to tiles that already have a POS.
    // If overwrite is false, only tiles with nil/empty colorHex will be updated.
    static func applySchemeColors(modelContext: ModelContext,
                                  scheme: AACColorScheme,
                                  overwrite: Bool = true) throws -> Result {
        let descriptor = FetchDescriptor<Tile>()
        let tiles = try modelContext.fetch(descriptor)

        var updated = 0
        for t in tiles {
            guard let pos = t.partOfSpeech else { continue }
            if overwrite || t.colorHex == nil || t.colorHex?.isEmpty == true {
                t.colorHex = FitzgeraldKey.colorHex(for: pos, scheme: scheme)
                updated += 1
            }
        }
        if updated > 0 {
            try modelContext.save()
        }
        return Result(updatedTiles: updated, assignedPOS: 0)
    }

    // Infer POS for a small, conservative lexicon of common words and apply scheme colors.
    // Existing POS values are preserved unless overwritePOS is true.
    // If setColor is true, updates colorHex to the scheme color for that POS (respecting overwriteColor).
    static func inferPOSForCommonWords(modelContext: ModelContext,
                                       scheme: AACColorScheme,
                                       overwritePOS: Bool = false,
                                       setColor: Bool = true,
                                       overwriteColor: Bool = false) throws -> Result {
        let descriptor = FetchDescriptor<Tile>()
        let tiles = try modelContext.fetch(descriptor)

        // Minimal lexicon (extend as needed)
        let pronouns: Set<String> = ["i","you","he","she","we","they","me","him","her","us","them","it","my","your","our","their"]
        let verbs: Set<String> = ["go","come","stop","want","like","need","see","look","eat","drink","play","read","write","open","close","make","get","put","give","take","help","feel","am","is","are","have","do"]
        let adjectives: Set<String> = ["happy","sad","mad","tired","excited","scared","sick","hurt","bored","calm","big","small","fast","slow","hot","cold"]
        let adverbs: Set<String> = ["here","there","now","later","today","tomorrow"]
        let determiners: Set<String> = ["this","that","these","those","a","an","the","more"]
        let questions: Set<String> = ["what","where","when","who","why","how"]
        let negations: Set<String> = ["no","not","don’t","dont","cant","can’t","won’t","wont","never"]
        let social: Set<String> = ["yes","please","thank","thanks","hello","hi","bye","goodbye","help"]

        func guessPOS(for text: String) -> PartOfSpeech? {
            let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if pronouns.contains(lower) { return .pronoun }
            if verbs.contains(lower) { return .verb }
            if adjectives.contains(lower) { return .adjective }
            if adverbs.contains(lower) { return .adverb }
            if determiners.contains(lower) { return .determiner }
            if questions.contains(lower) { return .question }
            if negations.contains(lower) { return .negation }
            if social.contains(lower) { return .social }
            // If word looks like a place/thing and none matched, you might classify as noun, but
            // we keep this conservative and return nil to avoid mislabeling.
            return nil
        }

        var assigned = 0
        var recolored = 0
        for t in tiles {
            let currentPOS = t.partOfSpeech
            if currentPOS == nil || overwritePOS {
                if let pos = guessPOS(for: t.text) {
                    t.partOfSpeech = pos
                    assigned += 1
                    if setColor && (overwriteColor || t.colorHex == nil || t.colorHex?.isEmpty == true) {
                        t.colorHex = FitzgeraldKey.colorHex(for: pos, scheme: scheme)
                        recolored += 1
                    }
                }
            } else if setColor, let pos = currentPOS, (overwriteColor || t.colorHex == nil || t.colorHex?.isEmpty == true) {
                // Already has POS; optionally set color
                t.colorHex = FitzgeraldKey.colorHex(for: pos, scheme: scheme)
                recolored += 1
            }
        }

        if assigned > 0 || recolored > 0 {
            try modelContext.save()
        }
        return Result(updatedTiles: recolored, assignedPOS: assigned)
    }
}

