//
//  SpeechRecogniser.swift
//  OS One
//
//  Created by Simon Loffler on 2/4/2023.
//

import AVFoundation
import Foundation
import Speech
import SwiftUI

class SpeechRecognizer: ObservableObject {
    enum RecognizerError: Error {
        case nilRecognizer
        case notAuthorizedToRecognize
        case notPermittedToRecord
        case recognizerIsUnavailable

        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            }
        }
    }

    @MainActor var transcript: String = ""

    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private let recognizer: SFSpeechRecognizer?
    private var updateState: ((String) -> Void)?
    private var onTimeout: (() -> Void)?
    private var timeoutTimer: DispatchSourceTimer?

    // MARK: - Voice Activity Detection
    private var voiceActivityDetector: VoiceActivityDetector?
    private var useVAD: Bool {
        UserDefaults.standard.bool(forKey: "useVAD")
    }
    private var onDeviceRecognition: Bool {
        UserDefaults.standard.bool(forKey: "onDeviceRecognition")
    }
    
    init() {
        // Use on-device recognition if enabled
        if onDeviceRecognition {
            recognizer = SFSpeechRecognizer()
            recognizer?.supportsOnDeviceRecognition = true
        } else {
            recognizer = SFSpeechRecognizer()
        }

        // Initialize VAD if enabled
        if useVAD {
            setupVoiceActivityDetection()
        }

        Task(priority: .medium) {
            do {
                guard recognizer != nil else {
                    throw RecognizerError.nilRecognizer
                }
                guard await SFSpeechRecognizer.hasAuthorizationToRecognize() else {
                    throw RecognizerError.notAuthorizedToRecognize
                }
                guard await AVAudioSession.sharedInstance().hasPermissionToRecord() else {
                    throw RecognizerError.notPermittedToRecord
                }
            } catch {
                speakError(error)
            }
        }
    }

    // MARK: - VAD Setup
    private func setupVoiceActivityDetection() {
        let vadConfig = VoiceActivityDetector.Configuration(
            energyThreshold: UserDefaults.standard.float(forKey: "vadThreshold") == 0 ? 0.02 : UserDefaults.standard.float(forKey: "vadThreshold"),
            silenceDuration: UserDefaults.standard.double(forKey: "vadSilenceDuration") == 0 ? 1.5 : UserDefaults.standard.double(forKey: "vadSilenceDuration"),
            speechStartDuration: 0.2,
            adaptiveThreshold: true,
            useMLDetection: true
        )

        voiceActivityDetector = VoiceActivityDetector(configuration: vadConfig)

        voiceActivityDetector?.onSpeechStart = { [weak self] in
            print("SpeechRecognizer: VAD detected speech start")
        }

        voiceActivityDetector?.onSpeechEnd = { [weak self] in
            print("SpeechRecognizer: VAD detected speech end")
            self?.onTimeout?()
            self?.stopTranscribing()
        }

        voiceActivityDetector?.onAudioLevel = { level in
            // Audio level feedback can be used for UI visualization
        }

        voiceActivityDetector?.startDetection()
        print("SpeechRecognizer: Voice Activity Detection initialized")
    }
    
    deinit {
        reset()
    }

    func setUpdateStateHandler(_ handler: @escaping (String) -> Void) {
        updateState = handler
    }

    func setOnTimeoutHandler(_ handler: @escaping () -> Void) {
        onTimeout = handler
    }

    @MainActor private func resetTimeoutTimer() {
        timeoutTimer?.cancel()
        timeoutTimer = DispatchSource.makeTimerSource(queue: .main)
        timeoutTimer?.schedule(deadline: .now() + 3.0)
        timeoutTimer?.setEventHandler { [weak self] in
            self?.onTimeout?()
            self?.stopTranscribing()
        }
        timeoutTimer?.resume()
    }

    func transcribe() {
        DispatchQueue(label: "Speech Recognizer Queue", qos: .default).async { [weak self] in
            guard let self = self, let recognizer = self.recognizer, recognizer.isAvailable else {
                self?.speakError(RecognizerError.recognizerIsUnavailable)
                return
            }
            
            do {
                let (audioEngine, request) = try Self.prepareEngine()
                self.audioEngine = audioEngine
                self.request = request
                self.task = recognizer.recognitionTask(with: request, resultHandler: self.recognitionHandler(result:error:))
            } catch {
                self.reset()
                self.speakError(error)
            }
        }
    }
    
    @MainActor func stopTranscribing() {
        reset()
    }
    
    func reset() {
        task?.cancel()
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
        timeoutTimer?.cancel()
        timeoutTimer = nil
        voiceActivityDetector?.resetDetection()

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to end audio session")
        }
    }

    // MARK: - VAD Access
    func getVoiceActivityDetector() -> VoiceActivityDetector? {
        return voiceActivityDetector
    }

    func updateVADSensitivity(_ sensitivity: Float) {
        voiceActivityDetector?.setSensitivity(sensitivity)
    }
    
    private static func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetoothA2DP, .allowBluetooth])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let inputNode = audioEngine.inputNode

        if let availableInputs = audioSession.availableInputs {
            for input in availableInputs {
                if input.portType == .headphones || input.portType == .bluetoothA2DP || input.portType == .bluetoothHFP || input.portType == .bluetoothLE {
                    do {
                        try audioSession.setPreferredInput(input)
                        break
                    } catch {
                        print("Error setting preferred input to headphones: \(error)")
                    }
                }
            }
        }

        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            request.append(buffer)

            // Process buffer with VAD if enabled
            if let vad = self?.voiceActivityDetector, self?.useVAD == true {
                vad.processAudioBuffer(buffer)
            }
        }
        audioEngine.prepare()
        try audioEngine.start()

        return (audioEngine, request)
    }
    
    private func recognitionHandler(result: SFSpeechRecognitionResult?, error: Error?) {
        let receivedFinalResult = result?.isFinal ?? false
        let receivedError = error != nil
        
        if receivedFinalResult || receivedError {
            audioEngine?.stop()
            audioEngine?.inputNode.removeTap(onBus: 0)
        }
        
        if let result = result {
            speak(result.bestTranscription.formattedString)
        }
    }
    
    private func speak(_ message: String) {
        Task { @MainActor in
            transcript = message
            if transcript != "" {
                updateState?(transcript)
                resetTimeoutTimer()
            } else {
                stopTranscribing()
            }
        }
    }
    
    private func speakError(_ error: Error) {
        var errorMessage = ""
        if let error = error as? RecognizerError {
            errorMessage += error.message
        } else {
            errorMessage += error.localizedDescription
        }
        Task { @MainActor [errorMessage] in
            transcript = "<< \(errorMessage) >>"
        }
    }
}

extension SFSpeechRecognizer {
    static func hasAuthorizationToRecognize() async -> Bool {
        await withCheckedContinuation { continuation in
            requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}

extension AVAudioSession {
    func hasPermissionToRecord() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { authorized in
                continuation.resume(returning: authorized)
            }
        }
    }
}
