//
//  FavoritesList.swift
//  LetsTalk
//
//  Created by Eric Carroll on 12/15/24.
//

import SwiftUI

struct FavoritesList: View {
    @Binding var searchText: String
    @Binding var selectedFavorite: Favorite?
    @Environment(Speaker.self) private var speaker
    var favorites: [Favorite]
    var onDelete: (IndexSet) -> Void
    var onMove: (IndexSet, Int) -> Void

    var filteredFavorites: [Favorite] {
        if searchText.isEmpty {
            return favorites
        } else {
            return favorites.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        List {
            Section {
                TextField("Search Favorites", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
            }

            Section {
                ForEach(filteredFavorites) { favorite in
                    Text(favorite.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(6)
                        .background(
                            favorite == selectedFavorite ?
                            Color.blue.opacity(0.2) :
                            Color.yellow.opacity(0.2)
                        )
                        .cornerRadius(8)
                        .onTapGesture {
                            speaker.text = favorite.text
                            selectedFavorite = favorite
                        }
                }
                .onMove(perform: onMove)
                .onDelete(perform: onDelete)
            }
        }
        .dynamicListStyle()
    }
}
