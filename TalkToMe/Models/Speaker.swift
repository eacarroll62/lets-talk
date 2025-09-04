//
//  Speaker.swift
//  TalkToMe
//
//  Created by Eric Carroll on 7/2/23.
//

import AVFoundation
import SwiftUI
import Observation

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

    // Preferences: Use a true stored property instead of @AppStorage to avoid @Observable conflict
    private var audioMixingRaw: String = UserDefaults.standard.string(forKey: "audioMixingOption") ?? AudioMixingOption.duckOthers.rawValue
    private var audioMixing: AudioMixingOption {
        get { AudioMixingOption(rawValue: audioMixingRaw) ?? .duckOthers }
        set {
            audioMixingRaw = newValue.rawValue
            // Persist to UserDefaults so SettingsView stays in sync
            UserDefaults.standard.set(audioMixingRaw, forKey: "audioMixingOption")
            configureAudioSession()
        }
    }

    override init() {
        super.init()
        synthesizer.delegate = self
        configureDefaultsIfNeeded()
        // Ensure our stored property reflects persisted value at init
        audioMixingRaw = UserDefaults.standard.string(forKey: "audioMixingOption") ?? AudioMixingOption.duckOthers.rawValue
        configureAudioSession()
    }

    deinit {
        synthesizer.delegate = nil
    }

    private func configureDefaultsIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "rate") == nil { defaults.set(0.5, forKey: "rate") }
        if defaults.object(forKey: "pitch") == nil { defaults.set(1.0, forKey: "pitch") }
        if defaults.object(forKey: "volume") == nil { defaults.set(1.0, forKey: "volume") }
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
            let options: AVAudioSession.CategoryOptions = {
                switch audioMixing {
                case .duckOthers:    return [.duckOthers]
                case .mixWithOthers: return [.mixWithOthers]
                }
            }()
            try session.setCategory(.playback, mode: .spokenAudio, options: options)
            try session.setActive(true, options: [])
        } catch {
            print("AudioSession error: \(error)")
        }
        #endif
    }

    private func startSpeechSynthesizerIfNeeded() {
        if !synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
            synthesizer.delegate = self
        }
    }

    // Resolve a robust voice selection and persist any recovered identifier
    private func resolveVoice() -> AVSpeechSynthesisVoice? {
        let defaults = UserDefaults.standard
        let savedIdentifier = defaults.string(forKey: "identifier")
        let savedLanguage = defaults.string(forKey: "language")

        // 1) Try saved identifier directly
        if let id = savedIdentifier, let v = AVSpeechSynthesisVoice(identifier: id) {
            return v
        }

        // 2) Try saved language
        if let lang = savedLanguage,
           let v = AVSpeechSynthesisVoice(language: lang) {
            defaults.set(v.identifier, forKey: "identifier")
            return v
        }

        // 3) Try preferred languages
        if let preferred = Locale.preferredLanguages.first,
           let v = AVSpeechSynthesisVoice(language: preferred) {
            defaults.set(v.identifier, forKey: "identifier")
            defaults.set(v.language, forKey: "language")
            return v
        }

        // 4) Fallback to first available
        if let v = AVSpeechSynthesisVoice.speechVoices().first {
            defaults.set(v.identifier, forKey: "identifier")
            defaults.set(v.language, forKey: "language")
            return v
        }

        return nil
    }

    // Public API: speak with optional enqueue control and interruption policy
    func speak(_ speechString: String, policy: InterruptionPolicy = .replaceCurrent) {
        // Build utterance (including our current "I" tweak)
        let utterance = buildUtterance(for: speechString)

        // Apply interruption policy
        switch policy {
        case .replaceCurrent:
            // Clear queue and stop current
            pendingUtterances.removeAll()
            if synthesizer.isSpeaking {
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
            // If nothing is playing, start now
            if !synthesizer.isSpeaking {
                dequeueAndSpeakNext()
            }
        }
    }

    // Convenience to preserve existing call sites
    func speak(_ speechString: String) {
        speak(speechString, policy: .replaceCurrent)
    }

    // Build utterance with voice, rate/pitch/volume, and IPA tweak for "I"
    private func buildUtterance(for speechString: String) -> AVSpeechUtterance {
        startSpeechSynthesizerIfNeeded()

        let defaults = UserDefaults.standard
        let selectedVoice = resolveVoice()

        // IPA/phonetic tweak for standalone "I" (kept; we can revisit later)
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

        let rate = defaults.object(forKey: "rate") as? Float ?? 0.5
        let pitch = defaults.object(forKey: "pitch") as? Float ?? 1.0
        let volume = defaults.object(forKey: "volume") as? Float ?? 1.0

        utterance.rate = max(0.1, min(rate, 0.6))
        utterance.pitchMultiplier = max(0.5, min(pitch, 2.0))
        utterance.volume = max(0.0, min(volume, 1.0))
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.1

        return utterance
    }

    private func enqueueAndStart(_ utterance: AVSpeechUtterance) {
        // If currently speaking, this will interrupt due to replaceCurrent policy
        synthesizer.speak(utterance)
    }

    private func dequeueAndSpeakNext() {
        guard !pendingUtterances.isEmpty else { return }
        let next = pendingUtterances.removeFirst()
        synthesizer.speak(next)
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
}

extension Speaker: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        self.state = .isSpeaking
        progress = 0.0
        print("Speaker: didStart")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        self.state = .isPaused
        print("Speaker: didPause")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.state = .isFinished
        progress = 1.0
        print("Speaker: didFinish")

        // If there are pending utterances, continue the queue
        if !pendingUtterances.isEmpty {
            // Reset to speaking state immediately when starting the next item
            dequeueAndSpeakNext()
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        self.state = .isContinued
        print("Speaker: didContinue")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        self.state = .isCancelled
        print("Speaker: didCancel")
        // If cancelled and we still have a queue (e.g., replace policy), start next
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
