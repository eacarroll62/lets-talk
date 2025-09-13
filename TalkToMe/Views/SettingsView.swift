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
import LocalAuthentication

struct SettingsView: View {
    @Environment(Speaker.self) private var speaker
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

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
    @AppStorage("customGridColumns") private var customGridColumns: Int = 4
    @AppStorage("predictionEnabled") private var predictionEnabled: Bool = true
    @AppStorage("routeToSpeaker") private var routeToSpeaker: Bool = false

    // Interaction preferences
    @AppStorage("selectionBehavior") private var selectionBehaviorRaw: String = SelectionBehavior.both.rawValue
    @AppStorage("largeTouchTargets") private var largeTouchTargets: Bool = false
    @AppStorage("autoRelockOnBackground") private var autoRelockOnBackground: Bool = true

    // New: Scanning and dwell preferences
    @AppStorage("scanningEnabled") private var scanningEnabled: Bool = false
    @AppStorage("scanningMode") private var scanningModeRaw: String = ScanningMode.step.rawValue
    @AppStorage("scanInterval") private var scanInterval: Double = 1.2 // seconds
    @AppStorage("auditoryPreviewOnFocus") private var auditoryPreviewOnFocus: Bool = false
    @AppStorage("dwellEnabled") private var dwellEnabled: Bool = false
    @AppStorage("dwellTime") private var dwellTime: Double = 0.9 // seconds

    // View visibility toggles
    @AppStorage("showNavTiles") private var showNavTiles: Bool = true
    @AppStorage("showAddTileButton") private var showAddTileButton: Bool = true
    @AppStorage("showBottomActionBar") private var showBottomActionBar: Bool = true
    @AppStorage("showSentenceBar") private var showSentenceBar: Bool = true
    @AppStorage("showQuickPhrases") private var showQuickPhrases: Bool = true
    @AppStorage("showRecents") private var showRecents: Bool = true

    // Guided edit lock
    @AppStorage("editLocked") private var editLocked: Bool = true

    // AAC color scheme
    @AppStorage("aacColorScheme") private var aacColorSchemeRaw: String = AACColorScheme.fitzgerald.rawValue

    // User info
    @AppStorage("userPreferredName") private var userPreferredName: String = ""

    enum GridSizePreference: String, CaseIterable, Identifiable {
        case small, medium, large, extraLarge, custom
        var id: String { rawValue }
        var label: String {
            switch self {
            case .small: return String(localized: "Small")
            case .medium: return String(localized: "Medium")
            case .large: return String(localized: "Large")
            case .extraLarge: return String(localized: "Extra Large")
            case .custom: return String(localized: "Custom")
            }
        }
    }

    @State private var availableLanguages: [String] = []
    @State private var availableVoices: [AVSpeechSynthesisVoice] = []

    // Export / Import state
    @State private var exportURL: URL?
    @State private var isExporting: Bool = false
    @State private var isImporting: Bool = false
    @State private var showImportConfirm: Bool = false
    @State private var lastExportError: String?
    @State private var exportSummary: String?
    @State private var importSummary: String?
    @State private var importMode: ImportMode = .merge

    // Development
    @State private var showReseedConfirm: Bool = false

    // Quick Phrases editing
    @State private var newQuickPhrase: String = ""
    @State private var isEditingQuickPhrases: Bool = false
    @State private var qpEdits: [UUID: String] = [:]
    @State private var confirmDeleteQP: QuickPhrase?

    // UI state
    @State private var showSpeechSettings: Bool = false
    @State private var showViewOptions: Bool = false
    @State private var showAudioSettings: Bool = false
    @State private var showLayoutSettings: Bool = false
    @State private var showQuickPhrasesDisclosure: Bool = false
    @State private var showUserInfoDisclosure: Bool = false
    @State private var showInteractionSettings: Bool = false

    // Migration feedback
    @State private var migrationSummary: String?

    private let rateMin = Double(AVSpeechUtteranceMinimumSpeechRate)
    private let rateMax = Double(AVSpeechUtteranceMaximumSpeechRate)

    // Strongly-typed proxies for raw AppStorage
    private var audioMixingOption: Binding<Speaker.AudioMixingOption> {
        Binding(
            get: { Speaker.AudioMixingOption(rawValue: audioMixingRaw) ?? .duckOthers },
            set: { new in
                audioMixingRaw = new.rawValue
                speaker.setAudioMixingOption(new)
            }
        )
    }

    private var gridSizePreference: Binding<GridSizePreference> {
        Binding(
            get: { GridSizePreference(rawValue: gridSizeRaw) ?? .medium },
            set: { gridSizeRaw = $0.rawValue }
        )
    }

    private var aacColorScheme: Binding<AACColorScheme> {
        Binding(
            get: { AACColorScheme(rawValue: aacColorSchemeRaw) ?? .fitzgerald },
            set: { aacColorSchemeRaw = $0.rawValue }
        )
    }

    private var selectionBehavior: Binding<SelectionBehavior> {
        Binding(
            get: { SelectionBehavior(rawValue: selectionBehaviorRaw) ?? .both },
            set: { selectionBehaviorRaw = $0.rawValue }
        )
    }

    private var scanningMode: Binding<ScanningMode> {
        Binding(
            get: { ScanningMode(rawValue: scanningModeRaw) ?? .step },
            set: { scanningModeRaw = $0.rawValue }
        )
    }

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

                // User Info inside a disclosure (optional)
                Section {
                    DisclosureGroup(isExpanded: $showUserInfoDisclosure) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField(String(localized: "Preferred Name"), text: $userPreferredName)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled(true)
                            Text(String(localized: "If provided, the app may greet you by name."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        Label(String(localized: "User Info"), systemImage: "person.crop.circle")
                    }
                }

                Section(header: Text(String(localized: "Prediction"))) {
                    Toggle(String(localized: "Enable Prediction"), isOn: $predictionEnabled)
                    Text(String(localized: "Suggestions adapt to your tiles and favorites."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                // Color Coding + Migration
                Section(header: Text(String(localized: "Color Coding"))) {
                    Picker(String(localized: "AAC Color Scheme"), selection: aacColorScheme) {
                        ForEach(AACColorScheme.allCases) { scheme in
                            Text(scheme.displayName).tag(scheme)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(String(localized: "Applies to tiles that have a Part of Speech assigned."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button {
                        Task { @MainActor in
                            do {
                                let scheme = AACColorScheme(rawValue: aacColorSchemeRaw) ?? .fitzgerald
                                let result = try AACColorMigration.applySchemeColors(modelContext: modelContext,
                                                                                      scheme: scheme,
                                                                                      overwrite: true)
                                migrationSummary = String(localized: "Updated colors on \(result.updatedTiles) tiles.")
                            } catch {
                                migrationSummary = error.localizedDescription
                            }
                        }
                    } label: {
                        Label(String(localized: "Apply Scheme Colors to Tiles"), systemImage: "paintpalette")
                    }
                    .disabled(editLocked)

                    Button {
                        Task { @MainActor in
                            do {
                                let scheme = AACColorScheme(rawValue: aacColorSchemeRaw) ?? .fitzgerald
                                let result = try AACColorMigration.inferPOSForCommonWords(modelContext: modelContext,
                                                                                          scheme: scheme,
                                                                                          overwritePOS: false,
                                                                                          setColor: true,
                                                                                          overwriteColor: false)
                                migrationSummary = String(localized: "Assigned POS to \(result.assignedPOS) tiles and updated \(result.updatedTiles) colors.")
                            } catch {
                                migrationSummary = error.localizedDescription
                            }
                        }
                    } label: {
                        Label(String(localized: "Infer POS for Common Words"), systemImage: "text.badge.plus")
                    }
                    .disabled(editLocked)

                    if let summary = migrationSummary {
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                // Speech settings inside a disclosure
                Section {
                    DisclosureGroup(isExpanded: $showSpeechSettings) {
                        LabeledContent {
                            Slider(value: $rate, in: rateMin...rateMax, step: 0.01)
                        } label: {
                            HStack {
                                Text(String(localized: "Rate"))
                                Spacer()
                                Text("\(rate, specifier: "%.2f")").monospacedDigit()
                            }
                        }

                        LabeledContent {
                            Slider(value: $pitch, in: 0.5...2.0, step: 0.01)
                        } label: {
                            HStack {
                                Text(String(localized: "Pitch"))
                                Spacer()
                                Text("\(pitch, specifier: "%.2f")").monospacedDigit()
                            }
                        }

                        LabeledContent {
                            Slider(value: $volume, in: 0.0...1.0, step: 0.01)
                        } label: {
                            HStack {
                                Text(String(localized: "Volume"))
                                Spacer()
                                Text("\(volume, specifier: "%.2f")").monospacedDigit()
                            }
                        }

                        Button(String(localized: "Test Speech")) {
                            testSpeech()
                        }
                        .buttonStyle(BorderedProminentButtonStyle())
                        .padding(.top, 4)
                    } label: {
                        Label(String(localized: "Speech Settings"), systemImage: "speaker.wave.2.fill")
                    }
                }

                // Audio inside a disclosure
                Section {
                    DisclosureGroup(isExpanded: $showAudioSettings) {
                        Picker(String(localized: "Audio Mixing"), selection: audioMixingOption) {
                            Text(String(localized: "Duck Others")).tag(Speaker.AudioMixingOption.duckOthers)
                            Text(String(localized: "Mix With Others")).tag(Speaker.AudioMixingOption.mixWithOthers)
                        }
                        .pickerStyle(.segmented)

                        Toggle(String(localized: "Route to Speaker"), isOn: $routeToSpeaker)
                            .onChange(of: routeToSpeaker) { _, new in
                                speaker.setAudioRouting(toSpeaker: new)
                            }
                            .accessibilityHint(Text(String(localized: "Force audio to play from the device speaker")))
                    } label: {
                        Label(String(localized: "Audio"), systemImage: "speaker.wave.3.fill")
                    }
                }

                // Interaction inside a disclosure
                Section {
                    DisclosureGroup(isExpanded: $showInteractionSettings) {
                        Picker(String(localized: "Selection Behavior"), selection: selectionBehavior) {
                            ForEach(SelectionBehavior.allCases) { behavior in
                                Text(behavior.displayName).tag(behavior)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("SelectionBehaviorPicker")

                        Text(String(localized: "Speak: tap speaks immediately. Add: tap builds the sentence. Both: adds to the sentence and speaks."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Toggle(String(localized: "Large Touch Targets"), isOn: $largeTouchTargets)
                            .accessibilityHint(Text(String(localized: "Increase tile size for easier tapping")))

                        Toggle(String(localized: "Auto‑Relock on Background"), isOn: $autoRelockOnBackground)
                            .accessibilityHint(Text(String(localized: "Lock editing when the app goes to background")))

                        // New: Scanning
                        Toggle(String(localized: "Enable Scanning"), isOn: $scanningEnabled)
                        Picker(String(localized: "Scanning Mode"), selection: scanningMode) {
                            ForEach(ScanningMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .disabled(!scanningEnabled)
                        HStack {
                            Text(String(localized: "Scan Speed"))
                            Slider(value: $scanInterval, in: 0.5...3.0, step: 0.1)
                            Text(String(format: "%.1fs", scanInterval))
                                .font(.caption.monospacedDigit())
                        }
                        .disabled(!scanningEnabled)
                        Toggle(String(localized: "Auditory Preview on Focus"), isOn: $auditoryPreviewOnFocus)
                            .disabled(!scanningEnabled)
                            .accessibilityHint(Text(String(localized: "Speaks a brief preview when an item is focused")))

                        // New: Dwell
                        Toggle(String(localized: "Dwell to Select"), isOn: $dwellEnabled)
                        HStack {
                            Text(String(localized: "Dwell Time"))
                            Slider(value: $dwellTime, in: 0.5...2.5, step: 0.1)
                            Text(String(format: "%.1fs", dwellTime))
                                .font(.caption.monospacedDigit())
                        }
                        .disabled(!dwellEnabled)

                    } label: {
                        Label(String(localized: "Interaction"), systemImage: "hand.tap")
                    }
                }

                // View Options inside a disclosure
                Section {
                    DisclosureGroup(isExpanded: $showViewOptions) {
                        Toggle(String(localized: "Sentence Bar"), isOn: $showSentenceBar)
                        Toggle(String(localized: "Quick Phrases"), isOn: $showQuickPhrases)
                        Toggle(String(localized: "Recents"), isOn: $showRecents)
                        Toggle(String(localized: "Back/Home Tiles"), isOn: $showNavTiles)
                        Toggle(String(localized: "Add Tile Button"), isOn: $showAddTileButton)
                        Toggle(String(localized: "Bottom Action Bar"), isOn: $showBottomActionBar)

                        Text(String(localized: "Use these options to focus on tiles only. You can also toggle them from the View Options menu in the toolbar."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    } label: {
                        Label(String(localized: "View Options"), systemImage: "eye")
                    }
                }

                // Combined Layout (Tile Size + Control Settings) inside a single disclosure
                Section {
                    DisclosureGroup(isExpanded: $showLayoutSettings) {
                        // Tile Size
                        Picker(String(localized: "Tile Size"), selection: gridSizePreference) {
                            ForEach(GridSizePreference.allCases) { size in
                                Text(size.label).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("TileSizePicker")

                        // Custom columns control appears when Custom is selected
                        if GridSizePreference(rawValue: gridSizeRaw) == .custom {
                            Stepper(value: $customGridColumns, in: 2...10) {
                                Text(String(localized: "Columns: \(customGridColumns)"))
                            }
                            .accessibilityIdentifier("CustomColumnsStepper")
                        }

                        // Display Mode
                        Picker(String(localized: "Display Mode"), selection: $controlStyle) {
                            ForEach(ControlsStyle.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .accessibilityIdentifier("DisplayModePicker")
                        .padding(.top, 4)
                    } label: {
                        Label(String(localized: "Layout"), systemImage: "rectangle.3.offgrid")
                    }
                }

                // Quick Phrases inside a disclosure
                Section {
                    DisclosureGroup(isExpanded: $showQuickPhrasesDisclosure) {
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

                        // Footer content moved inside the disclosure
                        quickPhrasesFooter()
                            .padding(.top, 4)
                    } label: {
                        Label(String(localized: "Quick Phrases"), systemImage: "quote.bubble")
                    }
                }

                // Help & Support
                Section(header: Text(String(localized: "Help & Support"))) {
                    NavigationLink {
                        HelpSupportView()
                    } label: {
                        Label(String(localized: "Open Help & Support"), systemImage: "questionmark.circle")
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
                        showImportConfirm = true
                    } label: {
                        Label(String(localized: "Import Board"), systemImage: "square.and.arrow.down.on.square")
                    }
                    .confirmationDialog(
                        String(localized: "Import Board"),
                        isPresented: $showImportConfirm,
                        titleVisibility: .visible
                    ) {
                        Button(String(localized: "Merge Into Current")) {
                            importMode = .merge
                            isImporting = true
                        }
                        Button(String(localized: "Replace Current"), role: .destructive) {
                            importMode = .replace
                            isImporting = true
                        }
                        Button(String(localized: "Cancel"), role: .cancel) { showImportConfirm = false }
                    } message: {
                        Text(String(localized: "Choose Merge to add content to your current board, or Replace to overwrite it."))
                    }
                    .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
                        switch result {
                        case .success(let url):
                            importData(from: url, mode: importMode)
                        case .failure(let error):
                            lastExportError = error.localizedDescription
                            importSummary = nil
                        }
                    }

                    if let summary = exportSummary {
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let summary = importSummary {
                        Text(summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
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
            }
            .navigationTitle(String(localized: "Settings"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Label(String(localized: "Dismiss"), systemImage: "xmark.circle.fill")
                    }
                    .accessibilityLabel(Text(String(localized: "Dismiss Settings")))
                }
            }
            .onAppear {
                fetchAvailableLanguages()
                refreshVoices()
                speaker.setAudioMixingOption(Speaker.AudioMixingOption(rawValue: audioMixingRaw) ?? .duckOthers)
                speaker.setAudioRouting(toSpeaker: routeToSpeaker)
            }
            .onChange(of: language) {
                refreshVoices()
                PredictionService.shared.reset()
                if let best = VoicePicker.bestVoiceIdentifier(for: language) {
                    identifier = best
                }
            }
            .onChange(of: aacColorSchemeRaw) { _, _ in
                Task { @MainActor in
                    let scheme = AACColorScheme(rawValue: aacColorSchemeRaw) ?? .fitzgerald
                    do {
                        let result = try AACColorMigration.applySchemeColors(modelContext: modelContext,
                                                                             scheme: scheme,
                                                                             overwrite: false)
                        migrationSummary = String(localized: "Applied scheme to \(result.updatedTiles) tiles.")
                    } catch {
                        migrationSummary = error.localizedDescription
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if autoRelockOnBackground && newPhase == .background {
                    editLocked = true
                }
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

    // MARK: - Voice helpers

    @MainActor
    private func refreshVoices() {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == language }
        availableVoices = voices
        if !voices.contains(where: { $0.identifier == identifier }) {
            if let best = VoicePicker.bestVoiceIdentifier(for: language) {
                identifier = best
            } else if let first = voices.first?.identifier {
                identifier = first
            }
        }
    }

    // MARK: - Quick Phrases

    @MainActor
    private func addQuickPhrase() {
        guard !editLocked else { return }
        let trimmed = newQuickPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !quickPhrases.contains(where: { $0.text.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            return
        }
        let nextOrder = (quickPhrases.map { $0.order }.max() ?? -1) + 1
        let qp = QuickPhrase(text: trimmed, order: nextOrder)
        modelContext.insert(qp)
        do {
            try modelContext.save()
            newQuickPhrase = ""
        } catch {
            lastExportError = error.localizedDescription
        }
    }

    private func canAddNewQuickPhrase() -> Bool {
        let trimmed = newQuickPhrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !quickPhrases.contains { $0.text.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    @ViewBuilder
    private func quickPhraseRow(_ qp: QuickPhrase) -> some View {
        HStack {
            if let current = qpEdits[qp.id] {
                TextField("", text: Binding(
                    get: { current },
                    set: { qpEdits[qp.id] = $0 }
                ))
                .textInputAutocapitalization(.sentences)
                .disabled(editLocked)
                .opacity(editLocked ? 0.5 : 1.0)
            } else {
                Text(qp.text)
            }
            Spacer()
            if editLocked {
                EmptyView()
            } else {
                if qpEdits[qp.id] == nil {
                    Button {
                        qpEdits[qp.id] = qp.text
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        confirmDeleteQP = qp
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        saveQuickPhraseEdit(qp)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .buttonStyle(.plain)

                    Button {
                        qpEdits.removeValue(forKey: qp.id)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @MainActor
    private func saveQuickPhraseEdit(_ qp: QuickPhrase) {
        guard !editLocked else { return }
        guard let edited = qpEdits[qp.id]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !edited.isEmpty else {
            qpEdits.removeValue(forKey: qp.id)
            return
        }
        if quickPhrases.contains(where: { $0.id != qp.id && $0.text.caseInsensitiveCompare(edited) == .orderedSame }) {
            return
        }
        qp.text = edited
        do {
            try modelContext.save()
            qpEdits.removeValue(forKey: qp.id)
        } catch {
            lastExportError = error.localizedDescription
        }
    }

    @MainActor
    private func moveQuickPhrases(from source: IndexSet, to destination: Int) {
        guard !editLocked else { return }
        var items = quickPhrases.sorted { $0.order < $1.order }
        items.move(fromOffsets: source, toOffset: destination)
        for (idx, qp) in items.enumerated() {
            qp.order = idx
        }
        do {
            try modelContext.save()
        } catch {
            lastExportError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func quickPhrasesFooter() -> some View {
        Text(String(localized: "Add short phrases you use often. Reorder them to prioritize."))
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    @MainActor
    private func deleteQuickPhrase(_ qp: QuickPhrase) {
        guard !editLocked else { return }
        let remaining = quickPhrases
            .filter { $0.id != qp.id }
            .sorted { $0.order < $1.order }
        modelContext.delete(qp)
        for (idx, item) in remaining.enumerated() {
            item.order = idx
        }
        do {
            try modelContext.save()
        } catch {
            lastExportError = error.localizedDescription
        }
        confirmDeleteQP = nil
    }

    // MARK: - Languages

    private func fetchAvailableLanguages() {
        let codes = Set(AVSpeechSynthesisVoice.speechVoices().map { $0.language })
        availableLanguages = codes.sorted()
        if !availableLanguages.contains(language) {
            language = availableLanguages.first ?? "en-US"
        }
    }

    // MARK: - Backup (full export/import with embedded images)

    private enum ImportMode { case merge, replace }

    private struct ExportPackage: Codable {
        let version: Int
        let exportedAt: Date
        let pages: [PageNode]
        let favorites: [FavoriteDTO]
        let quickPhrases: [QuickPhraseDTO]
        let recents: [RecentDTO]
        // Map relative image path -> base64 PNG
        let images: [String: String]
    }

    private struct PageNode: Codable {
        var id: UUID
        var name: String
        var order: Int
        var isRoot: Bool
        var tiles: [TileDTO]
        var children: [PageNode]
    }

    private struct TileDTO: Codable {
        var id: UUID
        var text: String
        var symbolName: String?
        var colorHex: String?
        var order: Int
        var isCore: Bool
        var pronunciationOverride: String?
        var imageRelativePath: String?
        var size: Double?
        var languageCode: String?
        var partOfSpeechRaw: String?
    }

    private struct FavoriteDTO: Codable {
        var text: String
        var order: Int
    }

    private struct QuickPhraseDTO: Codable {
        var id: UUID
        var text: String
        var order: Int
    }

    private struct RecentDTO: Codable {
        var id: UUID
        var text: String
        var timestamp: Date
        var count: Int
    }

    private func makePackage() -> ExportPackage {
        let imagesDict: [String: String] = pages
            .flatMap { $0.tiles }
            .compactMap { $0.imageRelativePath }
            .reduce(into: [String: String]()) { dict, rel in
                let url = TileImagesStorage.imagesDirectory.appendingPathComponent(rel)
                if let data = try? Data(contentsOf: url) {
                    dict[rel] = data.base64EncodedString()
                }
            }

        func node(from page: Page) -> PageNode {
            let tiles = page.tiles.sorted(by: { $0.order < $1.order }).map { t in
                TileDTO(
                    id: t.id,
                    text: t.text,
                    symbolName: t.symbolName,
                    colorHex: t.colorHex,
                    order: t.order,
                    isCore: t.isCore,
                    pronunciationOverride: t.pronunciationOverride,
                    imageRelativePath: t.imageRelativePath,
                    size: t.size,
                    languageCode: t.languageCode,
                    partOfSpeechRaw: t.partOfSpeechRaw
                )
            }
            let kids = page.children.sorted(by: { $0.order < $1.order }).map(node(from:))
            return PageNode(id: page.id, name: page.name, order: page.order, isRoot: page.isRoot, tiles: tiles, children: kids)
        }

        let roots = pages.filter { $0.parent == nil }.sorted(by: { $0.order < $1.order })
        let pageNodes = roots.map(node(from:))

        let favs = favorites.sorted(by: { $0.order < $1.order }).map { FavoriteDTO(text: $0.text, order: $0.order) }
        let qps = quickPhrases.sorted(by: { $0.order < $1.order }).map { QuickPhraseDTO(id: $0.id, text: $0.text, order: $0.order) }

        let recentsFetch = FetchDescriptor<Recent>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        let recentsAll = (try? modelContext.fetch(recentsFetch)) ?? []
        let recentsDTO = recentsAll.map { RecentDTO(id: $0.id, text: $0.text, timestamp: $0.timestamp, count: $0.count) }

        return ExportPackage(
            version: 1,
            exportedAt: Date(),
            pages: pageNodes,
            favorites: favs,
            quickPhrases: qps,
            recents: recentsDTO,
            images: imagesDict
        )
    }

    private func exportData() {
        isExporting = true
        lastExportError = nil
        exportSummary = nil

        Task { @MainActor in
            do {
                let pkg = makePackage()
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes, .sortedKeys]
                let data = try encoder.encode(pkg)
                let url = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Board-\(Int(Date().timeIntervalSince1970)).ltboard.json")
                try data.write(to: url, options: .atomic)
                exportURL = url

                let tileCount = pages.flatMap { $0.tiles }.count
                exportSummary = String(localized: "Exported \(pages.count) pages, \(tileCount) tiles, \(favorites.count) favorites, \(quickPhrases.count) quick phrases.")
            } catch {
                lastExportError = error.localizedDescription
            }
            isExporting = false
        }
    }

    private func importData(from url: URL, mode: ImportMode) {
        lastExportError = nil
        importSummary = nil

        Task { @MainActor in
            do {
                let data = try Data(contentsOf: url)
                let decoder = JSONDecoder()
                let pkg = try decoder.decode(ExportPackage.self, from: data)

                if mode == .replace {
                    try wipeAllContent()
                }

                let imageMap = restoreImages(pkg.images)

                let currentMaxOrder = (pages.map { $0.order }.max() ?? -1)
                var baseOrderOffset = max(0, currentMaxOrder + 1)
                for node in pkg.pages.sorted(by: { $0.order < $1.order }) {
                    let _ = importPageNode(node, parent: nil, orderOffset: &baseOrderOffset, imageMap: imageMap)
                }

                let existingFavs = (try? modelContext.fetch(FetchDescriptor<Favorite>())) ?? []
                var favOrderStart = (existingFavs.map { $0.order }.max() ?? -1) + 1
                for f in pkg.favorites.sorted(by: { $0.order < $1.order }) {
                    if existingFavs.contains(where: { $0.text.caseInsensitiveCompare(f.text) == .orderedSame }) {
                        continue
                    }
                    modelContext.insert(Favorite(text: f.text, order: favOrderStart))
                    favOrderStart += 1
                }

                let existingQPs = (try? modelContext.fetch(FetchDescriptor<QuickPhrase>())) ?? []
                var qpOrderStart = (existingQPs.map { $0.order }.max() ?? -1) + 1
                for q in pkg.quickPhrases.sorted(by: { $0.order < $1.order }) {
                    if existingQPs.contains(where: { $0.text.caseInsensitiveCompare(q.text) == .orderedSame }) {
                        continue
                    }
                    modelContext.insert(QuickPhrase(text: q.text, order: qpOrderStart))
                    qpOrderStart += 1
                }

                let existingRecents = (try? modelContext.fetch(FetchDescriptor<Recent>())) ?? []
                for r in pkg.recents {
                    if let match = existingRecents.first(where: { $0.text == r.text }) {
                        match.count += r.count
                        match.timestamp = max(match.timestamp, r.timestamp)
                    } else {
                        modelContext.insert(Recent(id: r.id, text: r.text, timestamp: r.timestamp, count: r.count))
                    }
                }

                try modelContext.save()

                let importedTileCount = countTiles(in: pkg.pages)
                importSummary = String(localized: "Imported \(pkg.pages.count) pages, \(importedTileCount) tiles, \(pkg.favorites.count) favorites, \(pkg.quickPhrases.count) quick phrases.")
            } catch {
                lastExportError = error.localizedDescription
            }
        }
    }

    private func countTiles(in nodes: [PageNode]) -> Int {
        nodes.reduce(0) { acc, node in
            acc + node.tiles.count + countTiles(in: node.children)
        }
    }

    private func wipeAllContent() throws {
        TileImagesStorage.delete(relativePath: nil)
        let dir = TileImagesStorage.imagesDirectory
        try? FileManager.default.removeItem(at: dir)

        try deleteAll(Favorite.self)
        try deleteAll(Recent.self)
        try deleteAll(QuickPhrase.self)
        try deleteAll(Tile.self)
        try deleteAll(Page.self)
    }

    private func deleteAll<T>(_ type: T.Type) throws where T: PersistentModel {
        let descriptor = FetchDescriptor<T>()
        let items = try modelContext.fetch(descriptor)
        for item in items {
            modelContext.delete(item)
        }
    }

    private func restoreImages(_ images: [String: String]) -> [String: String] {
        var mapping: [String: String] = [:]
        for (oldRel, b64) in images {
            if let data = Data(base64Encoded: b64), let newRel = TileImagesStorage.savePNG(data) {
                mapping[oldRel] = newRel
            }
        }
        return mapping
    }

    @discardableResult
    private func importPageNode(_ node: PageNode, parent: Page?, orderOffset: inout Int, imageMap: [String: String]) -> Page {
        let page = Page(id: node.id, name: node.name, order: orderOffset, isRoot: parent == nil ? node.isRoot : false)
        page.parent = parent
        modelContext.insert(page)
        orderOffset += 1

        var order = 0
        for t in node.tiles.sorted(by: { $0.order < $1.order }) {
            let newRel = t.imageRelativePath.flatMap { imageMap[$0] }
            let tile = Tile(
                id: t.id,
                text: t.text,
                symbolName: t.symbolName,
                colorHex: t.colorHex,
                order: order,
                isCore: t.isCore,
                pronunciationOverride: t.pronunciationOverride,
                destinationPage: nil,
                page: page,
                imageRelativePath: newRel,
                size: t.size,
                languageCode: t.languageCode,
                partOfSpeechRaw: t.partOfSpeechRaw
            )
            modelContext.insert(tile)
            page.tiles.append(tile)
            order += 1
        }

        for child in node.children.sorted(by: { $0.order < $1.order }) {
            _ = importPageNode(child, parent: page, orderOffset: &orderOffset, imageMap: imageMap)
        }

        return page
    }

    // MARK: - Admin

    private func authenticateAndUnlock() {
        let context = LAContext()
        var error: NSError?

        let reason = String(localized: "Unlock editing")

        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        editLocked = false
                    }
                }
            }
        } else {
            editLocked = false
        }
    }

    // MARK: - Test Speech

    @MainActor
    private func testSpeech() {
        let sample = String(localized: "This is a test.")
        let utterance = AVSpeechUtterance(string: sample)

        if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: language)
        }

        utterance.rate = Float(rate)
        utterance.pitchMultiplier = Float(pitch)
        utterance.volume = Float(volume)

        let synthesizer = AVSpeechSynthesizer()
        synthesizer.speak(utterance)
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: [Favorite.self, Page.self, Tile.self, Recent.self, QuickPhrase.self], inMemory: true)
        .environment(Speaker())
}
