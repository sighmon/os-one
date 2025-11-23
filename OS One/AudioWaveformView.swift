//
//  AudioWaveformView.swift
//  OS One
//
//  Real-time audio waveform visualization
//  Shows visual feedback during voice input
//

import SwiftUI

struct AudioWaveformView: View {
    // MARK: - Properties
    @Binding var audioLevel: Float
    @Binding var isSpeaking: Bool

    let barCount: Int = 40
    @State private var barHeights: [CGFloat] = Array(repeating: 0.1, count: 40)
    @State private var animationTimer: Timer?

    // MARK: - Colors
    private var waveformColor: Color {
        isSpeaking ? .green : .orange
    }

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(waveformColor.opacity(0.8))
                    .frame(width: 3, height: barHeights[index])
                    .animation(.easeInOut(duration: 0.1), value: barHeights[index])
            }
        }
        .frame(height: 60)
        .padding()
        .onAppear {
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: audioLevel) { _ in
            updateWaveform()
        }
    }

    // MARK: - Animation
    private func startAnimation() {
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updateWaveform()
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func updateWaveform() {
        let scaledLevel = CGFloat(audioLevel) * 50.0 + 5.0

        // Shift existing heights to the left
        for i in 0..<(barCount - 1) {
            barHeights[i] = barHeights[i + 1]
        }

        // Add new height at the end
        barHeights[barCount - 1] = scaledLevel

        // Add some variation for visual effect
        if audioLevel > 0.01 {
            let variation = CGFloat.random(in: -5.0...5.0)
            barHeights[barCount - 1] += variation
        }

        // Clamp values
        barHeights = barHeights.map { max(5.0, min($0, 60.0)) }
    }
}

// MARK: - Circular Waveform (Alternative Design)
struct CircularWaveformView: View {
    @Binding var audioLevel: Float
    @Binding var isSpeaking: Bool

    let circleCount: Int = 3

    var body: some View {
        ZStack {
            ForEach(0..<circleCount, id: \.self) { index in
                Circle()
                    .stroke(lineWidth: 2)
                    .fill(waveformColor(for: index).opacity(0.6))
                    .frame(width: circleSize(for: index), height: circleSize(for: index))
                    .scaleEffect(isSpeaking ? 1.0 + CGFloat(audioLevel) * 0.5 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: audioLevel)
            }

            // Center indicator
            Circle()
                .fill(isSpeaking ? Color.green : Color.orange)
                .frame(width: 20, height: 20)
        }
        .frame(width: 150, height: 150)
    }

    private func circleSize(for index: Int) -> CGFloat {
        return CGFloat(30 + (index * 30))
    }

    private func waveformColor(for index: Int) -> Color {
        return isSpeaking ? Color.green : Color.orange
    }
}

// MARK: - Simple Level Meter
struct AudioLevelMeter: View {
    @Binding var audioLevel: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 8)

                // Level indicator
                RoundedRectangle(cornerRadius: 4)
                    .fill(levelColor)
                    .frame(width: geometry.size.width * CGFloat(min(audioLevel, 1.0)), height: 8)
                    .animation(.easeInOut(duration: 0.1), value: audioLevel)
            }
        }
        .frame(height: 8)
        .padding(.horizontal)
    }

    private var levelColor: Color {
        if audioLevel < 0.3 {
            return .green
        } else if audioLevel < 0.7 {
            return .yellow
        } else {
            return .red
        }
    }
}

// MARK: - Preview
struct AudioWaveformView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AudioWaveformView(audioLevel: .constant(0.5), isSpeaking: .constant(true))
            CircularWaveformView(audioLevel: .constant(0.5), isSpeaking: .constant(true))
            AudioLevelMeter(audioLevel: .constant(0.5))
        }
        .padding()
    }
}
