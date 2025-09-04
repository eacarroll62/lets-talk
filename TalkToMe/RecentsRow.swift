// RecentsRow.swift

import SwiftUI
import SwiftData

struct RecentsRow: View {
    var items: [Recent]
    var onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Recents"))
                .font(.headline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(items.prefix(20)) { r in
                        Button {
                            onTap(r.text)
                        } label: {
                            Text(r.text)
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.yellow.opacity(0.2))
                                .clipShape(Capsule())
                        }
                        .accessibilityLabel(Text(r.text))
                        .accessibilityHint(Text(String(localized: "Insert recent phrase")))
                    }
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
