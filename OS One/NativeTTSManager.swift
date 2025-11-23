//
//  NativeTTSManager.swift
//  OS One
//
//  Native text-to-speech manager with voice selection and queue management
//  Fully offline using AVSpeechSynthesizer
//

import AVFoundation
import Foundation

// MARK: - Voice Configuration
struct NativeVoice: Identifiable, Equatable {
    let id: String
    let name: String
    let language: String
    let gender: VoiceGender
    let quality: AVSpeechSynthesisVoiceQuality

    enum VoiceGender {
        case male
        case female
        case neutral
    }

    static func == (lhs: NativeVoice, rhs: NativeVoice) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Speech Configuration
struct SpeechConfiguration {
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate  // 0.0 to 1.0
    var pitch: Float = 1.0  // 0.5 to 2.0
    var volume: Float = 1.0  // 0.0 to 1.0
    var preUtteranceDelay: TimeInterval = 0.0
    var postUtteranceDelay: TimeInterval = 0.0
}

// MARK: - Native TTS Manager
class NativeTTSManager: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published var isSpeaking: Bool = false
    @Published var currentVoice: NativeVoice?
    @Published var availableVoices: [NativeVoice] = []
    @Published var queuedUtterances: Int = 0

    // MARK: - Configuration
    private var config = SpeechConfiguration()
    private let synthesizer = AVSpeechSynthesizer()
    private var utteranceQueue: [AVSpeechUtterance] = []

    // MARK: - Callbacks
    var onSpeechStart: (() -> Void)?
    var onSpeechComplete: (() -> Void)?
    var onSpeechCancelled: (() -> Void)?

    // MARK: - Predefined Voices for Personas
    private let personaVoices: [String: String] = [
        "Samantha": "com.apple.voice.compact.en-US.Samantha",  // Female, US
        "KITT": "com.apple.voice.compact.en-US.Fred",  // Male, US
        "GLaDOS": "com.apple.ttsbundle.siri_female_en-US_premium",  // Female, robotic
        "Spock": "com.apple.voice.compact.en-GB.Daniel",  // Male, UK
        "Janet": "com.apple.voice.compact.en-US.Samantha",  // Female, US
        "J.A.R.V.I.S.": "com.apple.ttsbundle.siri_male_en-GB_premium",  // Male, UK
        "Ava": "com.apple.voice.compact.en-GB.Kate"  // Female, UK
    ]

    // MARK: - Initialization
    override init() {
        super.init()
        synthesizer.delegate = self
        loadAvailableVoices()
        selectDefaultVoice()
        print("NativeTTSManager: Initialized with \(availableVoices.count) voices")
    }

    // MARK: - Voice Management
    private func loadAvailableVoices() {
        let systemVoices = AVSpeechSynthesisVoice.speechVoices()

        availableVoices = systemVoices.compactMap { voice in
            // Focus on high-quality English voices
            guard voice.language.hasPrefix("en") else { return nil }

            let gender: NativeVoice.VoiceGender
            if voice.identifier.contains("female") || voice.name.contains("Female") {
                gender = .female
            } else if voice.identifier.contains("male") || voice.name.contains("Male") {
                gender = .male
            } else {
                gender = .neutral
            }

            return NativeVoice(
                id: voice.identifier,
                name: voice.name,
                language: voice.language,
                gender: gender,
                quality: voice.quality
            )
        }

        // Sort by quality (enhanced first)
        availableVoices.sort { voice1, voice2 in
            if voice1.quality == .enhanced && voice2.quality != .enhanced {
                return true
            } else if voice1.quality != .enhanced && voice2.quality == .enhanced {
                return false
            }
            return voice1.name < voice2.name
        }
    }

    private func selectDefaultVoice() {
        // Try to select Samantha or best available voice
        if let samantha = availableVoices.first(where: { $0.name.contains("Samantha") }) {
            currentVoice = samantha
        } else if let enhanced = availableVoices.first(where: { $0.quality == .enhanced }) {
            currentVoice = enhanced
        } else {
            currentVoice = availableVoices.first
        }
    }

    func selectVoice(byId id: String) {
        if let voice = availableVoices.first(where: { $0.id == id }) {
            currentVoice = voice
            print("NativeTTSManager: Selected voice: \(voice.name)")
        }
    }

    func selectVoiceForPersona(_ personaName: String) {
        if let voiceId = personaVoices[personaName],
           let voice = availableVoices.first(where: { $0.id == voiceId }) {
            currentVoice = voice
            print("NativeTTSManager: Selected voice for \(personaName): \(voice.name)")
        } else {
            print("NativeTTSManager: No specific voice for \(personaName), using current voice")
        }
    }

    func getVoicesByGender(_ gender: NativeVoice.VoiceGender) -> [NativeVoice] {
        return availableVoices.filter { $0.gender == gender }
    }

    func getEnhancedVoices() -> [NativeVoice] {
        return availableVoices.filter { $0.quality == .enhanced }
    }

    // MARK: - Speech Synthesis
    func speak(_ text: String, withConfig customConfig: SpeechConfiguration? = nil) {
        guard !text.isEmpty else {
            print("NativeTTSManager: Cannot speak empty text")
            return
        }

        let utterance = AVSpeechUtterance(string: text)

        // Apply configuration
        let activeConfig = customConfig ?? config
        utterance.rate = activeConfig.rate
        utterance.pitchMultiplier = activeConfig.pitch
        utterance.volume = activeConfig.volume
        utterance.preUtteranceDelay = activeConfig.preUtteranceDelay
        utterance.postUtteranceDelay = activeConfig.postUtteranceDelay

        // Set voice
        if let voice = currentVoice {
            utterance.voice = AVSpeechSynthesisVoice(identifier: voice.id)
        }

        // Add to queue
        utteranceQueue.append(utterance)
        DispatchQueue.main.async {
            self.queuedUtterances = self.utteranceQueue.count
        }

        // Start speaking
        synthesizer.speak(utterance)

        print("NativeTTSManager: Speaking: \(text.prefix(50))...")
    }

    func speakWithRate(_ text: String, rate: Float) {
        var customConfig = config
        customConfig.rate = rate
        speak(text, withConfig: customConfig)
    }

    func speakWithPitch(_ text: String, pitch: Float) {
        var customConfig = config
        customConfig.pitch = pitch
        speak(text, withConfig: customConfig)
    }

    // MARK: - Queue Management
    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
            print("NativeTTSManager: Speech paused")
        }
    }

    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
            print("NativeTTSManager: Speech resumed")
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        utteranceQueue.removeAll()
        DispatchQueue.main.async {
            self.queuedUtterances = 0
            self.isSpeaking = false
        }
        print("NativeTTSManager: Speech stopped")
    }

    func stopAtBoundary() {
        synthesizer.stopSpeaking(at: .word)
        print("NativeTTSManager: Speech stopped at word boundary")
    }

    func clearQueue() {
        utteranceQueue.removeAll()
        DispatchQueue.main.async {
            self.queuedUtterances = 0
        }
        print("NativeTTSManager: Queue cleared")
    }

    // MARK: - Configuration
    func updateConfiguration(_ newConfig: SpeechConfiguration) {
        config = newConfig
        print("NativeTTSManager: Configuration updated - rate: \(config.rate), pitch: \(config.pitch)")
    }

    func setRate(_ rate: Float) {
        config.rate = max(AVSpeechUtteranceMinimumSpeechRate, min(rate, AVSpeechUtteranceMaximumSpeechRate))
    }

    func setPitch(_ pitch: Float) {
        config.pitch = max(0.5, min(pitch, 2.0))
    }

    func setVolume(_ volume: Float) {
        config.volume = max(0.0, min(volume, 1.0))
    }

    // MARK: - Convenience Methods
    func getSpeechRate() -> Float {
        return config.rate
    }

    func getPitch() -> Float {
        return config.pitch
    }

    func getVolume() -> Float {
        return config.volume
    }

    func getQueueSize() -> Int {
        return utteranceQueue.count
    }

    func getCurrentVoiceName() -> String {
        return currentVoice?.name ?? "Default"
    }

    // MARK: - Save/Load Settings
    func saveSettings() {
        UserDefaults.standard.set(config.rate, forKey: "ttsRate")
        UserDefaults.standard.set(config.pitch, forKey: "ttsPitch")
        UserDefaults.standard.set(config.volume, forKey: "ttsVolume")
        if let voiceId = currentVoice?.id {
            UserDefaults.standard.set(voiceId, forKey: "ttsVoiceId")
        }
        print("NativeTTSManager: Settings saved")
    }

    func loadSettings() {
        config.rate = UserDefaults.standard.float(forKey: "ttsRate") == 0 ? AVSpeechUtteranceDefaultSpeechRate : UserDefaults.standard.float(forKey: "ttsRate")
        config.pitch = UserDefaults.standard.float(forKey: "ttsPitch") == 0 ? 1.0 : UserDefaults.standard.float(forKey: "ttsPitch")
        config.volume = UserDefaults.standard.float(forKey: "ttsVolume") == 0 ? 1.0 : UserDefaults.standard.float(forKey: "ttsVolume")

        if let voiceId = UserDefaults.standard.string(forKey: "ttsVoiceId") {
            selectVoice(byId: voiceId)
        }

        print("NativeTTSManager: Settings loaded")
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension NativeTTSManager: AVSpeechSynthesizerDelegate {

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = true
        }
        onSpeechStart?()
        print("NativeTTSManager: Speech started")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // Remove from queue
        if let index = utteranceQueue.firstIndex(of: utterance) {
            utteranceQueue.remove(at: index)
        }

        DispatchQueue.main.async {
            self.queuedUtterances = self.utteranceQueue.count
            if self.utteranceQueue.isEmpty {
                self.isSpeaking = false
            }
        }

        if utteranceQueue.isEmpty {
            onSpeechComplete?()
            print("NativeTTSManager: Speech completed")
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        print("NativeTTSManager: Speech paused at boundary")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        print("NativeTTSManager: Speech continued")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        DispatchQueue.main.async {
            self.isSpeaking = false
            self.queuedUtterances = 0
        }
        utteranceQueue.removeAll()
        onSpeechCancelled?()
        print("NativeTTSManager: Speech cancelled")
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // Can be used for word-by-word highlighting in UI
    }
}
