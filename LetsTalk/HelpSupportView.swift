import SwiftUI

struct HelpSupportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text(String(localized: "Getting Started"))) {
                    Label(String(localized: "Tap tiles to speak"), systemImage: "speaker.wave.2.fill")
                    Label(String(localized: "Use the Sentence Bar to compose longer phrases"), systemImage: "text.bubble")
                    Label(String(localized: "Toggle view options from the toolbar menu"), systemImage: "eye")
                    Label(String(localized: "Lock editing to prevent accidental changes"), systemImage: "lock.fill")
                }

                Section(header: Text(String(localized: "Editing Tiles and Pages"))) {
                    Text(String(localized: "Unlock editing in Settings > Admin. Long-press a tile or use the Edit buttons to modify, move, or delete."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text(String(localized: "Speech Settings"))) {
                    Text(String(localized: "Adjust rate, pitch, and volume in Settings. Choose a language and voice that fit your needs."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text(String(localized: "Backup and Restore"))) {
                    Text(String(localized: "Export your board to a file you control. Import to merge content into your current board."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section(header: Text(String(localized: "Support"))) {
                    Link(destination: URL(string: "mailto:support@example.com")!) {
                        Label(String(localized: "Email Support"), systemImage: "envelope")
                    }
                    Link(destination: URL(string: "https://www.example.com/support")!) {
                        Label(String(localized: "Support Website"), systemImage: "globe")
                    }
                    Link(destination: URL(string: "https://www.example.com/privacy")!) {
                        Label(String(localized: "Privacy Policy"), systemImage: "doc.text")
                    }
                }
            }
            .navigationTitle(String(localized: "Help & Support"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "Close")) { dismiss() }
                }
            }
        }
    }
}

#Preview {
    HelpSupportView()
}
