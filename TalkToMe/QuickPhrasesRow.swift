// QuickPhrasesRow.swift

import SwiftUI

struct QuickPhrasesRow: View {
    var phrases: [String]
    var onTap: (String) -> Void

    @AppStorage("largeTouchTargets") private var largeTouchTargets: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Quick Phrases"))
                .font(.headline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: largeTouchTargets ? 12 : 8) {
                    ForEach(phrases, id: \.self) { phrase in
                        Button {
                            onTap(phrase)
                        } label: {
                            Text(phrase)
                                .lineLimit(1)
                                .padding(.horizontal, largeTouchTargets ? 18 : 12)
                                .padding(.vertical, largeTouchTargets ? 12 : 8)
                                .background(Color.green.opacity(0.2))
                                .clipShape(Capsule())
                                .dynamicTypeSize(.large ... .accessibility3)
                        }
                        .accessibilityLabel(Text(phrase))
                        .accessibilityHint(Text(String(localized: "Insert quick phrase")))
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

