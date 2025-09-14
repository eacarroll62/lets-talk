// TileEditorView.swift

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct TileEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(Speaker.self) private var speaker

    // Editing existing tile or creating a new one on the given page
    let page: Page
    var tileToEdit: Tile?

    // Queries for pages (to pick a destination or create a new one)
    @Query(sort: \Page.order) private var pages: [Page]

    // Fields
    @State private var text: String = ""
    @State private var colorHex: String = "#F9D65C"
    @State private var symbolName: String = "square.grid.2x2.fill"
    @State private var pronunciationOverride: String = ""
    @State private var size: Double = 1.0
    @State private var languageCode: String = (UserDefaults.standard.string(forKey: "language") ?? "en-US").hasPrefix("es") ? "es" : "en"

    // New: POS selection (optional)
    @State private var selectedPOS: PartOfSpeech?

    // Destination page (folder) selection
    @State private var destinationPage: Page?
    @State private var createNewPage: Bool = false
    @State private var newPageName: String = ""

    // Image picking
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var showCamera: Bool = false
    @State private var cameraImageData: Data?

    // Symbol picker
    @State private var showSymbolPicker: Bool = false
    @State private var symbolSearch: String = ""

    // Speech-to-text
    @StateObject private var transcriber = SpeechTranscriber()
    @State private var dictationModeAppend: Bool = true
    @State private var isRequestingAuth: Bool = false

    // AAC scheme
    @AppStorage("aacColorScheme") private var aacColorSchemeRaw: String = AACColorScheme.fitzgerald.rawValue
    private var aacScheme: AACColorScheme { AACColorScheme(rawValue: aacColorSchemeRaw) ?? .fitzgerald }

    private let presetColors: [(String, Color)] = [
        ("#F9D65C", Color(hex: "#F9D65C") ?? .yellow),
        ("#FFD1DC", Color(hex: "#FFD1DC") ?? .pink),
        ("#C6E2FF", Color(hex: "#C6E2FF") ?? .blue.opacity(0.3)),
        ("#C1E1C1", Color(hex: "#C1E1C1") ?? .green.opacity(0.3)),
        ("#FFECB3", Color(hex: "#FFECB3") ?? .orange.opacity(0.3)),
        ("#E0D7FF", Color(hex: "#E0D7FF") ?? .purple.opacity(0.3))
    ]

    private let commonSymbols: [String] = [
        "square.grid.2x2.fill", "house.fill", "arrow.backward.circle.fill", "plus.circle.fill",
        "person.fill", "hand.wave.fill", "heart.fill", "star.fill", "checkmark.seal.fill",
        "pencil", "trash.fill", "photo", "camera", "mic.fill", "speaker.wave.2.fill"
    ]

    var isEditing: Bool { tileToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Tile")) {
                    HStack(spacing: 8) {
                        TextField("Text", text: $text)
                            .textInputAutocapitalization(.sentences)

                        Button {
                            toggleDictationForText()
                        } label: {
                            Image(systemName: transcriber.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .foregroundStyle(transcriber.isRecording ? .red : .accentColor)
                        }
                        .accessibilityLabel(Text(transcriber.isRecording ? "Stop Dictation" : "Start Dictation"))
                        .help(transcriber.isRecording ? "Stop Dictation" : "Start Dictation")
                    }

                    Picker("Dictation Mode", selection: $dictationModeAppend) {
                        Text("Append").tag(true)
                        Text("Replace").tag(false)
                    }
                    .pickerStyle(.segmented)

                    if transcriber.isRecording {
                        Text(transcriber.partialText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    TextField("Pronunciation (optional)", text: $pronunciationOverride)

                    Picker("Language", selection: $languageCode) {
                        Text("English").tag("en")
                        Text("Español").tag("es")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: languageCode) { _, newValue in
                        let locale = newValue.hasPrefix("es") ? "es-ES" : "en-US"
                        transcriber.setLocale(locale)
                    }

                    // Part of Speech
                    Picker("Part of Speech (Fitzgerald)", selection: Binding(
                        get: { selectedPOS ?? PartOfSpeech?.none ?? nil },
                        set: { newValue in
                            selectedPOS = newValue
                            // If POS is chosen, auto-apply color from the selected scheme
                            if let pos = newValue {
                                colorHex = FitzgeraldKey.colorHex(for: pos, scheme: aacScheme)
                            }
                        }
                    )) {
                        Text("None").tag(PartOfSpeech?.none)
                        ForEach(PartOfSpeech.allCases) { pos in
                            Text(pos.displayName).tag(PartOfSpeech?.some(pos))
                        }
                    }

                    Button {
                        speakPreview()
                    } label: {
                        Label("Speak", systemImage: "speaker.wave.2.fill")
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityHint(Text("Speaks the tile text using the selected language"))

                    HStack {
                        Text("Size")
                        Slider(value: $size, in: 0.75...1.5, step: 0.05)
                        Text(String(format: "%.2fx", size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Color")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(presetColors, id: \.0) { item in
                                    let hex = item.0
                                    let color = item.1
                                    Button {
                                        colorHex = hex
                                        // Clear POS if user manually overrides color
                                        selectedPOS = nil
                                    } label: {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 28, height: 28)
                                            .overlay(
                                                Circle().stroke(Color.primary.opacity(colorHex == hex ? 0.8 : 0.2), lineWidth: colorHex == hex ? 2 : 1)
                                            )
                                    }
                                }
                            }
                        }
                        ColorPicker("Custom Color", selection: Binding(
                            get: { Color(hex: colorHex) ?? .yellow },
                            set: { newColor in
                                colorHex = newColor.toHexString(default: colorHex)
                                // Clear POS if user manually overrides color
                                selectedPOS = nil
                            }
                        ))
                        TextField("Color Hex (#RRGGBB)", text: $colorHex)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .onChange(of: colorHex) { _, _ in
                                // Clear POS if user manually overrides color
                                selectedPOS = nil
                            }
                        if let pos = selectedPOS {
                            Text("Using \(aacScheme.displayName) color for \(pos.displayName).")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Symbol")
                        HStack {
                            TextField("SF Symbol (optional)", text: $symbolName)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                            Button {
                                showSymbolPicker = true
                            } label: {
                                Label("Browse", systemImage: "magnifyingglass")
                            }
                        }
                        if !symbolName.isEmpty {
                            HStack(spacing: 8) {
                                Text("Preview:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Image(systemName: symbolName)
                                    .font(.system(size: 24, weight: .bold))
                            }
                        }
                    }
                }

                Section(header: Text("Image")) {
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo")
                    }

                    Button {
                        showCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }

                    if let data = selectedImageData ?? cameraImageData, let ui = UIImage(data: data) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else if let existing = tileToEdit?.imageURL,
                              let ui = UIImage(contentsOfFile: existing.path) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }

                Section(header: Text("Destination Page")) {
                    Toggle("This tile opens a category page", isOn: Binding(
                        get: { destinationPage != nil || createNewPage },
                        set: { newValue in
                            if !newValue {
                                destinationPage = nil
                                createNewPage = false
                            }
                        }
                    ))

                    if destinationPage != nil || createNewPage {
                        Picker("Existing Page", selection: Binding<Page?>(
                            get: { destinationPage },
                            set: { newVal in
                                destinationPage = newVal
                                createNewPage = false
                                if let dest = newVal, dest.parent == nil {
                                    dest.parent = page
                                }
                            }
                        )) {
                            Text("None").tag(Page?.none)
                            ForEach(pages) { p in
                                Text(p.name).tag(Page?.some(p))
                            }
                        }

                        Toggle("Create New Page", isOn: $createNewPage)
                        if createNewPage {
                            TextField("New Page Name", text: $newPageName)
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Tile" : "New Tile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if transcriber.isRecording { transcriber.stop() }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        if transcriber.isRecording { transcriber.stop() }
                        saveTile()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        cameraImageData = nil
                        selectedImageData = data
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraCaptureView(imageData: $cameraImageData)
            }
            .sheet(isPresented: $showSymbolPicker) {
                symbolPickerSheet()
            }
            .onAppear {
                hydrateFromExisting()
                let locale = languageCode.hasPrefix("es") ? "es-ES" : "en-US"
                transcriber.setLocale(locale)
            }
            .onDisappear {
                // Ensure the audio session is restored even if the sheet is dismissed by swipe
                if transcriber.isRecording { transcriber.stop() }
            }
        }
    }

    private func hydrateFromExisting() {
        guard let tile = tileToEdit else { return }
        text = tile.text
        colorHex = tile.colorHex ?? "#F9D65C"
        symbolName = tile.symbolName ?? ""
        pronunciationOverride = tile.pronunciationOverride ?? ""
        size = tile.size ?? 1.0
        languageCode = tile.languageCode ?? languageCode
        destinationPage = tile.destinationPage
        selectedPOS = tile.partOfSpeech
    }

    private func toggleDictationForText() {
        if transcriber.isRecording {
            transcriber.stop()
            return
        }
        Task {
            if !transcriber.isAuthorized && !isRequestingAuth {
                isRequestingAuth = true
                let ok = await transcriber.requestAuthorization()
                isRequestingAuth = false
                if !ok { return }
            }
            do {
                try transcriber.start { partial in
                    if dictationModeAppend {
                        let base = self.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        if base.isEmpty {
                            self.text = partial
                        } else {
                            if partial.hasPrefix(base) {
                                let suffix = String(partial.dropFirst(base.count)).trimmingCharacters(in: .whitespaces)
                                self.text = suffix.isEmpty ? base : "\(base) \(suffix)"
                            } else {
                                self.text = "\(base) \(partial)"
                            }
                        }
                    } else {
                        self.text = partial
                    }
                }
            } catch {
                print("Speech start error: \(error)")
            }
        }
    }

    private func speakPreview() {
        let phrase = pronunciationOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? text.trimmingCharacters(in: .whitespacesAndNewlines)
            : pronunciationOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return }
        speaker.speak(phrase, languageOverride: languageCode, policy: .replaceCurrent)
    }

    private func saveTile() {
        var dest: Page? = destinationPage
        if createNewPage {
            let newOrder = (pages.map { $0.order }.max() ?? -1) + 1
            let newPage = Page(name: newPageName.isEmpty ? text : newPageName, order: newOrder, isRoot: false)
            newPage.parent = page
            modelContext.insert(newPage)
            dest = newPage
        }

        var imageRelativePath: String? = tileToEdit?.imageRelativePath
        if let data = selectedImageData ?? cameraImageData {
            if let existing = imageRelativePath { TileImagesStorage.delete(relativePath: existing) }
            imageRelativePath = TileImagesStorage.savePNG(data)
        }

        if let edit = tileToEdit {
            edit.text = text
            edit.colorHex = colorHex
            edit.symbolName = symbolName.isEmpty ? nil : symbolName
            edit.pronunciationOverride = pronunciationOverride.isEmpty ? nil : pronunciationOverride
            edit.size = size
            edit.languageCode = languageCode
            edit.destinationPage = dest
            edit.imageRelativePath = imageRelativePath
            edit.partOfSpeech = selectedPOS
        } else {
            let newOrder = page.tiles.count
            let tile = Tile(
                text: text,
                symbolName: symbolName.isEmpty ? nil : symbolName,
                colorHex: colorHex,
                order: newOrder,
                isCore: false,
                pronunciationOverride: pronunciationOverride.isEmpty ? nil : pronunciationOverride,
                destinationPage: dest,
                page: page,
                imageRelativePath: imageRelativePath,
                size: size,
                languageCode: languageCode,
                partOfSpeechRaw: selectedPOS?.rawValue
            )
            modelContext.insert(tile)
            page.tiles.append(tile)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save tile: \(error)")
        }
        dismiss()
    }

    // MARK: - Symbol Picker

    @ViewBuilder
    private func symbolPickerSheet() -> some View {
        NavigationStack {
            VStack {
                TextField("Search symbols", text: $symbolSearch)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                List {
                    let filtered = (commonSymbols + (symbolName.isEmpty ? [] : [symbolName]))
                        .uniqued()
                        .filter { symbolSearch.isEmpty ? true : $0.localizedCaseInsensitiveContains(symbolSearch) }
                        .sorted()
                    ForEach(filtered, id: \.self) { name in
                        HStack {
                            Image(systemName: name)
                                .frame(width: 32)
                            Text(name)
                            Spacer()
                            if name == symbolName {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            symbolName = name
                        }
                    }
                }
            }
            .navigationTitle("SF Symbols")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showSymbolPicker = false }
                }
            }
        }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
