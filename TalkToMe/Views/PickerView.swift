////
////  PickerView.swift
////  TalkToMe
////
////  Created by Eric Carroll on 8/15/23.
////
//
//import SwiftUI
//import AVFoundation
//
//struct PickerView: View {
//    @State var hourSelect = 0
//    @State var minuteSelect = 0
//    
//    private var voices: [AVSpeechSynthesisVoice] {
//        AVSpeechSynthesisVoice.speechVoices()
//    }
//    
//    @AppStorage("gender") private var gender: Int = AVSpeechSynthesisVoiceGender.male.rawValue
//    @AppStorage("identifier") private var identifier: String = "com.apple.voice.compact.en-US.Samantha"
//    @AppStorage("code") private var code: String = "en-US"
//    
//    var hours = [Int](0..<24)
//    var minutes = [Int](0..<60)
//    
//    var body: some View {
//        ZStack {
//            Color.black
//                .opacity(0.5)
//                .ignoresSafeArea()
//                .preferredColorScheme(.light)
//            Rectangle()
//                .fill(.white.opacity(1))
//                .cornerRadius(30)
//                .frame(width: 300, height: 350)
//            VStack {
//                Text("Header")
//                    HStack(spacing: 0) {
//                        Picker(selection: $code, label: Text("")) {
//                            ForEach(voices, id: \.self) {voice in
//                                Text(voice.language)
//                            }
//                        }
//                        .pickerStyle(.wheel)
//                        .frame(minWidth: 0)
//                        .compositingGroup()
//                        .clipped()
//                        
//                        Picker(selection: $gender, label: Text("")) {
//                            ForEach(0..<self.minutes.count) { index in
//                                Text("\(self.minutes[index])").tag(index)
//                           }
//                        }
//                        .pickerStyle(.wheel)
//                        .frame(minWidth: 0)
//                        .compositingGroup()
//                        .clipped()
//                    }
//            }
//        }
//
//    }
//}
//
//#Preview {
//    PickerView()
//}
