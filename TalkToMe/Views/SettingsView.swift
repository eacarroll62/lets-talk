//
//  Settings.swift
//  Let's Talk
//
//  Created by Eric Carroll on 7/2/23.
//

import SwiftUI
import AVFoundation
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(Speaker.self) private var speaker
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // Data to export
    @Query(sort: \Page.order) private var pages: [Page]
    @Query(sort: \Favorite.order) private var favorites: [Favorite]
    // Tiles aren’t directly queryable as a flat list with SwiftData, but we can gather from pages.
    private var allTiles: [Tile] { pages.flatMap { $0.tiles } }

    @AppStorage("identifier") private var identifier: String = "com.apple.voice.compact.en-US.Samantha"
    @AppStorage("language") private var language: String = "en-US"
    @AppStorage("rate") private var rate: Double = Double(AVSpeechUtteranceDefaultSpeechRate)
    @AppStorage("pitch") private var pitch: Double = 1.0
    @AppStorage("volume") private var volume: Double = 0.8
    @AppStorage("controlStyle") private var controlStyle: ControlsStyle = .compact

    // Audio mixing option
    @AppStorage("audioMixingOption") private var audioMixingRaw: String = Speaker.AudioMixingOption.duckOthers.rawValue

    // New: grid size preference for tiles
    enum GridSizePreference: String, CaseIterable, Identifiable {
        case small, medium, large
        var id: String { rawValue }
        var label: String {
            switch self {
            case .small: return String(localized: "Small")
            case .medium: return String(localized: "Medium")
            case .large: return String(localized: "Large")
            }
        }
    }
    @AppStorage("gridSizePreference") private var gridSizeRaw: String = GridSizePreference.medium.rawValue

    // New: prediction toggle
    @AppStorage("predictionEnabled") private var predictionEnabled: Bool = true

    @State private var availableLanguages: [String] = []
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []

    // Export / Import state
    @State private var exportURL: URL?
    @State private var isExporting: Bool = false
    @State private var isImporting: Bool = false
    @State private var lastExportError: String?

    private let rateMin = Double(AVSpeechUtteranceMinimumSpeechRate)
    private let rateMax = Double(AVSpeechUtteranceMaximumSpeechRate)

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(String(localized: "Language and Voice"))) {
                    Picker(String(localized: "Select Language"), selection: $language) {
                        ForEach(availableLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .onChange(of: language) { _, newValue in
                        refreshVoices()
                        // Reset the predictor on language change so it can re-learn for the new language
                        PredictionService.shared.reset()
                    }

                    Picker(String(localized: "Select Voice"), selection: $identifier) {
                        if availableVoices.isEmpty {
                            Text(String(localized: "No voices available")).font(.caption)
                        } else {
                            ForEach(availableVoices, id: \.identifier) { voice in
                                Text(voice.name).tag(voice.identifier)
                            }
                        }
                    }
                    .disabled(availableVoices.isEmpty)
                }

                Section(header: Text(String(localized: "Prediction"))) {
                    Toggle(String(localized: "Enable Prediction"), isOn: $predictionEnabled)
                        .accessibilityHint(Text(String(localized: "Show word suggestions while typing")))
                    Text(String(localized: "Suggestions adapt to your tiles and favorites."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text(String(localized: "Speech Settings"))) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text(String(localized: "Rate"))
                            Spacer()
                            Text("\(rate, specifier: "%.2f")")
                        }
                        Slider(value: $rate, in: rateMin...rateMax, step: 0.01)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text(String(localized: "Pitch"))
                            Spacer()
                            Text("\(pitch, specifier: "%.2f")")
                        }
                        Slider(value: $pitch, in: 0.5...2.0, step: 0.01)
                    }

                    VStack(alignment: .leading) {
                        HStack {
                            Text(String(localized: "Volume"))
                            Spacer()
                            Text("\(volume, specifier: "%.2f")")
                        }
                        Slider(value: $volume, in: 0.0...1.0, step: 0.01)
                    }

                    Button(String(localized: "Test Speech")) {
                        testSpeech()
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                    .accessibilityLabel(Text(String(localized: "Test Speech")))
                }

                Section(header: Text(String(localized: "Audio"))) {
                    Picker(String(localized: "Audio Mixing"), selection: $audioMixingRaw) {
                        Text(String(localized: "Duck Others")).tag(Speaker.AudioMixingOption.duckOthers.rawValue)
                        Text(String(localized: "Mix With Others")).tag(Speaker.AudioMixingOption.mixWithOthers.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: audioMixingRaw) { _, newValue in
                        let option = Speaker.AudioMixingOption(rawValue: newValue) ?? .duckOthers
                        speaker.setAudioMixingOption(option)
                    }
                    .accessibilityLabel(Text(String(localized: "Audio Mixing Behavior")))
                    .accessibilityHint(Text(String(localized: "Choose whether to duck or mix with other audio")))
                }

                Section(header: Text(String(localized: "Tile Size"))) {
                    Picker(String(localized: "Tile Size"), selection: $gridSizeRaw) {
                        ForEach(GridSizePreference.allCases) { size in
                            Text(size.label).tag(size.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(Text(String(localized: "Tile Size")))
                    .accessibilityHint(Text(String(localized: "Controls how many tiles fit per row")))
                }

                Section(header: Text(String(localized: "Control Settings"))) {
                    Picker(String(localized: "Display Mode"), selection: $controlStyle) {
                        ForEach(ControlsStyle.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.vertical, 4)
                }

                Section(header: Text(String(localized: "Backup"))) {
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label(String(localized: "Share Last Export"), systemImage: "square.and.arrow.up")
                        }
                    }
                    Button {
                        exportData()
                    } label: {
                        if isExporting {
                            ProgressView()
                        } else {
                            Label(String(localized: "Export Board"), systemImage: "square.and.arrow.up.on.square")
                        }
                    }
                    .disabled(isExporting)
                    .accessibilityLabel(Text(String(localized: "Export Board")))
                    .accessibilityHint(Text(String(localized: "Create a JSON export of pages, tiles, favorites")))

                    Button {
                        isImporting = true
                    } label: {
                        Label(String(localized: "Import Board"), systemImage: "square.and.arrow.down.on.square")
                    }
                    .accessibilityLabel(Text(String(localized: "Import Board")))
                    .accessibilityHint(Text(String(localized: "Import a JSON export to restore pages, tiles, favorites")))
                    .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                        switch result {
                        case .success(let url):
                            importData(from: url)
                        case .failure(let error):
                            lastExportError = error.localizedDescription
                        }
                    }

                    if let err = lastExportError {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button(String(localized: "Dismiss"), role: .destructive) {
                        dismiss()
                    }
                }
            }
            .navigationTitle(String(localized: "Settings"))
            .onAppear {
                fetchAvailableLanguages()
                refreshVoices()
                let option = Speaker.AudioMixingOption(rawValue: audioMixingRaw) ?? .duckOthers
                speaker.setAudioMixingOption(option)
            }
        }
    }

    private func fetchAvailableLanguages() {
        // Get unique languages from system voices
        availableLanguages = Array(Set(AVSpeechSynthesisVoice.speechVoices().map { $0.language }))
            .sorted()
    }

    private func refreshVoices() {
        // Refresh voices for the selected language
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(language) }

        // Reset identifier if necessary
        if !availableVoices.contains(where: { $0.identifier == identifier }) {
            identifier = availableVoices.first?.identifier ?? ""
        }
    }

    private func testSpeech() {
        let utterance = AVSpeechUtterance(string: String(localized: "This is a test speech with the current settings of the \(language) language, a rate of \(rate), a pitch of \(pitch), and a volume of \(volume) applied."))
        utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
        utterance.rate = Float(rate)
        utterance.pitchMultiplier = Float(pitch)
        utterance.volume = Float(volume)

        speaker.speak(utterance.speechString)
    }

    private func exportData() {
        isExporting = true
        lastExportError = nil
        Task {
            do {
                let url = try ExportService.exportJSON(
                    modelContext: modelContext,
                    pages: pages,
                    tiles: allTiles,
                    favorites: favorites
                )
                exportURL = url
            } catch {
                lastExportError = error.localizedDescription
            }
            isExporting = false
        }
    }

    private func importData(from url: URL) {
        lastExportError = nil
        Task {
            do {
                try ExportService.import(modelContext: modelContext, from: url)
            } catch {
                lastExportError = error.localizedDescription
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Favorite.self, Page.self, Tile.self], inMemory: true)
        .environment(Speaker())
}
