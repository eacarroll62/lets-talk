//
//  Speaker.swift
//  TalkToMe
//
//  Created by Eric Carroll on 7/2/23.
//

import AVFoundation
import SwiftUI
import Observation
import os

@Observable final class Speaker: NSObject {
    // Public observable state
    var state: SpeechState = .isFinished
    var text: String = ""
    // Normalized progress in 0.0 ... 1.0
    var progress: Double = 0.0

    enum SpeechState: String {
        case isFinished, isSpeaking, isPaused, isCancelled, isContinued
    }

    // Interruption policy for new speak requests
    enum InterruptionPolicy: String {
        case replaceCurrent    // stop current and speak immediately
        case enqueueIfSpeaking // enqueue if speaking, otherwise speak now
        case alwaysEnqueue     // always enqueue after current queue
    }

    // Audio mixing option
    enum AudioMixingOption: String {
        case duckOthers
        case mixWithOthers
    }

    // Synthesizer
    let synthesizer: AVSpeechSynthesizer = .init()

    // Queue of pending utterances (FIFO)
    private var pendingUtterances: [AVSpeechUtterance] = []

    // Track when we initiated a programmatic cancel due to replaceCurrent
    private var replaceInProgress: Bool = false

    // Preferences: Use a true stored property instead of @AppStorage to avoid @Observable conflict
    private var audioMixingRaw: String = UserDefaults.standard.string(forKey: "audioMixingOption") ?? AudioMixingOption.duckOthers.rawValue
    private var audioMixing: AudioMixingOption {
        get { AudioMixingOption(rawValue: audioMixingRaw) ?? .duckOthers }
        set {
            audioMixingRaw = newValue.rawValue
            UserDefaults.standard.set(audioMixingRaw, forKey: "audioMixingOption")
            configureAudioSession()
        }
    }

    // Routing option (persisted): route playback to device speaker
    private var routeToSpeaker: Bool = UserDefaults.standard.bool(forKey: "routeToSpeaker")

    // UserDefaults key prefix for per-language voice identifiers
    private let perLanguageVoiceKeyPrefix = "voice.identifier."

    // Logger
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "LetsTalk", category: "Speaker")

    override init() {
        super.init()
        synthesizer.delegate = self
        configureDefaultsIfNeeded()
        // Ensure our stored properties reflect persisted values at init
        audioMixingRaw = UserDefaults.standard.string(forKey: "audioMixingOption") ?? AudioMixingOption.duckOthers.rawValue
        routeToSpeaker = UserDefaults.standard.bool(forKey: "routeToSpeaker")
        configureAudioSession()
    }

    deinit {
        synthesizer.delegate = nil
    }

    private func configureDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        // Keep defaults aligned with SettingsView slider and Apple constants
        if defaults.object(forKey: "rate") == nil {
            defaults.set(Double(AVSpeechUtteranceDefaultSpeechRate), forKey: "rate")
        }
        if defaults.object(forKey: "pitch") == nil { defaults.set(1.0, forKey: "pitch") }
        // Match SettingsView default volume exactly (0.8)
        if defaults.object(forKey: "volume") == nil { defaults.set(0.8, forKey: "volume") }
        // Seed a default identifier if none saved (best-effort)
        if defaults.string(forKey: "identifier") == nil {
            if let lang = Locale.preferredLanguages.first,
               let voice = AVSpeechSynthesisVoice(language: lang) {
                defaults.set(voice.identifier, forKey: "identifier")
                defaults.set(voice.language, forKey: "language")
            } else if let first = AVSpeechSynthesisVoice.speechVoices().first {
                defaults.set(first.identifier, forKey: "identifier")
                defaults.set(first.language, forKey: "language")
            }
        }
        // Seed audio mixing option if missing
        if defaults.string(forKey: "audioMixingOption") == nil {
            defaults.set(AudioMixingOption.duckOthers.rawValue, forKey: "audioMixingOption")
        }
    }

    private func configureAudioSession() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        do {
            let mixingOptions: AVAudioSession.CategoryOptions = {
                switch audioMixing {
                case .duckOthers:    return [.duckOthers]
                case .mixWithOthers: return [.mixWithOthers]
                }
            }()

            if routeToSpeaker {
                var options: AVAudioSession.CategoryOptions = mixingOptions.union([.defaultToSpeaker])
                options.insert(.allowBluetooth)
                try session.setCategory(.playAndRecord, mode: .spokenAudio, options: options)
            } else {
                try session.setCategory(.playback, mode: .spokenAudio, options: mixingOptions)
            }

            try session.setActive(true, options: [])
            debugLog("AudioSession configured. routeToSpeaker=\(self.routeToSpeaker), mixing=\(self.audioMixing.rawValue)")
        } catch {
            errorLog("AudioSession error: \(error.localizedDescription)")
        }
        #endif
    }

    private func startSpeechSynthesizerIfNeeded() {
        if !synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            synthesizer.delegate = self
        }
    }

    // Resolve a robust voice selection and persist any recovered identifier (default path)
    private func resolveDefaultVoice() -> AVSpeechSynthesisVoice? {
        let defaults = UserDefaults.standard
        let savedIdentifier = defaults.string(forKey: "identifier")
        let savedLanguage = defaults.string(forKey: "language")

        if let id = savedIdentifier, let v = AVSpeechSynthesisVoice(identifier: id) {
            return v
        }
        if let lang = savedLanguage, let v = AVSpeechSynthesisVoice(language: lang) {
            defaults.set(v.identifier, forKey: "identifier")
            return v
        }
        if let preferred = Locale.preferredLanguages.first,
           let v = AVSpeechSynthesisVoice(language: preferred) {
            defaults.set(v.identifier, forKey: "identifier")
            defaults.set(v.language, forKey: "language")
            return v
        }
        if let v = AVSpeechSynthesisVoice.speechVoices().first {
            defaults.set(v.identifier, forKey: "identifier")
            defaults.set(v.language, forKey: "language")
            return v
        }
        return nil
    }

    // Resolve a voice for a preferred language (e.g., "en", "es", or "en-US").
    // Optionally persists the chosen identifier per language tag for future use.
    private func resolveVoice(preferredLanguage rawCode: String?) -> AVSpeechSynthesisVoice? {
        guard let rawCode, !rawCode.isEmpty else {
            return resolveDefaultVoice()
        }

        let langTag = bestLanguageTag(for: rawCode)
        let defaults = UserDefaults.standard

        // 1) Try per-language saved identifier
        let perLangKey = perLanguageVoiceKeyPrefix + langTag
        if let id = defaults.string(forKey: perLangKey),
           let v = AVSpeechSynthesisVoice(identifier: id) {
            return v
        }

        // 2) Try exact language tag
        if let v = AVSpeechSynthesisVoice(language: langTag) {
            defaults.set(v.identifier, forKey: perLangKey)
            return v
        }

        // 3) Try prefix match (e.g., "en" -> first "en-*" voice)
        if let v = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix(rawCode) }) {
            defaults.set(v.identifier, forKey: perLangKey)
            return v
        }

        // 4) Fallback to default voice
        return resolveDefaultVoice()
    }

    // Map short code to a best-available BCP-47 tag among installed voices.
    private func bestLanguageTag(for code: String) -> String {
        if code.contains("-") { return code }
        if let match = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language.hasPrefix(code) }) {
            return match.language
        }
        switch code.lowercased() {
        case "en": return "en-US"
        case "es": return "es-ES"
        default:   return code
        }
    }

    // MARK: - Public API

    func speak(_ speechString: String, policy: InterruptionPolicy = .replaceCurrent) {
        speak(speechString, languageOverride: nil, policy: policy)
    }

    func speak(_ speechString: String, languageOverride: String?, policy: InterruptionPolicy = .replaceCurrent) {
        let utterance = buildUtterance(for: speechString, languageOverride: languageOverride)

        switch policy {
        case .replaceCurrent:
            pendingUtterances.removeAll()
            if synthesizer.isSpeaking {
                replaceInProgress = true
                synthesizer.stopSpeaking(at: .immediate)
            }
            enqueueAndStart(utterance)

        case .enqueueIfSpeaking:
            if synthesizer.isSpeaking || !pendingUtterances.isEmpty {
                pendingUtterances.append(utterance)
            } else {
                enqueueAndStart(utterance)
            }

        case .alwaysEnqueue:
            pendingUtterances.append(utterance)
            if !synthesizer.isSpeaking {
                dequeueAndSpeakNext()
            }
        }
    }

    func speakImmediately(_ speechString: String, languageOverride: String? = nil) {
        speak(speechString, languageOverride: languageOverride, policy: .replaceCurrent)
    }

    func clearQueue() {
        pendingUtterances.removeAll()
    }

    func pause() {
        synthesizer.pauseSpeaking(at: .word)
    }

    func stop() {
        pendingUtterances.removeAll()
        synthesizer.stopSpeaking(at: .immediate)
    }

    func continueSpeaking() {
        synthesizer.continueSpeaking()
    }

    // Expose a way to toggle audio mixing at runtime if needed
    func setAudioMixingOption(_ option: AudioMixingOption) {
        audioMixing = option
    }

    // Toggle audio routing to the device speaker
    func setAudioRouting(toSpeaker: Bool) {
        routeToSpeaker = toSpeaker
        UserDefaults.standard.set(toSpeaker, forKey: "routeToSpeaker")
        configureAudioSession()
    }

    // MARK: - Utterance building

    private func buildUtterance(for speechString: String, languageOverride: String? = nil) -> AVSpeechUtterance {
        startSpeechSynthesizerIfNeeded()

        let defaults = UserDefaults.standard
        let selectedVoice = resolveVoice(preferredLanguage: languageOverride)

        // IPA/phonetic tweak for standalone "I"
        let ipaKey = NSAttributedString.Key("com.apple.speech.synthesis.IPANotation")
        let phoneticKey = NSAttributedString.Key("com.apple.speech.synthesis.PhoneticPronunciation")
        let ipaValue = "aɪ"

        var usedAttributed = false
        let attributed = NSMutableAttributedString(string: speechString)

        if let regex = try? NSRegularExpression(pattern: #"(?<!\p{L})I(?!\p{L})"#, options: []) {
            let fullRange = NSRange(location: 0, length: (speechString as NSString).length)
            let matches = regex.matches(in: speechString, options: [], range: fullRange)
            for match in matches {
                attributed.addAttribute(ipaKey, value: ipaValue, range: match.range)
                attributed.addAttribute(phoneticKey, value: ipaValue, range: match.range)
                usedAttributed = true
            }
        }

        let utterance: AVSpeechUtterance = usedAttributed
            ? AVSpeechUtterance(attributedString: attributed)
            : AVSpeechUtterance(string: speechString)

        utterance.voice = selectedVoice

        // Read settings as Double (matching SettingsView) and clamp using Apple’s constants
        let rateDouble = (defaults.object(forKey: "rate") as? Double) ?? Double(AVSpeechUtteranceDefaultSpeechRate)
        let pitchDouble = (defaults.object(forKey: "pitch") as? Double) ?? 1.0
        let volumeDouble = (defaults.object(forKey: "volume") as? Double) ?? 0.8

        let minRate = Double(AVSpeechUtteranceMinimumSpeechRate)
        let maxRate = Double(AVSpeechUtteranceMaximumSpeechRate)
        let clampedRate = max(minRate, min(rateDouble, maxRate))

        utterance.rate = Float(clampedRate)
        utterance.pitchMultiplier = max(0.5, min(Float(pitchDouble), 2.0))
        utterance.volume = max(0.0, min(Float(volumeDouble), 1.0))
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.1

        return utterance
    }

    private func enqueueAndStart(_ utterance: AVSpeechUtterance) {
        synthesizer.speak(utterance)
    }

    private func dequeueAndSpeakNext() {
        guard !pendingUtterances.isEmpty else { return }
        let next = pendingUtterances.removeFirst()
        synthesizer.speak(next)
    }
}

extension Speaker: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        self.state = .isSpeaking
        progress = 0.0
        debugLog("didStart")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        self.state = .isPaused
        debugLog("didPause")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.state = .isFinished
        progress = 1.0
        debugLog("didFinish")
        if !pendingUtterances.isEmpty {
            dequeueAndSpeakNext()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        self.state = .isContinued
        debugLog("didContinue")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        self.state = .isCancelled
        debugLog("didCancel")
        if replaceInProgress {
            replaceInProgress = false
            return
        }
        if !pendingUtterances.isEmpty {
            dequeueAndSpeakNext()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer,
                           willSpeakRangeOfSpeechString characterRange: NSRange,
                           utterance: AVSpeechUtterance) {
        let totalLength = (utterance.speechString as NSString).length
        guard totalLength > 0 else {
            progress = 0.0
            return
        }
        let currentLength = characterRange.location + characterRange.length
        progress = min(1.0, max(0.0, Double(currentLength) / Double(totalLength)))
    }
}

// MARK: - Logging helpers

private extension Speaker {
    func debugLog(_ message: StaticString) {
        #if DEBUG
        logger.debug("\(message)")
        #endif
    }

    func debugLog(_ message: String) {
        #if DEBUG
        logger.debug("\(message, privacy: .public)")
        #endif
    }

    func errorLog(_ message: String) {
        logger.error("\(message, privacy: .public)")
    }
}
