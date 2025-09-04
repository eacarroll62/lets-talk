// QuickPhrasesRow.swift

import SwiftUI

struct QuickPhrasesRow: View {
    var phrases: [String]
    var onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Quick Phrases"))
                .font(.headline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(phrases, id: \.self) { phrase in
                        Button {
                            onTap(phrase)
                        } label: {
                            Text(phrase)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.green.opacity(0.2))
                                .clipShape(Capsule())
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
