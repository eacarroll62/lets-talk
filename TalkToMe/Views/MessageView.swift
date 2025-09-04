//
//  MessageView.swift
//  TalkToMe
//
//  Created by Eric Carroll on 7/8/23.
//

import SwiftUI
import AVFoundation
import SwiftData
import Observation

struct MessageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(Speaker.self) var speaker

    @AppStorage("controlStyle") private var controlStyle: ControlsStyle = .compact // AppStorage for persistence
    
    enum Field { case input }
    @FocusState private var focusedField: Field?
    
    var favorites: [Favorite]

    var body: some View {
        @Bindable var speaker = speaker
        
        VStack(alignment: .leading) {
            HeaderView(imageString: "ellipsis.message", textString: "Message", backColor: Color.clear, showButton: false)
            
            TextField("Enter your message", text: $speaker.text, axis: .vertical)
                .foregroundColor(.primary)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .input)
                .textInputAutocapitalization(.sentences)
                .lineLimit(5...5)
                .overlay(controlsOverlay(), alignment: .topTrailing)
            
            if controlStyle == .large {
                HStack {
                    playButton()
                    saveButton()
                }
            }
        }
        .padding()
        .border(Color.black)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                HStack {
                    Spacer()
                    Button {
                        focusedField = nil
                    } label: {
                        Image(systemName: "keyboard.chevron.compact.down")
                    }
                }
            }
        }
    }
    
    @MainActor
    private func saveFavorite(_ text: String) {
        let newOrder = favorites.count
        let newFavorite = Favorite(text: text, order: newOrder)
        modelContext.insert(newFavorite)
        
        do {
            try modelContext.save()
        } catch {
            print("Error saving to modelContext: \(error)")
        }
    }
    
    // MARK: - Subviews and Helpers

    private func controlsOverlay() -> some View {
        VStack {
            clearButton()
            if controlStyle == .compact {
                playButton()
                saveButton()
            }
            Spacer()
        }
    }
    
    private func clearButton() -> some View {
        Button(action: {
            speaker.text = ""
        }) {
            Image(systemName: "clear")
                .resizable()
                .frame(width: 25, height: 25)
                .aspectRatio(contentMode: .fit)
                .tint(Color.hunterGreen)
        }
        .accessibilityLabel("Clear Message Box")
    }

    private func playButton() -> some View {
        Button(action: {
            if speaker.state == .isPaused {
                speaker.continueSpeaking()
            } else {
                speaker.speak(speaker.text)
            }
        }) {
            Image(systemName: "play.circle.fill")
                .resizable()
                .frame(width: 25, height: 25)
                .aspectRatio(contentMode: .fit)
                .tint(Color.hunterGreen)
        }
        .accessibilityLabel("Play Message")
    }

    private func saveButton() -> some View {
        Button(action: {
            if !speaker.text.isEmpty {
                saveFavorite(speaker.text)
            }
        }) {
            Image(systemName: "square.and.arrow.down")
                .resizable()
                .frame(width: 25, height: 25)
                .aspectRatio(contentMode: .fit)
                .tint(Color.hunterGreen)
        }
        .accessibilityLabel("Save Message as Favorite")
    }
}
#Preview {
    MessageView(favorites: [Favorite(text: "Hello World", order: 0)])
        .modelContainer(for: [Favorite.self], inMemory: true)
        .environment(Speaker())
}

