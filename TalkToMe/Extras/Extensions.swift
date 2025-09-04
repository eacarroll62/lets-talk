//
//  Extensions.swift
//  TalkToMe
//
//  Created by Eric Carroll on 7/3/23.
//

import SwiftUI
import SwiftData

extension Color {
    static let offWhite = Color(red: 225 / 255, green: 225 / 255, blue: 235 / 255)
    static let darkStart = Color(red: 50 / 255, green: 60 / 255, blue: 65 / 255)
    static let darkEnd = Color(red: 25 / 255, green: 25 / 255, blue: 30 / 255)
    static let lightStart = Color(red: 60 / 255, green: 160 / 255, blue: 240 / 255)
    static let lightEnd = Color(red: 30 / 255, green: 80 / 255, blue: 120 / 255)
    static let lightBlue = Color(red: 135 / 255, green: 206 / 255, blue: 250 / 255)
    static let ghostWhite = Color(red: 248 / 255, green: 248 / 255, blue: 255 / 255)
    static let ivory = Color(red: 255 / 255, green: 255 / 255, blue: 240 / 255)
    static let tealBlue = Color(red: 0 / 255, green: 255 / 255, blue: 255 / 255)
    static let whiteSmoke = Color(red: 245 / 255, green: 245 / 255, blue: 245 / 255)
    static let goldYellow = Color(red: 248 / 255, green: 239 / 255, blue: 0 / 255)
    static let lightSeaGreen = Color(red: 32 / 255, green: 178 / 255, blue: 170 / 255, opacity: 0.25)
    static let metallicGold = Color(red: 190 / 255, green: 183 / 255, blue: 2 / 255)
    static let bluePurple = Color(red: 104 / 255, green: 104 / 255, blue: 233 / 255, opacity: 1.0)
    static let greenYellow = Color(red: 173 / 255, green: 255 / 255, blue: 47 / 255)
    static let yellowGreen = Color(red: 154 / 255, green: 205 / 255, blue: 50 / 255)
    static let deepPink = Color(red: 255 / 255, green: 20 / 255, blue: 147 / 255)
    static let crimson = Color(red: 220 / 255, green: 20 / 255, blue: 60 / 255, opacity: 1.0)
    static let fluorescentOrange = Color(red: 255 / 255, green: 191 / 255, blue: 0 / 255)
    static let darkOrange = Color(red: 255 / 255, green: 140 / 255, blue: 0 / 255)
    static let mediumSlateBlue = Color(red: 123 / 255, green: 104 / 255, blue: 238 / 255)
    static let mediumPurple = Color(red: 147 / 255, green: 112 / 255, blue: 219 / 255)
    static let indigo = Color(red: 75 / 255, green: 0 / 255, blue: 130 / 255)
    static let lemonChiffon = Color(red: 255 / 255, green: 250 / 255, blue: 205 / 255)
    static let olive = Color(red: 139 / 255, green: 143 / 255, blue: 19 / 255)
    static let oliveYellow = Color(red: 187 / 255, green: 228 / 255, blue: 30 / 255)
    static let fuchsia = Color(red: 246 / 255, green: 58 / 255, blue: 246 / 255)
    static let purple2 = Color(red: 181 / 255, green: 43 / 255, blue: 181 / 255)
    static let lawBorder = Color(red: 104 / 255, green: 104 / 255, blue: 233 / 255)
    static let law = Color(red: 75 / 255, green: 75 / 255, blue: 168 / 255)
    static let honeydew = Color(red: 212 / 255, green: 251 / 255, blue: 121 / 255, opacity: 1.0)
    static let lemon = Color(red: 255 / 255, green: 251 / 255, blue: 0 / 255, opacity: 1.0)
    static let hunterGreen = Color(red: 68/255, green: 105/255, blue: 61/255, opacity: 1.0)
    static let skyBlue = Color(red: 135 / 255, green: 206 / 255, blue: 235 / 255)
    static let peach = Color(red: 255 / 255, green: 218 / 255, blue: 185 / 255)
}

struct ContainerStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: .gray.opacity(0.3), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func containerStyle() -> some View {
        self.modifier(ContainerStyle())
    }
}

struct SafeAreaPadding: ViewModifier {
    func body(content: Content) -> some View {
        content
            .edgesIgnoringSafeArea(.horizontal)
            .padding(.horizontal)
    }
}

extension View {
    func safeAreaPadding() -> some View {
        self.modifier(SafeAreaPadding())
    }
}

struct DynamicListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(InsetGroupedListStyle())
    }
}

extension View {
    func dynamicListStyle() -> some View {
        self.modifier(DynamicListStyle())
    }
}
