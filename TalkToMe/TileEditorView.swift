// TileEditorView.swift

import SwiftUI
import SwiftData
import PhotosUI

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

                    TextField("Color Hex (#RRGGBB)", text: $colorHex)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    TextField("SF Symbol (optional)", text: $symbolName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
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
                            } else {
                                // default to current page as destination? better: pick explicitly
                            }
                        }
                    ))

                    if destinationPage != nil || createNewPage {
                        Picker("Existing Page", selection: Binding<Page?>(
                            get: { destinationPage },
                            set: { destinationPage = $0; createNewPage = false }
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
            // Replace existing image
            if let existing = imageRelativePath { TileImagesStorage.delete(relativePath: existing) }
            imageRelativePath = TileImagesStorage.savePNG(data)
        }

        if let edit = tileToEdit {
            // Edit existing
            edit.text = text
            edit.colorHex = colorHex
            edit.symbolName = symbolName.isEmpty ? nil : symbolName
            edit.pronunciationOverride = pronunciationOverride.isEmpty ? nil : pronunciationOverride
            edit.size = size
            edit.languageCode = languageCode
            edit.destinationPage = dest
            edit.imageRelativePath = imageRelativePath
        } else {
            // Create new
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
            // maintain relationship
            page.tiles.append(tile)
        }

        do {
            try modelContext.save()
        } catch {
            print("Failed to save tile: \(error)")
        }
        dismiss()
    }
}

