import SwiftUI

struct SentenceBarView: View {
    @Environment(Speaker.self) private var speaker
    @State private var showClearConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Current composed sentence
            Text(speaker.text.isEmpty ? String(localized: "Tap tiles to build your message…") : speaker.text)
                .font(.title3.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .foregroundStyle(speaker.text.isEmpty ? .secondary : .primary)
                .accessibilityLabel(Text(speaker.text.isEmpty ? String(localized: "Message empty") : String(localized: "Message: \(speaker.text)")))

            HStack(spacing: 12) {
                Button {
                    let phrase = speaker.text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !phrase.isEmpty else { return }
                    speaker.speakImmediately(phrase)
                } label: {
                    Label(String(localized: "Speak"), systemImage: "speaker.wave.2.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(Text(String(localized: "Speaks the current message")))

                Button {
                    backspace()
                } label: {
                    Label(String(localized: "Backspace"), systemImage: "delete.left.fill")
                }
                .buttonStyle(.bordered)
                .disabled(speaker.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityHint(Text(String(localized: "Remove the last word")))

                Spacer()

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
                    Button(String(localized: "Clear"), role: .destructive) { speaker.text = "" }
                    Button(String(localized: "Cancel"), role: .cancel) {}
                } message: {
                    Text(String(localized: "This will erase the current message."))
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func backspace() {
        let trimmed = speaker.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var parts = trimmed.split(separator: " ").map(String.init)
        guard !parts.isEmpty else { return }
        parts.removeLast()
        speaker.text = parts.joined(separator: " ")
    }
}
