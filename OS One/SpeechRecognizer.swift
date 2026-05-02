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
        case invalidAudioInputFormat(sampleRate: Double, channelCount: AVAudioChannelCount)
        
        var message: String {
            switch self {
            case .nilRecognizer: return "Can't initialize speech recognizer"
            case .notAuthorizedToRecognize: return "Not authorized to recognize speech"
            case .notPermittedToRecord: return "Not permitted to record audio"
            case .recognizerIsUnavailable: return "Recognizer is unavailable"
            case .invalidAudioInputFormat(let sampleRate, let channelCount):
                return "Audio input is unavailable (sample rate: \(sampleRate), channels: \(channelCount))"
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
    private let recognitionQueue = DispatchQueue(label: "Speech Recognizer Queue", qos: .default)
    private static let recognitionQueueKey = DispatchSpecificKey<Void>()
    private var isTapInstalled = false
    
    init() {
        recognizer = SFSpeechRecognizer()
        recognitionQueue.setSpecific(key: Self.recognitionQueueKey, value: ())
        
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
        recognitionQueue.async { [weak self] in
            guard let self = self, let recognizer = self.recognizer, recognizer.isAvailable else {
                self?.speakError(RecognizerError.recognizerIsUnavailable)
                return
            }
            
            do {
                self.resetOnRecognitionQueue(deactivateAudioSession: true)
                let (audioEngine, request) = try Self.prepareEngine()
                self.audioEngine = audioEngine
                self.request = request
                self.isTapInstalled = true
                self.task = recognizer.recognitionTask(with: request, resultHandler: self.recognitionHandler(result:error:))
            } catch {
                self.resetOnRecognitionQueue(deactivateAudioSession: true)
                self.speakError(error)
            }
        }
    }
    
    @MainActor func stopTranscribing() {
        reset()
    }
    
    func reset() {
        if DispatchQueue.getSpecific(key: Self.recognitionQueueKey) != nil {
            resetOnRecognitionQueue(deactivateAudioSession: true)
        } else {
            recognitionQueue.sync {
                resetOnRecognitionQueue(deactivateAudioSession: true)
            }
        }
    }

    private func resetOnRecognitionQueue(deactivateAudioSession: Bool) {
        task?.cancel()
        if isTapInstalled {
            audioEngine?.inputNode.removeTap(onBus: 0)
            isTapInstalled = false
        }
        audioEngine?.stop()
        audioEngine = nil
        request = nil
        task = nil
        timeoutTimer?.cancel()
        timeoutTimer = nil
        if deactivateAudioSession {
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            } catch {
                print("Failed to end audio session")
            }
        }
    }
    
    private static func prepareEngine() throws -> (AVAudioEngine, SFSpeechAudioBufferRecognitionRequest) {
        let audioEngine = AVAudioEngine()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.allowBluetoothA2DP, .allowBluetoothHFP])
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
        guard recordingFormat.sampleRate > 0, recordingFormat.channelCount > 0 else {
            throw RecognizerError.invalidAudioInputFormat(
                sampleRate: recordingFormat.sampleRate,
                channelCount: recordingFormat.channelCount
            )
        }

        var tapInstalled = false
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            request.append(buffer)
        }
        tapInstalled = true

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            if tapInstalled {
                inputNode.removeTap(onBus: 0)
            }
            audioEngine.stop()
            try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }

        return (audioEngine, request)
    }
    
    private func recognitionHandler(result: SFSpeechRecognitionResult?, error: Error?) {
        let receivedFinalResult = result?.isFinal ?? false
        let receivedError = error != nil
        
        if receivedFinalResult || receivedError {
            recognitionQueue.async { [weak self] in
                self?.resetOnRecognitionQueue(deactivateAudioSession: false)
            }
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
