//
//  Settings.swift
//  TalkToMe
//
//  Created by Eric Carroll on 7/2/23.
//

import SwiftUI
import AVFoundation

struct SettingsView: View {
    @Environment(Speaker.self) private var speaker
    @Environment(\.dismiss) private var dismiss
    
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
            case .small: return "Small"
            case .medium: return "Medium"
            case .large: return "Large"
            }
        }
    }
    @AppStorage("gridSizePreference") private var gridSizeRaw: String = GridSizePreference.medium.rawValue

    @State private var availableLanguages: [String] = []
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []
    
    private let rateMin = Double(AVSpeechUtteranceMinimumSpeechRate)
    private let rateMax = Double(AVSpeechUtteranceMaximumSpeechRate)

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Language and Voice")) {
                    Picker("Select Language", selection: $language) {
                        ForEach(availableLanguages, id: \.self) { lang in
                            Text(lang).tag(lang)
                        }
                    }
                    .onChange(of: language) { _, _ in
                        refreshVoices()
                    }
                    
                    Picker("Select Voice", selection: $identifier) {
                        if availableVoices.isEmpty {
                            Text("No voices available").font(.caption)
                        } else {
                            ForEach(availableVoices, id: \.identifier) { voice in
                                Text(voice.name).tag(voice.identifier)
                            }
                        }
                    }
                    .disabled(availableVoices.isEmpty)
                }
                
                Section(header: Text("Speech Settings")) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Rate")
                            Spacer()
                            Text("\(rate, specifier: "%.2f")")
                        }
                        Slider(value: $rate, in: rateMin...rateMax, step: 0.01)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Pitch")
                            Spacer()
                            Text("\(pitch, specifier: "%.2f")")
                        }
                        Slider(value: $pitch, in: 0.5...2.0, step: 0.01)
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Volume")
                            Spacer()
                            Text("\(volume, specifier: "%.2f")")
                        }
                        Slider(value: $volume, in: 0.0...1.0, step: 0.01)
                    }
                    
                    Button("Test Speech") {
                        testSpeech()
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                }

                Section(header: Text("Audio")) {
                    Picker("Audio Mixing", selection: $audioMixingRaw) {
                        Text("Duck Others").tag(Speaker.AudioMixingOption.duckOthers.rawValue)
                        Text("Mix With Others").tag(Speaker.AudioMixingOption.mixWithOthers.rawValue)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: audioMixingRaw) { _, newValue in
                        let option = Speaker.AudioMixingOption(rawValue: newValue) ?? .duckOthers
                        speaker.setAudioMixingOption(option)
                    }
                    .accessibilityLabel("Audio Mixing Behavior")
                    .accessibilityHint("Choose whether to duck or mix with other audio")
                }

                // New: Tile Size
                Section(header: Text("Tile Size")) {
                    Picker("Tile Size", selection: $gridSizeRaw) {
                        ForEach(GridSizePreference.allCases) { size in
                            Text(size.label).tag(size.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel("Tile Size")
                    .accessibilityHint("Controls how many tiles fit per row")
                }
                
                Section(header: Text("Control Settings")) {
                    Picker("Display Mode", selection: $controlStyle) {
                        ForEach(ControlsStyle.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()
                }
                
                Section {
                    Button("Dismiss", role: .destructive) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                fetchAvailableLanguages()
                refreshVoices()
                // Ensure the speaker reflects the stored audio mixing on entry
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
        let utterance = AVSpeechUtterance(string: "This is a test speech with the current settings of the \(language) language, a rate of \(rate), a pitch of \(pitch), and a volume of \(volume) applied.")
        utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
        utterance.rate = Float(rate)
        utterance.pitchMultiplier = Float(pitch)
        utterance.volume = Float(volume)
        
        speaker.speak(utterance.speechString)
    }
}

#Preview {
    SettingsView()
        .environment(Speaker())
}
