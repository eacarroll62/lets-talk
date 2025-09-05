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
                    TextField("Text", text: $text)
                    TextField("Pronunciation (optional)", text: $pronunciationOverride)

                    Picker("Language", selection: $languageCode) {
                        Text("English").tag("en")
                        Text("Español").tag("es")
                    }
                    .pickerStyle(.segmented)

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
                            set: { newColor in colorHex = newColor.toHexString(default: colorHex) }
                        ))
                        TextField("Color Hex (#RRGGBB)", text: $colorHex)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
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
                    HStack {
                        PhotosPicker("Choose from Library", selection: $selectedPhotoItem, matching: .images)
                        Spacer()
                        Button {
                            showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
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
                                // Auto-parent existing page if missing
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
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { saveTile() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
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
    }

    private func saveTile() {
        // Resolve destination page (existing or new)
        var dest: Page? = destinationPage
        if createNewPage {
            let newOrder = (pages.map { $0.order }.max() ?? -1) + 1
            let newPage = Page(name: newPageName.isEmpty ? text : newPageName, order: newOrder, isRoot: false)
            newPage.parent = page
            modelContext.insert(newPage)
            dest = newPage
        }

        // Manage image saving
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
                languageCode: languageCode
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

private extension Color {
    func toHexString(default defaultHex: String) -> String {
        // Convert to UIColor to extract RGBA
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard ui.getRed(&r, green: &g, blue: &b, alpha: &a) else { return defaultHex }
        let ri = Int(round(r * 255))
        let gi = Int(round(g * 255))
        let bi = Int(round(b * 255))
        return String(format: "#%02X%02X%02X", ri, gi, bi)
    }
}

private extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hexSanitized.hasPrefix("#") {
            hexSanitized.removeFirst()
        }
        guard hexSanitized.count == 6,
              let rgb = Int(hexSanitized, radix: 16) else {
            return nil
        }
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0
        self = Color(red: r, green: g, blue: b)
    }
}

