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

    @Query(sort: \Page.order) private var pages: [Page]
    @Query(sort: \Favorite.order) private var favorites: [Favorite]
    private var allTiles: [Tile] { pages.flatMap { $0.tiles } }

    @AppStorage("identifier") private var identifier: String = "com.apple.voice.compact.en-US.Samantha"
    @AppStorage("language") private var language: String = "en-US"
    @AppStorage("rate") private var rate: Double = Double(AVSpeechUtteranceDefaultSpeechRate)
    @AppStorage("pitch") private var pitch: Double = 1.0
    @AppStorage("volume") private var volume: Double = 0.8
    @AppStorage("controlStyle") private var controlStyle: ControlsStyle = .compact
    @AppStorage("audioMixingOption") private var audioMixingRaw: String = Speaker.AudioMixingOption.duckOthers.rawValue
    @AppStorage("gridSizePreference") private var gridSizeRaw: String = GridSizePreference.medium.rawValue
    @AppStorage("predictionEnabled") private var predictionEnabled: Bool = true

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

    @State private var availableLanguages: [String] = []
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []

    // Export / Import state
    @State private var exportURL: URL?
    @State private var isExporting: Bool = false
    @State private var isImporting: Bool = false
    @State private var lastExportError: String?

    // Development
    @State private var showReseedConfirm: Bool = false

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
                    .onChange(of: language) { _, _ in
                        refreshVoices()
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
                }

                Section(header: Text(String(localized: "Tile Size"))) {
                    Picker(String(localized: "Tile Size"), selection: $gridSizeRaw) {
                        ForEach(GridSizePreference.allCases) { size in
                            Text(size.label).tag(size.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
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

                // Backup section (unchanged content you already have)
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

                    Button {
                        isImporting = true
                    } label: {
                        Label(String(localized: "Import Board"), systemImage: "square.and.arrow.down.on.square")
                    }
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

                // Development section
                Section(header: Text(String(localized: "Development"))) {
                    Button(role: .destructive) {
                        showReseedConfirm = true
                    } label: {
                        Label(String(localized: "Reseed Starter Pages"), systemImage: "arrow.counterclockwise.circle")
                    }
                    .confirmationDialog(
                        String(localized: "Reseed Starter Pages?"),
                        isPresented: $showReseedConfirm,
                        titleVisibility: .visible
                    ) {
                        Button(String(localized: "Reseed"), role: .destructive) {
                            SeedingService.reseedAll(modelContext: modelContext)
                        }
                        Button(String(localized: "Cancel"), role: .cancel) {}
                    } message: {
                        Text(String(localized: "This will delete all pages, tiles, favorites, recents, quick phrases, and images, then rebuild the starter board."))
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
        availableLanguages = Array(Set(AVSpeechSynthesisVoice.speechVoices().map { $0.language })).sorted()
    }

    private func refreshVoices() {
        availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(language) }
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
        .modelContainer(for: [Favorite.self, Page.self, Tile.self, Recent.self, QuickPhrase.self], inMemory: true)
        .environment(Speaker())
}
