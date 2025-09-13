//
//  HelpView.swift
//  Let's Talk
//
//  Created by Eric Carroll on 9/13/25.
//

import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    SectionHeader(title: String(localized: "Welcome"))
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "• The sentence bar shows what you plan to say. Use Speak to play it aloud and Clear to reset."))
                            Text(String(localized: "• Quick Phrases and Recents help you speak faster. Tap any item to insert and speak (based on your selection behavior)."))
                            Text(String(localized: "• Use the grid density control in the toolbar to choose Compact, Cozy, or Comfortable layouts."))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SectionHeader(title: String(localized: "Kiosk Mode (Guided Access)"))
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "Guided Access keeps the iPhone or iPad focused on this app and can disable hardware buttons or touch areas."))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(String(localized: "Enable"))
                                .font(.headline)
                            Text(String(localized: "1) Open Settings > Accessibility > Guided Access."))
                            Text(String(localized: "2) Turn on Guided Access and set a Passcode (or enable Face ID/Touch ID)."))

                            Text(String(localized: "Start"))
                                .font(.headline)
                                .padding(.top, 6)
                            Text(String(localized: "1) Open Let’s Talk."))
                            Text(String(localized: "2) Triple‑click the Side (or Home) button."))
                            Text(String(localized: "3) Tap Start. Optionally tap Options to restrict volume buttons, motion, keyboards, etc."))

                            Text(String(localized: "End"))
                                .font(.headline)
                                .padding(.top, 6)
                            Text(String(localized: "Triple‑click the Side (or Home) button again and authenticate to end."))

                            Text(String(localized: "Tip"))
                                .font(.headline)
                                .padding(.top, 6)
                            Text(String(localized: "Combine Guided Access with the app’s Edit Lock to prevent changes to pages and tiles."))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SectionHeader(title: String(localized: "Edit Lock"))
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "When Edit Lock is on, you can’t reorder or change content. This is helpful for daily use or kiosk mode."))
                            Text(String(localized: "You can toggle Edit Lock in Settings. Consider protecting unlock with Face ID/Touch ID if available."))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SectionHeader(title: String(localized: "Backups & iCloud Drive"))
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "Regularly export your board to Files or iCloud Drive so you can restore it later or move to a new device."))
                            Text(String(localized: "Go to Settings to Export or Import. After a successful export, the app won’t remind you for a while."))
                            Text(String(localized: "Tip: Keep multiple dated backups so you can roll back if needed."))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SectionHeader(title: String(localized: "Voice & Language"))
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "Choose a language and voice in Settings. You can adjust speaking rate, pitch, and volume for comfort."))
                            Text(String(localized: "If no voice is set, the app will try to pick a good default for your language."))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    SectionHeader(title: String(localized: "Troubleshooting"))
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(String(localized: "• If speech is quiet, check your device volume and the app’s volume setting in Settings."))
                            Text(String(localized: "• If dictation is used and speech stops after recording, wait a moment or try speaking again—audio will resume automatically."))
                            Text(String(localized: "• If you can’t edit, check Edit Lock or whether Guided Access is active."))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .navigationTitle(String(localized: "Help"))
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(String(localized: "Done")) { dismiss() }
                }
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.title3).bold()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
    }
}

#Preview {
    HelpView()
}
