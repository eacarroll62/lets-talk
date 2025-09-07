// VoiceSelection.swift
import AVFoundation

enum VoicePicker {
    static func bestVoice(for bcp47: String) -> AVSpeechSynthesisVoice? {
        let all = AVSpeechSynthesisVoice.speechVoices()
        guard !all.isEmpty else { return nil }

        // Normalize
        let normalized = bcp47.replacingOccurrences(of: "_", with: "-")
        let lower = normalized.lowercased()

        // Split primary (e.g., "pt" from "pt-BR")
        let parts = lower.split(separator: "-")
        let primary = parts.first.map(String.init) ?? lower

        // Helper to sort by quality (if available) and name
        func sortedByQuality(_ voices: [AVSpeechSynthesisVoice]) -> [AVSpeechSynthesisVoice] {
            voices.sorted { a, b in
                if a.quality != b.quality { return a.quality.rawValue > b.quality.rawValue }
                return a.name < b.name
            }
        }

        // 1) Exact language match (case-insensitive), e.g., "pt-BR"
        if let exact = sortedByQuality(all.filter { $0.language.lowercased() == lower }).first {
            return exact
        }

        // 2) Region-insensitive match (starts with primary + "-")
        if let regional = sortedByQuality(all.filter { $0.language.lowercased().hasPrefix(primary + "-") }).first {
            return regional
        }

        // 3) Base language match (exact primary), e.g., "pt"
        if let base = sortedByQuality(all.filter { $0.language.lowercased() == primary }).first {
            return base
        }

        // 4) Fallback: first voice where language contains primary (very loose)
        if let loose = sortedByQuality(all.filter { $0.language.lowercased().contains(primary) }).first {
            return loose
        }

        // 5) Absolute fallback: system default voice
        return AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
    }

    static func bestVoiceIdentifier(for bcp47: String) -> String? {
        bestVoice(for: bcp47)?.identifier
    }
}
