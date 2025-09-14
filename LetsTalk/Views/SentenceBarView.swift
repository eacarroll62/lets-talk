import SwiftUI

struct SentenceBarView: View {
    @Environment(Speaker.self) private var speaker
    @State private var showClearConfirm = false

    // Dictation
    @StateObject private var transcriber = SpeechTranscriber()
    @AppStorage("language") private var languageSetting: String = "en-US"
    @State private var isRequestingSpeechAuth = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current composed sentence
            Text(speaker.text.isEmpty ? String(localized: "Tap tiles to build your message…") : speaker.text)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .foregroundStyle(speaker.text.isEmpty ? .secondary : .primary)
                .accessibilityLabel(Text(speaker.text.isEmpty ? String(localized: "Message empty") : String(localized: "Message: \(speaker.text)")))

            // Controls row
            HStack(spacing: 12) {
                // Speak (immediate/restart)
                Button {
                    let phrase = speaker.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !phrase.isEmpty else { return }
                    haptic(.success)
                    // Immediate: stop any current utterance then start fresh
                    speaker.stop()
                    speaker.speak(phrase)
                } label: {
                    Label(String(localized: "Speak"), systemImage: "speaker.wave.2.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .disabled(speaker.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint(Text(String(localized: "Speaks the current message")))

                // Pause and Resume
                Button {
                    haptic(.light)
                    speaker.pause()
                } label: {
                    Label(String(localized: "Pause"), systemImage: "pause.fill")
                }
                .buttonStyle(.bordered)

                Button {
                    haptic(.light)
                    speaker.continueSpeaking()
                } label: {
                    Label(String(localized: "Resume"), systemImage: "play.fill")
                }
                .buttonStyle(.bordered)

                // Backspace
                Button {
                    haptic(.light)
                    backspace()
                } label: {
                    Label(String(localized: "Backspace"), systemImage: "delete.left.fill")
                }
                .buttonStyle(.bordered)
                .disabled(speaker.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint(Text(String(localized: "Remove the last word")))

                Spacer()

                // Dictation
                Button {
                    toggleDictation()
                } label: {
                    Label(
                        transcriber.isRecording ? String(localized: "Stop Dictation") : String(localized: "Dictate"),
                        systemImage: transcriber.isRecording ? "mic.slash.fill" : "mic.fill"
                    )
                }
                .buttonStyle(.bordered)

                // Copy
                Button {
                    haptic(.light)
                    copyToPasteboard()
                } label: {
                    Label(String(localized: "Copy"), systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .disabled(speaker.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                // Share
                if !speaker.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ShareLink(item: speaker.text) {
                        Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }

                // Clear
                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label(String(localized: "Clear"), systemImage: "xmark.circle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(speaker.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .confirmationDialog(
                    String(localized: "Clear Message?"),
                    isPresented: $showClearConfirm,
                    titleVisibility: .visible
                ) {
                    Button(String(localized: "Clear"), role: .destructive) {
                        haptic(.warning)
                        speaker.text = ""
                    }
                    Button(String(localized: "Cancel"), role: .cancel) {}
                } message: {
                    Text(String(localized: "This will erase the current message."))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .task {
            // Keep SpeechTranscriber in sync with language preference
            transcriber.setLocale(languageSetting)
            // Lazily request speech/mic permission if needed when the view appears
            if !transcriber.isAuthorized && !isRequestingSpeechAuth {
                isRequestingSpeechAuth = true
                _ = await transcriber.requestAuthorization()
                isRequestingSpeechAuth = false
            }
        }
        .onChange(of: languageSetting) { _, newValue in
            transcriber.setLocale(newValue)
        }
    }

    // MARK: - Actions

    private func backspace() {
        let trimmed = speaker.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var parts = trimmed.split(separator: " ").map(String.init)
        guard !parts.isEmpty else { return }
        parts.removeLast()
        speaker.text = parts.joined(separator: " ")
    }

    private func copyToPasteboard() {
        let text = speaker.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }

    private func toggleDictation() {
        if transcriber.isRecording {
            haptic(.light)
            transcriber.stop()
        } else {
            Task { @MainActor in
                if !transcriber.isAuthorized {
                    let ok = await transcriber.requestAuthorization()
                    guard ok else { return }
                }
                do {
                    haptic(.light)
                    try transcriber.start { [weak speaker] text in
                        guard let speaker else { return }
                        // Append partial/final transcription to the message seamlessly
                        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleaned.isEmpty else { return }
                        if speaker.text.isEmpty {
                            speaker.text = cleaned
                        } else {
                            // Only append the delta when possible to avoid duplicating the sentence
                            // Simple heuristic: if the new text starts with existing, append the remainder
                            if cleaned.hasPrefix(speaker.text) {
                                let remainder = String(cleaned.dropFirst(speaker.text.count)).trimmingCharacters(in: .whitespaces)
                                if !remainder.isEmpty {
                                    speaker.text += (speaker.text.hasSuffix(" ") || remainder.hasPrefix(" ") ? "" : " ") + remainder
                                }
                            } else {
                                // Fallback: replace with the best transcription
                                speaker.text = cleaned
                            }
                        }
                    }
                } catch {
                    // If starting dictation fails, ensure it’s not “stuck”
                    transcriber.stop()
                }
            }
        }
    }

    // MARK: - Haptics

    private func haptic(_ type: HapticType) {
        #if canImport(UIKit)
        switch type {
        case .light:
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
        case .success:
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        case .warning:
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.warning)
        }
        #endif
    }

    private enum HapticType { case light, success, warning }
}
