import SwiftUI

struct DoubleHelixView: View {

    @State private var speed: Double = 300

    var body: some View {
        ZStack {
            Color(
                red: 240/255,
                green: 88/255,
                blue: 56/255
            ).edgesIgnoringSafeArea(.all)
            ZStack {
                Helix(color: .black, rotationOffset: 0, reverseRotation: false, speed: $speed)
                Helix(color: .black, rotationOffset: 120, reverseRotation: true, speed: $speed)
                Helix(color: .black, rotationOffset: 240, reverseRotation: false, speed: $speed)
            }
            .opacity(0.2)
        }
    }
}

struct Helix: View {
    let color: Color
    let rotationOffset: Double
    let reverseRotation: Bool
    @Binding var speed: Double
    @State private var rotate = false

    var body: some View {
        ForEach(0..<12) { i in
            SineWave(amplitude: 90, frequency: 1)
                .stroke(color, lineWidth: 4)
                .frame(height: 90)
                .offset(y: CGFloat(i) * 90)
                .rotation3DEffect(
                    .degrees(Double(i) * 36 + rotationOffset + (rotate ? 360 : 0)),
                    axis: (x: 1, y: 0, z: 0),
                    anchor: .top,
                    anchorZ: 0.0,
                    perspective: 0
                )
        }
        .onAppear {
            withAnimation(Animation.linear(duration: speed).repeatForever(autoreverses: false)) {
                rotate.toggle()
            }
        }
        .rotation3DEffect(.degrees(reverseRotation ? 180 : 0), axis: (x: 0, y: 1, z: 0))
    }
}

struct SineWave: Shape {
    var amplitude: CGFloat
    var frequency: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            let midHeight = rect.height / 2
            let width = rect.width

            path.move(to: CGPoint(x: 0, y: midHeight))

            for x in stride(from: CGFloat(0), through: width, by: 1) {
                let relativeX = x / width
                let y = midHeight + amplitude * sin(relativeX * .pi * 2 * frequency)
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
    }
}

struct DoubleHelixView_Previews: PreviewProvider {
    static var previews: some View {
        DoubleHelixView()
    }
}
