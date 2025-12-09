//
//  ParakeetSTTClient.swift
//  OS One
//
//  NVIDIA Parakeet CTC Speech-to-Text Client
//  Provides high-quality ASR using Parakeet CTC 0.6 models (v2 or v3)
//

#if os(macOS)

import Foundation
import AVFoundation
import Accelerate

/// Speech-to-Text client using NVIDIA Parakeet CTC models
/// Supports both v2 and v3 variants of Parakeet CTC 0.6
@MainActor
class ParakeetSTTClient: NSObject, ObservableObject {

    // MARK: - Published Properties
    @Published var isRecording: Bool = false
    @Published var isProcessing: Bool = false
    @Published var lastTranscription: String = ""
    @Published var isModelLoaded: Bool = false
    @Published var error: String?

    // MARK: - Configuration
    enum ParakeetModel: String, CaseIterable {
        case ctc_06_v2 = "parakeet-ctc-0.6-v2"
        case ctc_06_v3 = "parakeet-ctc-0.6-v3"

        var displayName: String {
            switch self {
            case .ctc_06_v2:
                return "Parakeet CTC 0.6 v2 (Stable)"
            case .ctc_06_v3:
                return "Parakeet CTC 0.6 v3 (Latest)"
            }
        }

        var modelSize: String {
            switch self {
            case .ctc_06_v2:
                return "~600MB"
            case .ctc_06_v3:
                return "~620MB"
            }
        }

        var contextSeconds: Int {
            return 30  // 30 seconds of audio context
        }
    }

    private var selectedModel: ParakeetModel = .ctc_06_v3
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioBuffer: [Float] = []
    private let sampleRate: Double = 16000  // Parakeet expects 16kHz

    // MARK: - Initialization
    override init() {
        super.init()
        loadSettings()
    }

    // MARK: - Settings Management
    private func loadSettings() {
        if let modelString = UserDefaults.standard.string(forKey: "parakeetModel"),
           let model = ParakeetModel(rawValue: modelString) {
            selectedModel = model
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(selectedModel.rawValue, forKey: "parakeetModel")
    }

    // MARK: - Model Management

    /// Load the Parakeet model
    /// Note: This implementation uses a placeholder. In production, you would:
    /// 1. Download model from Hugging Face (nvidia/parakeet-ctc-0.6)
    /// 2. Convert to CoreML or ONNX format
    /// 3. Load using CoreML or ONNX Runtime
    func loadModel(_ model: ParakeetModel) async throws {
        isProcessing = true
        error = nil

        defer {
            isProcessing = false
        }

        // For now, we'll use a hybrid approach:
        // 1. Check if model is available locally (CoreML/ONNX)
        // 2. Fall back to API endpoint (could be local or remote)

        let modelPath = getModelPath(for: model)

        if FileManager.default.fileExists(atPath: modelPath) {
            // Load local model (CoreML or ONNX)
            try await loadLocalModel(path: modelPath)
        } else {
            // Use API endpoint (e.g., local inference server)
            try await checkAPIEndpoint()
        }

        isModelLoaded = true
        selectedModel = model
        saveSettings()
    }

    private func getModelPath(for model: ParakeetModel) -> String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let modelsDir = appSupport.appendingPathComponent("ParakeetModels")
        return modelsDir.appendingPathComponent("\(model.rawValue).mlmodelc").path
    }

    private func loadLocalModel(path: String) async throws {
        // Placeholder for CoreML model loading
        // In production: Use MLModel(contentsOf: URL(fileURLWithPath: path))
        try await Task.sleep(nanoseconds: 100_000_000)  // Simulate loading
    }

    private func checkAPIEndpoint() async throws {
        // Check for local inference server (e.g., running on localhost:8000)
        let endpoint = UserDefaults.standard.string(forKey: "parakeetEndpoint") ?? "http://localhost:8000"

        guard let url = URL(string: "\(endpoint)/health") else {
            throw ParakeetError.invalidEndpoint
        }

        let (_, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ParakeetError.serverNotRunning
        }
    }

    // MARK: - Audio Recording

    func startRecording() throws {
        guard !isRecording else { return }

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw ParakeetError.audioEngineFailure
        }

        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            throw ParakeetError.noInputDevice
        }

        // Configure audio format: 16kHz mono
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )

        guard let format = recordingFormat else {
            throw ParakeetError.audioFormatError
        }

        // Install tap to capture audio
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isRecording = true
        audioBuffer.removeAll()
    }

    func stopRecording() async -> String {
        guard isRecording else { return "" }

        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)

        isRecording = false
        isProcessing = true

        // Transcribe the collected audio
        let transcription = await transcribeAudio(audioBuffer)

        isProcessing = false
        lastTranscription = transcription
        audioBuffer.removeAll()

        return transcription
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))

        audioBuffer.append(contentsOf: samples)

        // Keep buffer size reasonable (max 30 seconds)
        let maxSamples = Int(sampleRate * 30)
        if audioBuffer.count > maxSamples {
            audioBuffer.removeFirst(audioBuffer.count - maxSamples)
        }
    }

    // MARK: - Transcription

    private func transcribeAudio(_ samples: [Float]) async -> String {
        do {
            // Try local model first
            if isModelLoaded {
                return try await transcribeWithLocalModel(samples)
            } else {
                // Fall back to API endpoint
                return try await transcribeWithAPI(samples)
            }
        } catch {
            self.error = error.localizedDescription
            return ""
        }
    }

    private func transcribeWithLocalModel(_ samples: [Float]) async throws -> String {
        // Placeholder for local inference
        // In production:
        // 1. Preprocess audio (normalize, extract features)
        // 2. Run through CoreML/ONNX model
        // 3. Decode CTC output to text

        // For now, return placeholder
        return "[Parakeet local transcription would appear here]"
    }

    private func transcribeWithAPI(_ samples: [Float]) async throws -> String {
        let endpoint = UserDefaults.standard.string(forKey: "parakeetEndpoint") ?? "http://localhost:8000"

        guard let url = URL(string: "\(endpoint)/transcribe") else {
            throw ParakeetError.invalidEndpoint
        }

        // Convert float samples to Data
        let audioData = samples.withUnsafeBytes { Data($0) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ParakeetError.apiError
        }

        let result = try JSONDecoder().decode(TranscriptionResponse.self, from: data)
        return result.text
    }

    // MARK: - Download Model

    func downloadModel(_ model: ParakeetModel) async throws {
        isProcessing = true
        error = nil

        defer {
            isProcessing = false
        }

        // Placeholder for model download from Hugging Face
        // In production:
        // 1. Download from https://huggingface.co/nvidia/parakeet-ctc-0.6
        // 2. Convert to CoreML format
        // 3. Save to application support directory

        let modelsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ParakeetModels")

        try FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        // Simulate download
        try await Task.sleep(nanoseconds: 2_000_000_000)
    }

    // MARK: - Errors

    enum ParakeetError: LocalizedError {
        case invalidEndpoint
        case serverNotRunning
        case audioEngineFailure
        case noInputDevice
        case audioFormatError
        case apiError
        case modelNotFound

        var errorDescription: String? {
            switch self {
            case .invalidEndpoint:
                return "Invalid Parakeet endpoint URL"
            case .serverNotRunning:
                return "Parakeet server is not running"
            case .audioEngineFailure:
                return "Failed to initialize audio engine"
            case .noInputDevice:
                return "No audio input device found"
            case .audioFormatError:
                return "Unsupported audio format"
            case .apiError:
                return "API request failed"
            case .modelNotFound:
                return "Parakeet model not found"
            }
        }
    }

    struct TranscriptionResponse: Codable {
        let text: String
        let confidence: Double?
    }
}

#endif
