//
//  MessageView.swift
//  Let's Talk
//
//  Created by Eric Carroll on 7/8/23.
//

import SwiftUI
import AVFoundation
import SwiftData
import Observation

struct MessageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Speaker.self) var speaker

    @AppStorage("controlStyle") private var controlStyle: ControlsStyle = .compact
    @AppStorage("language") private var languageSetting: String = "en-US"
    @AppStorage("predictionEnabled") private var predictionEnabled: Bool = true

    enum Field { case input }
    @FocusState private var focusedField: Field?

    var favorites: [Favorite]

    @State private var suggestions: [String] = []

    var body: some View {
        @Bindable var speaker = speaker

        VStack(alignment: .leading, spacing: 12) {
            HeaderView(imageString: "ellipsis.message", textString: String(localized: "Message"), backColor: Color.clear, showButton: false)

            TextField(String(localized: "Enter your message"), text: $speaker.text, axis: .vertical)
                .foregroundColor(.primary)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .input)
                .textInputAutocapitalization(.sentences)
                .lineLimit(5...5)
                .overlay(controlsOverlay(), alignment: .topTrailing)
                .onChange(of: speaker.text) { _, _ in
                    refreshSuggestions()
                }
                .onAppear {
                    refreshSuggestions()
                }

            if predictionEnabled, !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { word in
                            Button {
                                insertSuggestion(word)
                            } label: {
                                Text(word)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.15))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                            .accessibilityLabel(Text(String(localized: "Suggestion \(word)")))
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            if controlStyle == .large {
                HStack {
                    playButton()
                    saveButton()
                }
            }
        }
        .padding()
        .border(Color.black)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button {
                        focusedField = nil
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                }
            }
        }
        .onAppear {
            // Learn from saved favorites to personalize predictions
            if predictionEnabled {
                favorites.forEach { PredictionService.shared.learn(from: $0.text, languageCode: langCode()) }
            }
        }
    }

    private func refreshSuggestions() {
        guard predictionEnabled else {
            suggestions = []
            return
        }
        suggestions = PredictionService.shared.suggestions(for: speaker.text, languageCode: langCode(), limit: 5)
    }

    private func langCode() -> String {
        languageSetting.hasPrefix("es") ? "es" : "en"
    }

    private func insertSuggestion(_ word: String) {
        var text = speaker.text
        if text.isEmpty || text.last?.isWhitespace == true {
            text += word
        } else {
            text += " " + word
        }
        speaker.text = text
        refreshSuggestions()
    }

    @MainActor
    private func saveFavorite(_ text: String) {
        let newOrder = favorites.count
        let newFavorite = Favorite(text: text, order: newOrder)
        modelContext.insert(newFavorite)

        if predictionEnabled {
            PredictionService.shared.learn(from: text, languageCode: langCode())
        }

        do {
            try modelContext.save()
        } catch {
            print("Error saving to modelContext: \(error)")
        }
    }

    // MARK: - Subviews and Helpers

    private func controlsOverlay() -> some View {
        VStack {
            clearButton()
            if controlStyle == .compact {
                playButton()
                saveButton()
            }
            Spacer()
        }
    }

    private func clearButton() -> some View {
        Button(action: {
            speaker.text = ""
            refreshSuggestions()
        }) {
            Image(systemName: "clear")
                .resizable()
                .frame(width: 25, height: 25)
                .aspectRatio(contentMode: .fit)
                .tint(Color.hunterGreen)
        }
        .accessibilityLabel(Text(String(localized: "Clear Message Box")))
    }

    private func playButton() -> some View {
        Button(action: {
            if speaker.state == .isPaused {
                speaker.continueSpeaking()
            } else {
                speaker.speak(speaker.text)
                // Log the full message to Recents
                logRecent(text: speaker.text)
            }
        }) {
            Image(systemName: "play.circle.fill")
                .resizable()
                .frame(width: 25, height: 25)
                .aspectRatio(contentMode: .fit)
                .tint(Color.hunterGreen)
        }
        .accessibilityLabel(Text(String(localized: "Play Message")))
    }

    private func saveButton() -> some View {
        Button(action: {
            if !speaker.text.isEmpty {
                saveFavorite(speaker.text)
            }
        }) {
            Image(systemName: "square.and.arrow.down")
                .resizable()
                .frame(width: 25, height: 25)
                .aspectRatio(contentMode: .fit)
                .tint(Color.hunterGreen)
        }
        .accessibilityLabel(Text(String(localized: "Save Message as Favorite")))
    }

    // MARK: - Recents logging

    private func logRecent(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let predicate = #Predicate<Recent> { $0.text == trimmed }
        var descriptor = FetchDescriptor<Recent>(predicate: predicate)
        descriptor.fetchLimit = 1
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.count += 1
            existing.timestamp = Date()
        } else {
            modelContext.insert(Recent(text: trimmed, timestamp: Date(), count: 1))
        }

        pruneRecents(maxCount: 20)
        try? modelContext.save()
    }

    private func pruneRecents(maxCount: Int) {
        var descriptor = FetchDescriptor<Recent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        if let all = try? modelContext.fetch(descriptor), all.count > maxCount {
            for r in all.dropFirst(maxCount) {
                modelContext.delete(r)
            }
        }
    }
}

#Preview {
    MessageView(favorites: [Favorite(text: "Hello World", order: 0)])
        .modelContainer(for: [Favorite.self, Recent.self], inMemory: true)
        .environment(Speaker())
}
