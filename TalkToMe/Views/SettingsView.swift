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
    @Query(sort: \QuickPhrase.order) private var quickPhrases: [QuickPhrase]
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

    // Guided edit lock
    @AppStorage("editLocked") private var editLocked: Bool = true

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

    // Quick Phrases editing
    @State private var newQuickPhrase: String = ""
    @State private var isEditingQuickPhrases: Bool = false
    @State private var qpEdits: [UUID: String] = [:]
    @State private var confirmDeleteQP: QuickPhrase?

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

                // Quick Phrases editor
                Section(
                    header: Text(String(localized: "Quick Phrases")),
                    footer: quickPhrasesFooter()
                ) {
                    HStack {
                        TextField(String(localized: "Add new phrase"), text: $newQuickPhrase)
                            .textInputAutocapitalization(.sentences)
                            .disabled(editLocked)
                            .opacity(editLocked ? 0.5 : 1.0)
                        Button {
                            addQuickPhrase()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(editLocked || !canAddNewQuickPhrase())
                        .opacity((editLocked || !canAddNewQuickPhrase()) ? 0.5 : 1.0)
                        .accessibilityLabel(Text(String(localized: "Add Quick Phrase")))
                    }

                    if quickPhrases.isEmpty {
                        Text(String(localized: "No quick phrases yet. Add one above."))
                            .foregroundStyle(.secondary)
                    } else {
                        List {
                            ForEach(quickPhrases) { qp in
                                quickPhraseRow(qp)
                            }
                            // Guard reordering by lock
                            .onMove { source, destination in
                                if !editLocked {
                                    moveQuickPhrases(from: source, to: destination)
                                }
                            }
                        }
                        .frame(minHeight: 150, maxHeight: 260)
                        .environment(\.editMode, .constant(isEditingQuickPhrases && !editLocked ? .active : .inactive))

                        Toggle(String(localized: "Reorder Mode"), isOn: $isEditingQuickPhrases)
                            .disabled(editLocked)
                            .opacity(editLocked ? 0.5 : 1.0)
                            .accessibilityHint(Text(String(localized: "Enable to drag and reorder quick phrases")))
                    }
                }

                // Backup section
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

                // Admin (Guided Edit Lock) + Development
                Section(header: Text(String(localized: "Admin"))) {
                    if editLocked {
                        Button {
                            authenticateAndUnlock()
                        } label: {
                            Label(String(localized: "Unlock Editing"), systemImage: "lock.fill")
                        }
                        .tint(.blue)
                    } else {
                        Button(role: .destructive) {
                            editLocked = true
                        } label: {
                            Label(String(localized: "Lock Editing"), systemImage: "lock.open.fill")
                        }
                    }
                    Text(editLocked ? String(localized: "Editing is locked. Long-press and Edit Mode are disabled.") :
                         String(localized: "Editing is unlocked. You can edit and delete tiles and pages."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

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
            .confirmationDialog(
                String(localized: "Delete Quick Phrase?"),
                isPresented: Binding(
                    get: { confirmDeleteQP != nil },
                    set: { if !$0 { confirmDeleteQP = nil } }
                ),
                titleVisibility: .visible
            ) {
                if let qp = confirmDeleteQP {
                    Button(String(localized: "Delete"), role: .destructive) {
                        deleteQuickPhrase(qp)
                    }
                }
                Button(String(localized: "Cancel"), role: .cancel) { confirmDeleteQP = nil }
            } message: {
                if let qp = confirmDeleteQP {
                    Text(String(localized: "Are you sure you want to delete “\(qp.text)”?"))
                }
            }
        }
    }

    // MARK: - Quick Phrases

    private func quickPhrasesFooter() -> some View {
        Group {
            if editLocked {
                Text(String(localized: "Editing is locked. Unlock in Settings > Admin to modify quick phrases."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if !newQuickPhrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !canAddNewQuickPhrase() {
                Text(String(localized: "This phrase already exists."))
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func quickPhraseRow(_ qp: QuickPhrase) -> some View {
        HStack {
            if let editing = qpEdits[qp.id] {
                TextField(String(localized: "Edit phrase"), text: Binding(
                    get: { editing },
                    set: { qpEdits[qp.id] = $0 }
                ))
                .disabled(editLocked)
                .opacity(editLocked ? 0.6 : 1.0)

                Button {
                    saveQuickPhraseEdit(qp)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .disabled(editLocked || !canSaveEdit(for: qp))
                .opacity((editLocked || !canSaveEdit(for: qp)) ? 0.5 : 1.0)

                Button {
                    qpEdits.removeValue(forKey: qp.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .disabled(editLocked)
                .opacity(editLocked ? 0.5 : 1.0)
            } else {
                Text(qp.text)
                    .lineLimit(1)
                Spacer()
                Button {
                    if !editLocked {
                        qpEdits[qp.id] = qp.text
                    }
                } label: {
                    Image(systemName: "pencil")
                }
                .disabled(editLocked)
                .opacity(editLocked ? 0.5 : 1.0)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                if !editLocked {
                    confirmDeleteQP = qp
                }
            } label: {
                Label(String(localized: "Delete"), systemImage: "trash")
            }
            .disabled(editLocked)
        }
    }

    private func canAddNewQuickPhrase() -> Bool {
        let text = newQuickPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return false }
        return !quickPhrases.contains { $0.text.caseInsensitiveCompare(text) == .orderedSame }
    }

    private func canSaveEdit(for qp: QuickPhrase) -> Bool {
        guard let text = qpEdits[qp.id]?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return false
        }
        // Allow unchanged text
        if text.caseInsensitiveCompare(qp.text) == .orderedSame { return true }
        // Prevent duplicates against others
        return !quickPhrases.contains { $0.id != qp.id && $0.text.caseInsensitiveCompare(text) == .orderedSame }
    }

    private func addQuickPhrase() {
        guard !editLocked else { return }
        let text = newQuickPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard !quickPhrases.contains(where: { $0.text.caseInsensitiveCompare(text) == .orderedSame }) else { return }
        let nextOrder = (quickPhrases.map { $0.order }.max() ?? -1) + 1
        modelContext.insert(QuickPhrase(text: text, order: nextOrder))
        try? modelContext.save()
        newQuickPhrase = ""
    }

    private func saveQuickPhraseEdit(_ qp: QuickPhrase) {
        guard !editLocked else { return }
        guard let newText = qpEdits[qp.id]?.trimmingCharacters(in: .whitespacesAndNewlines), !newText.isEmpty else { return }
        // Duplicate check included in canSaveEdit
        guard canSaveEdit(for: qp) else { return }
        qp.text = newText
        qpEdits.removeValue(forKey: qp.id)
        try? modelContext.save()
    }

    private func deleteQuickPhrase(_ qp: QuickPhrase) {
        guard !editLocked else { return }
        modelContext.delete(qp)
        // Reindex orders
        let ordered = quickPhrases.sorted(by: { $0.order < $1.order })
        for (i, item) in ordered.enumerated() { item.order = i }
        try? modelContext.save()
    }

    private func moveQuickPhrases(from source: IndexSet, to destination: Int) {
        var ordered = quickPhrases.sorted(by: { $0.order < $1.order })
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, qp) in ordered.enumerated() {
            qp.order = i
        }
        try? modelContext.save()
    }

    // MARK: - Auth

    private func authenticateAndUnlock() {
        Task {
            let success = await AuthService.authenticate(reason: String(localized: "Unlock editing to modify tiles and pages."))
            if success {
                editLocked = false
            }
        }
    }

    // MARK: - Voice

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

    // MARK: - Backup

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

