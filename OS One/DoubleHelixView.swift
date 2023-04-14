//
//  DoubleHelixView.swift
//  OS One
//
//  Created by Simon Loffler on 14/4/2023.
//

import SwiftUI

struct DoubleHelixView: View {
    @State private var rotate = false

    var body: some View {
        ZStack {
            Color(
                red: 240/255,
                green: 88/255,
                blue: 56/255
            ).edgesIgnoringSafeArea(.all)
            Helix(color: .accentColor, rotationOffset: 0, reverseRotation: false)
                .rotation3DEffect(
                    .degrees(rotate ? 360 : 0),
                    axis: (x: 0, y: 1, z: 0)
                )
                .rotationEffect(.degrees(90))
        }
        .onAppear {
            withAnimation(Animation.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotate.toggle()
            }
        }
    }
}

struct Helix: View {
    let color: Color
    let rotationOffset: Double
    let reverseRotation: Bool

    var body: some View {
        ForEach(0..<3) { i in
            Circle()
                // .stroke(color, lineWidth: 2)
                .frame(width: 100, height: 100)
                .offset(y: CGFloat(i) * 60)
                .padding(.top, -110)
                // .foregroundColor(.white)
        }
    }
}


struct Helix_Previews: PreviewProvider {
    static var previews: some View {
        DoubleHelixView()
    }
}
