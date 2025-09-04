//
//  PagesManagerView.swift
//  Let's Talk
//
//  Created by Eric Carroll on 9/4/25.
//

import SwiftUI
import SwiftData

struct PagesManagerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \Page.order) private var pages: [Page]

    let rootPage: Page?

    @State private var newPageName: String = ""
    @State private var editNames: [UUID: String] = [:]

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(String(localized: "Pages"))) {
                    ForEach(pages) { page in
                        HStack {
                            if editNames[page.id] != nil {
                                TextField(String(localized: "Page name"), text: Binding(
                                    get: { editNames[page.id] ?? page.name },
                                    set: { editNames[page.id] = $0 }
                                ))
                            } else {
                                Text(page.name)
                                    .font(page.isRoot ? .headline : .body)
                                if page.isRoot {
                                    Text(String(localized: "Root"))
                                        .font(.caption)
                                        .padding(4)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundColor(.blue)
                                        .clipShape(Capsule())
                                }
                            }
                            Spacer()
                            Menu {
                                Button(String(localized: "Rename")) {
                                    editNames[page.id] = page.name
                                }
                                Button(String(localized: "Set as Root")) {
                                    setAsRoot(page)
                                }
                                Button(String(localized: "Delete"), role: .destructive) {
                                    delete(page)
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                            }
                            .accessibilityLabel(Text(String(localized: "Page actions for \(page.name)")))
                        }
                    }
                    .onMove(perform: movePages)
                }

                Section(header: Text(String(localized: "Add Page"))) {
                    HStack {
                        TextField(String(localized: "New page name"), text: $newPageName)
                        Button(String(localized: "Add")) {
                            addPage()
                        }
                        .disabled(newPageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Done")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if !editNames.isEmpty {
                        Button(String(localized: "Save Names")) { saveEdits() }
                    }
                }
            }
            .navigationTitle(String(localized: "Manage Pages"))
        }
    }

    private func addPage() {
        let order = (pages.map { $0.order }.max() ?? -1) + 1
        let page = Page(name: newPageName, order: order, isRoot: pages.isEmpty)
        modelContext.insert(page)
        newPageName = ""
        try? modelContext.save()
    }

    private func saveEdits() {
        for page in pages {
            if let newName = editNames[page.id], !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                page.name = newName
            }
        }
        editNames.removeAll()
        try? modelContext.save()
    }

    private func setAsRoot(_ page: Page) {
        for p in pages {
            p.isRoot = (p.id == page.id)
        }
        try? modelContext.save()
    }

    private func delete(_ page: Page) {
        guard !page.isRoot else { return } // prevent deleting root
        // Detach children if any
        for child in page.children {
            child.parent = page.parent
        }
        // Remove tiles that point to this page as destination
        let allPages = pages
        for p in allPages {
            for t in p.tiles where t.destinationPage?.id == page.id {
                t.destinationPage = nil
            }
        }
        modelContext.delete(page)
        try? modelContext.save()
    }

    private func movePages(from source: IndexSet, to destination: Int) {
        var ordered = pages.sorted(by: { $0.order < $1.order })
        ordered.move(fromOffsets: source, toOffset: destination)
        for (idx, p) in ordered.enumerated() {
            p.order = idx
        }
        try? modelContext.save()
    }
}
