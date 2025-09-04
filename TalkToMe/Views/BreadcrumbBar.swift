// BreadcrumbBar.swift

import SwiftUI

struct BreadcrumbBar: View {
    let current: Page
    var onSelect: (Page) -> Void

    private var path: [Page] {
        var nodes: [Page] = []
        var node: Page? = current
        while let p = node {
            nodes.append(p)
            node = p.parent
        }
        return nodes.reversed()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                let crumbs = path
                ForEach(crumbs.indices, id: \.self) { idx in
                    let page = crumbs[idx]
                    Button {
                        onSelect(page)
                    } label: {
                        HStack(spacing: 4) {
                            Text(page.name)
                                .font(.subheadline)
                                .foregroundColor(idx == crumbs.count - 1 ? .primary : .blue)
                            if idx < crumbs.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(idx == crumbs.count - 1 ? Color.gray.opacity(0.15) : Color.blue.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Breadcrumb \(page.name)"))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
        }
    }
}
