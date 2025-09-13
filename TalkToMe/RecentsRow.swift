// RecentsRow.swift

import SwiftUI
import SwiftData

struct RecentsRow: View {
    var items: [Recent]
    var onTap: (String) -> Void

    @AppStorage("largeTouchTargets") private var largeTouchTargets: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Recents"))
                .font(.headline)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: largeTouchTargets ? 12 : 8) {
                    ForEach(items.prefix(20)) { r in
                        Button {
                            onTap(r.text)
                        } label: {
                            Text(r.text)
                                .lineLimit(1)
                                .padding(.horizontal, largeTouchTargets ? 18 : 12)
                                .padding(.vertical, largeTouchTargets ? 12 : 8)
                                .background(Color.yellow.opacity(0.2))
                                .clipShape(Capsule())
                                .dynamicTypeSize(.large ... .accessibility3)
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

