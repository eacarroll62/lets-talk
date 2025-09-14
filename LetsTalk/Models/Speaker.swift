import AVFoundation
import SwiftUI
import Observation
import os

@MainActor
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
    private(set) var synthesizer: AVSpeechSynthesizer = .init()

    // Queue of pending utterances (FIFO)
    private var pendingUtterances: [AVSpeechUtterance] = []

    // Track when we initiated a programmatic cancel due to replaceCurrent
    private var replaceInProgress: Bool = false

    // If true, do not dequeue next item when the current one finishes (used by stopAfterCurrent)
    private var suppressAutoDequeueOnce: Bool = false

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

    // Prewarm guard
    private var hasPrewarmed: Bool = false

    // MARK: - Lifecycle

    override init() {
        super.init()
        synthesizer.delegate = self
        configureDefaultsIfNeeded()
        // Ensure our stored properties reflect persisted values at init
        audioMixingRaw = UserDefaults.standard.string(forKey: "audioMixingOption") ?? AudioMixingOption.duckOthers.rawValue
        routeToSpeaker = UserDefaults.standard.bool(forKey: "routeToSpeaker")
        configureAudioSession()
        installAudioSessionObservers()
    }

    @MainActor
    deinit {
        removeAudioSessionObservers()
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

    // Detect test environments (XCTest/XCUITest/Swift Testing)
    private var isRunningInTests: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["XCTestConfigurationFilePath"] != nil { return true }
        if ProcessInfo.processInfo.arguments.contains("UITest") { return true }
        // Swift Testing still launches under XCTest; above usually catches it.
        return NSClassFromString("XCTestCase") != nil
    }

    // MARK: - Audio Session

    private func configureAudioSession() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        // Skip configuring audio in test environments to avoid concurrency and CoreAudio server warnings
        if isRunningInTests {
            debugLog("Skipping AudioSession configuration in tests")
            return
        }

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
                options.insert(.allowBluetoothHFP)
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

    /// Public helper to re-assert our preferred audio session (useful after dictation/interruption).
    func ensureAudioSessionActive() {
        configureAudioSession()
    }

    private func installAudioSessionObservers() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleInterruption(note) }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleMediaServicesReset(note) }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in self?.handleRouteChange(note) }
        }
        #endif
    }

    private func removeAudioSessionObservers() {
        NotificationCenter.default.removeObserver(self)
    }

    private func handleInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            // Update state to reflect interruption
            if state == .isSpeaking {
                state = .isPaused
            } else {
                state = .isCancelled
            }
            debugLog("AudioSession interruption began")
        case .ended:
            // Re-assert session; do not auto-resume to avoid surprising users
            configureAudioSession()
            debugLog("AudioSession interruption ended")
        @unknown default:
            break
        }
    }

    private func handleMediaServicesReset(_ notification: Notification) {
        // Recreate synthesizer and re-apply delegate and session
        synthesizer.delegate = nil
        synthesizer = AVSpeechSynthesizer()
        synthesizer.delegate = self
        pendingUtterances.removeAll()
        state = .isCancelled
        progress = 0.0
        configureAudioSession()
        debugLog("Media services were reset; synthesizer recreated")
    }

    private func handleRouteChange(_ notification: Notification) {
        // Re-apply routing/mixing preferences after route changes
        configureAudioSession()
        debugLog("Audio route changed")
    }

    // MARK: - Voices

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

    var isSpeaking: Bool { state == .isSpeaking }
    var isBusy: Bool { state == .isSpeaking || state == .isPaused || !pendingUtterances.isEmpty }

    func speak(_ speechString: String, policy: InterruptionPolicy = .replaceCurrent) {
        speak(speechString, languageOverride: nil, policy: policy)
    }

    func speak(_ speechString: String, languageOverride: String?, policy: InterruptionPolicy = .replaceCurrent) {
        let utterance = buildUtterance(for: speechString, languageOverride: languageOverride, volumeOverride: nil)

        switch policy {
        case .replaceCurrent:
            pendingUtterances.removeAll()
            suppressAutoDequeueOnce = false
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

    /// Queue multiple words/phrases in order.
    func speak(words: [String], languageOverride: String? = nil, policy: InterruptionPolicy = .alwaysEnqueue) {
        for (idx, word) in words.enumerated() {
            let p: InterruptionPolicy = (idx == 0) ? policy : .alwaysEnqueue
            speak(word, languageOverride: languageOverride, policy: p)
        }
    }

    /// Enqueue text to play after current utterance(s).
    func enqueue(_ text: String, languageOverride: String? = nil) {
        speak(text, languageOverride: languageOverride, policy: .alwaysEnqueue)
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
        suppressAutoDequeueOnce = false
        synthesizer.stopSpeaking(at: .immediate)
        progress = 0.0
    }

    /// Let the current utterance finish, but prevent dequeuing the next one.
    func stopAfterCurrent() {
        // Clear any queued items and suppress auto-dequeue when the current finishes.
        pendingUtterances.removeAll()
        suppressAutoDequeueOnce = true
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

    // MARK: - AAC conveniences

    /// Prewarm the speech synthesizer to reduce first-utterance latency.
    /// Safe to call multiple times; only runs once per process.
    func prewarm() {
        guard !hasPrewarmed else { return }
        hasPrewarmed = true

        // Avoid in tests
        if isRunningInTests { return }

        // Use a very short, near-silent utterance.
        let warmup = buildUtterance(for: "•", languageOverride: nil, volumeOverride: 0.0)
        warmup.preUtteranceDelay = 0.0
        warmup.postUtteranceDelay = 0.0

        // Do not interrupt current speech; enqueue only if idle.
        if !synthesizer.isSpeaking && pendingUtterances.isEmpty {
            enqueueAndStart(warmup)
        }
    }

    /// Speak a reduced-volume preview (useful for focus/hover/long-press).
    /// Uses enqueueIfSpeaking so it doesn’t interrupt active speech.
    func preview(_ text: String, languageOverride: String? = nil, volume: Float = 0.33) {
        let u = buildUtterance(for: text, languageOverride: languageOverride, volumeOverride: max(0.0, min(volume, 1.0)))
        if synthesizer.isSpeaking || !pendingUtterances.isEmpty {
            pendingUtterances.append(u)
        } else {
            enqueueAndStart(u)
        }
    }

    // MARK: - Utterance building

    private func buildUtterance(for speechString: String, languageOverride: String? = nil, volumeOverride: Float?) -> AVSpeechUtterance {
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
        // Allow a one-off volume override (for previews/prewarm)
        if let v = volumeOverride {
            utterance.volume = max(0.0, min(v, 1.0))
        } else {
            utterance.volume = max(0.0, min(Float(volumeDouble), 1.0))
        }
        utterance.preUtteranceDelay = 0.0
        utterance.postUtteranceDelay = 0.1

        return utterance
    }

    private func enqueueAndStart(_ utterance: AVSpeechUtterance) {
        progress = 0.0
        synthesizer.speak(utterance)
    }

    private func dequeueAndSpeakNext() {
        guard !pendingUtterances.isEmpty else { return }
        let next = pendingUtterances.removeFirst()
        progress = 0.0
        synthesizer.speak(next)
    }
}

nonisolated(unsafe) extension Speaker: AVSpeechSynthesizerDelegate {
    @MainActor
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        self.state = .isSpeaking
        progress = 0.0
        debugLog("didStart")
    }

    @MainActor
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        self.state = .isPaused
        debugLog("didPause")
    }

    @MainActor
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        self.state = .isFinished
        progress = 1.0
        debugLog("didFinish")
        if suppressAutoDequeueOnce {
            // Consume the suppression once, then return to normal behavior
            suppressAutoDequeueOnce = false
            return
        }
        if !pendingUtterances.isEmpty {
            dequeueAndSpeakNext()
        }
    }

    @MainActor
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        self.state = .isContinued
        debugLog("didContinue")
    }

    @MainActor
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

    @MainActor
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
