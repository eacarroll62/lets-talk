//
//  HeaderView.swift
//  LetsTalk
//
//  Created by Eric Carroll on 7/8/23.
//

import SwiftUI

struct HeaderView: View {
    var imageString: String
    var textString: String
    var backColor: Color
    var showButton: Bool
    @State private var showAddView: Bool = false
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: imageString)
                    .foregroundColor(Color.mediumPurple)
                Text(textString)
                    .textCase(.none)
                    .foregroundColor(Color.gray)
                if showButton {
                    Button(action: {showAddView.toggle()}) {
                        Image(systemName: "plus")
                    }
                    .padding()
                    .background(backColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }
}

#Preview {
    HeaderView(imageString: "person.circle.fill", textString: "People", backColor: Color.clear, showButton: true)
}
