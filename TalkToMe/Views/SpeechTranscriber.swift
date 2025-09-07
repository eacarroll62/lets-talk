//
//  SpeechTranscriber.swift
//  Let's Talk
//
//  Created by Eric Carroll on 9/6/25.
//

import Foundation
import AVFoundation
import AVFAudio
import Speech

@MainActor
final class SpeechTranscriber: ObservableObject {
    @Published var isAuthorized: Bool = false
    @Published var isRecording: Bool = false
    @Published var partialText: String = ""

    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?

    // Track saved session configuration to restore after dictation
    private var savedCategory: AVAudioSession.Category?
    private var savedMode: AVAudioSession.Mode?
    private var savedOptions: AVAudioSession.CategoryOptions = []
    private var sessionConfiguredForDictation = false

    init(localeIdentifier: String? = nil) {
        if let id = localeIdentifier {
            recognizer = SFSpeechRecognizer(locale: Locale(identifier: id))
        } else {
            recognizer = SFSpeechRecognizer()
        }
    }

    func setLocale(_ identifier: String) {
        if isRecording { stop() }
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: identifier))
    }

    func requestAuthorization() async -> Bool {
        let speechOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
        let micOK = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            if #available(iOS 17.0, macOS 14.0, watchOS 10.0, tvOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    cont.resume(returning: granted)
                }
            }
        }
        isAuthorized = speechOK && micOK
        return isAuthorized
    }

    func start(onUpdate: @escaping (String) -> Void) throws {
        guard !isRecording else { return }
        guard let recognizer, recognizer.isAvailable else {
            throw NSError(domain: "SpeechTranscriber", code: -1, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
        }

        // Configure session for dictation and save previous config
        try configureSessionForDictation()

        partialText = ""
        request = SFSpeechAudioBufferRecognitionRequest()
        guard let request else {
            throw NSError(domain: "SpeechTranscriber", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create recognition request"])
        }
        request.shouldReportPartialResults = true

        let inputNode = audioEngine.inputNode
        let format = inputNode.inputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            throw NSError(domain: "SpeechTranscriber", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid audio input format"])
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result = result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.partialText = text
                    onUpdate(text)
                }
                if result.isFinal {
                    self.finishAndRestoreSession()
                }
            }
            if error != nil {
                Task { @MainActor in
                    self.finishAndRestoreSession()
                }
            }
        }

        isRecording = true
    }

    func stop() {
        guard isRecording else { return }
        finishAndRestoreSession()
    }

    // MARK: - Private

    private func finishAndRestoreSession() {
        audioEngine.stop()
        if audioEngine.inputNode.numberOfInputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        request?.endAudio()
        task?.cancel()

        task = nil
        request = nil
        isRecording = false

        // Restore the previous audio session configuration so TTS playback works immediately
        restoreSavedSessionConfiguration()
    }

    private func configureSessionForDictation() throws {
        let session = AVAudioSession.sharedInstance()

        // Save current configuration to restore later
        savedCategory = session.category
        savedMode = session.mode
        savedOptions = session.categoryOptions

        // Use playAndRecord so you can still hear prompts; defaultToSpeaker routes to speaker on iPhone
        // duckOthers keeps other audio quiet; allowBluetoothHFP supports BT mics if present
        try session.setCategory(.playAndRecord,
                                mode: .measurement,
                                options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP])
        try? session.setPreferredSampleRate(44100)
        try? session.setPreferredIOBufferDuration(0.02)
        try session.setActive(true, options: [])
        sessionConfiguredForDictation = true
    }

    private func restoreSavedSessionConfiguration() {
        guard sessionConfiguredForDictation else { return }
        sessionConfiguredForDictation = false

        let session = AVAudioSession.sharedInstance()

        // First deactivate the dictation session
        try? session.setActive(false, options: [.notifyOthersOnDeactivation])

        // Restore prior category/mode/options and reactivate so the Speaker can play immediately
        if let savedCategory, let savedMode {
            try? session.setCategory(savedCategory, mode: savedMode, options: savedOptions)
            try? session.setActive(true, options: [])
        }

        // Clear saved values
        savedCategory = nil
        savedMode = nil
        savedOptions = []
    }
}
