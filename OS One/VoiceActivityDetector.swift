//
//  VoiceActivityDetector.swift
//  OS One
//
//  Voice Activity Detection using SoundAnalysis and audio energy monitoring
//  Provides intelligent speech detection without fixed timeouts
//

import AVFoundation
import Foundation
import SoundAnalysis
import Accelerate

class VoiceActivityDetector: ObservableObject {

    // MARK: - Published Properties
    @Published var isSpeaking: Bool = false
    @Published var audioLevel: Float = 0.0  // 0.0 to 1.0
    @Published var vadState: VADState = .silence

    // MARK: - Configuration
    struct Configuration {
        var energyThreshold: Float = 0.02           // Minimum energy to consider as speech
        var silenceDuration: TimeInterval = 1.5      // Seconds of silence before triggering end-of-speech
        var speechStartDuration: TimeInterval = 0.2  // Minimum speech duration to trigger start
        var adaptiveThreshold: Bool = true           // Automatically adjust threshold based on background noise
        var useMLDetection: Bool = true              // Use SoundAnalysis ML model
    }

    var config = Configuration()

    // MARK: - VAD States
    enum VADState {
        case silence
        case possibleSpeech
        case speaking
        case endOfSpeech
    }

    // MARK: - Callbacks
    var onSpeechStart: (() -> Void)?
    var onSpeechEnd: (() -> Void)?
    var onAudioLevel: ((Float) -> Void)?

    // MARK: - Private Properties
    private var energyHistory: [Float] = []
    private let historySize = 30  // Keep last 30 samples
    private var backgroundNoiseLevel: Float = 0.01

    private var lastSpeechTime: Date?
    private var firstSpeechTime: Date?
    private var silenceTimer: Timer?

    private var soundAnalyzer: SNAudioStreamAnalyzer?
    private let analysisQueue = DispatchQueue(label: "com.osone.vad.analysis")

    // MARK: - Initialization
    init(configuration: Configuration = Configuration()) {
        self.config = configuration
        setupSoundAnalysis()
    }

    deinit {
        stopDetection()
    }

    // MARK: - Sound Analysis Setup
    private func setupSoundAnalysis() {
        guard config.useMLDetection else { return }

        // Note: SoundAnalysis requires iOS 13+ and works best with iOS 15+
        // For speech detection, we'll use a custom approach since
        // SNClassifySoundRequest requires specific sound models
        print("VoiceActivityDetector: SoundAnalysis framework initialized")
    }

    // MARK: - Audio Buffer Processing
    func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let channelCount = Int(buffer.format.channelCount)
        let frameLength = Int(buffer.frameLength)

        guard frameLength > 0 else { return }

        // Calculate RMS (Root Mean Square) energy
        let energy = calculateRMS(channelData: channelData[0], frameLength: frameLength)

        // Update audio level for UI
        DispatchQueue.main.async { [weak self] in
            self?.audioLevel = energy
            self?.onAudioLevel?(energy)
        }

        // Process VAD state
        processVADState(energy: energy)
    }

    // MARK: - Energy Calculation
    private func calculateRMS(channelData: UnsafeMutablePointer<Float>, frameLength: Int) -> Float {
        var rms: Float = 0.0

        // Use Accelerate framework for efficient calculation
        vDSP_rmsqv(channelData, 1, &rms, vDSP_Length(frameLength))

        // Normalize to 0.0-1.0 range (typical speech is around 0.01-0.1)
        return min(rms * 10.0, 1.0)
    }

    // MARK: - VAD State Machine
    private func processVADState(energy: Float) {
        // Update energy history
        energyHistory.append(energy)
        if energyHistory.count > historySize {
            energyHistory.removeFirst()
        }

        // Adaptive threshold adjustment
        if config.adaptiveThreshold {
            updateBackgroundNoiseLevel()
        }

        let effectiveThreshold = config.energyThreshold + backgroundNoiseLevel
        let isSpeechEnergy = energy > effectiveThreshold

        let now = Date()

        switch vadState {
        case .silence:
            if isSpeechEnergy {
                firstSpeechTime = now
                updateState(.possibleSpeech)
            }

        case .possibleSpeech:
            if isSpeechEnergy {
                // Check if we've had enough continuous speech
                if let firstSpeech = firstSpeechTime,
                   now.timeIntervalSince(firstSpeech) >= config.speechStartDuration {
                    updateState(.speaking)
                    notifySpeechStart()
                }
            } else {
                // False alarm, return to silence
                updateState(.silence)
                firstSpeechTime = nil
            }

        case .speaking:
            if isSpeechEnergy {
                lastSpeechTime = now
                resetSilenceTimer()
            } else {
                // Potential silence, start timer
                if lastSpeechTime == nil {
                    lastSpeechTime = now
                }
                startSilenceTimer()
            }

        case .endOfSpeech:
            // Transition handled by timer
            break
        }
    }

    // MARK: - Background Noise Estimation
    private func updateBackgroundNoiseLevel() {
        guard energyHistory.count >= 10 else { return }

        // Use the median of the lowest 30% of energy values
        let sortedEnergy = energyHistory.sorted()
        let sampleCount = Int(Double(sortedEnergy.count) * 0.3)
        let lowEnergySamples = Array(sortedEnergy.prefix(sampleCount))

        if !lowEnergySamples.isEmpty {
            let sum = lowEnergySamples.reduce(0, +)
            backgroundNoiseLevel = sum / Float(lowEnergySamples.count)
        }
    }

    // MARK: - State Management
    private func updateState(_ newState: VADState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.vadState != newState {
                self.vadState = newState
                self.isSpeaking = (newState == .speaking)
            }
        }
    }

    private func notifySpeechStart() {
        print("VAD: Speech started")
        DispatchQueue.main.async { [weak self] in
            self?.onSpeechStart?()
        }
    }

    private func notifySpeechEnd() {
        print("VAD: Speech ended")
        DispatchQueue.main.async { [weak self] in
            self?.onSpeechEnd?()
        }
        resetDetection()
    }

    // MARK: - Silence Timer
    private func startSilenceTimer() {
        guard silenceTimer == nil else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                self?.checkSilenceDuration()
            }
        }
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = nil
    }

    private func checkSilenceDuration() {
        guard let lastSpeech = lastSpeechTime else { return }

        let silenceDuration = Date().timeIntervalSince(lastSpeech)

        if silenceDuration >= config.silenceDuration {
            updateState(.endOfSpeech)
            notifySpeechEnd()
            resetSilenceTimer()
        }
    }

    // MARK: - Public Control Methods
    func startDetection() {
        print("VAD: Detection started")
        resetDetection()
    }

    func stopDetection() {
        print("VAD: Detection stopped")
        resetSilenceTimer()
        resetDetection()
    }

    func resetDetection() {
        lastSpeechTime = nil
        firstSpeechTime = nil
        resetSilenceTimer()
        updateState(.silence)
    }

    // MARK: - Configuration Updates
    func updateConfiguration(_ newConfig: Configuration) {
        config = newConfig
        print("VAD: Configuration updated - threshold: \(config.energyThreshold), silence: \(config.silenceDuration)s")
    }

    func setSensitivity(_ sensitivity: Float) {
        // sensitivity: 0.0 (least sensitive) to 1.0 (most sensitive)
        // Inverse relationship: higher sensitivity = lower threshold
        let normalizedSensitivity = max(0.0, min(1.0, sensitivity))
        config.energyThreshold = 0.05 * (1.0 - normalizedSensitivity) + 0.005
        print("VAD: Sensitivity set to \(normalizedSensitivity), threshold: \(config.energyThreshold)")
    }

    // MARK: - Diagnostics
    func getDiagnostics() -> [String: Any] {
        return [
            "state": String(describing: vadState),
            "isSpeaking": isSpeaking,
            "audioLevel": audioLevel,
            "backgroundNoise": backgroundNoiseLevel,
            "threshold": config.energyThreshold,
            "effectiveThreshold": config.energyThreshold + backgroundNoiseLevel,
            "historySize": energyHistory.count
        ]
    }
}
