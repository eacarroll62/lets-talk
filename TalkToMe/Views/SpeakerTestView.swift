//
//  SpeakerTestView.swift
//  TalkToMe
//
//  Created by Eric Carroll on 12/13/24.
//

import SwiftUI
import Observation

struct SpeakerTestView: View {
    @Environment(Speaker.self) private var speaker
    @State private var speechText: String = "Hello, world! This is a speech test."
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Speaker State: \(speaker.state.rawValue)")
                .font(.headline)
            
            TextField("Enter text to speak", text: $speechText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()

            HStack {
                Button {speaker.speak(speechText)} label: {Image(systemName: "play")}
                .buttonStyle(.borderedProminent)
                
                Button {speaker.pause()} label: {Image(systemName: "pause")}
                .buttonStyle(.borderedProminent)
                
                Button {speaker.continueSpeaking()} label: {Image(systemName: "forward.fill")}
                .buttonStyle(.borderedProminent)
                
                Button {speaker.stop()} label: {Image(systemName: "stop")}
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .onAppear {
            // Set UserDefaults for testing
            UserDefaults.standard.set("en-US", forKey: "language")
            UserDefaults.standard.set(0.5, forKey: "rate")
            UserDefaults.standard.set(1.0, forKey: "pitch")
            UserDefaults.standard.set(1.0, forKey: "volume")
        }
    }
}

#Preview {
    SpeakerTestView()
        .environment(Speaker())
}
