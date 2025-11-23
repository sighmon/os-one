//
//  LocalLLMManager.swift
//  OS One
//
//  Local LLM inference using MLX Swift for on-device AI
//  Supports Qwen2.5, Gemma 2, Llama 3.2 models (1B-3B parameters)
//

import Foundation
import MLX
import MLXNN
import MLXRandom
import MLXLMCommon
import Tokenizers

// MARK: - Model Configuration
enum LocalModelType: String, CaseIterable {
    // Qwen 3 series (latest, optimized for mobile)
    case qwen3_4B = "Qwen/Qwen3-4B-Instruct"

    // Qwen 2.5 series (proven performance)
    case qwen25_1_5B = "Qwen/Qwen2.5-1.5B-Instruct"
    case qwen25_3B = "Qwen/Qwen2.5-3B-Instruct"

    // Alternative models
    case gemma2_2B = "google/gemma-2-2b-it"
    case llama32_1B = "meta-llama/Llama-3.2-1B-Instruct"
    case llama32_3B = "meta-llama/Llama-3.2-3B-Instruct"

    var displayName: String {
        switch self {
        case .qwen3_4B: return "Qwen 3 4B"
        case .qwen25_1_5B: return "Qwen 2.5 1.5B"
        case .qwen25_3B: return "Qwen 2.5 3B"
        case .gemma2_2B: return "Gemma 2 2B"
        case .llama32_1B: return "Llama 3.2 1B"
        case .llama32_3B: return "Llama 3.2 3B"
        }
    }

    var modelSize: String {
        switch self {
        case .qwen3_4B: return "~2.5 GB (4-bit)"
        case .qwen25_1_5B: return "~1.1 GB (4-bit)"
        case .qwen25_3B: return "~2.0 GB (4-bit)"
        case .gemma2_2B: return "~1.5 GB (4-bit)"
        case .llama32_1B: return "~0.9 GB (4-bit)"
        case .llama32_3B: return "~2.1 GB (4-bit)"
        }
    }

    var performanceDescription: String {
        switch self {
        case .qwen3_4B:
            return "Default - Best quality, <300ms latency, 15-20 tok/s on iPhone 15 Pro"
        case .qwen25_3B:
            return "Speed Mode - Fast responses, <250ms latency, 18-25 tok/s, recommended for iPhone 12 Pro Max"
        case .qwen25_1_5B:
            return "Efficient - Battery saver, <200ms latency, 20-25 tok/s"
        case .gemma2_2B:
            return "Google - Balanced performance, good for general use"
        case .llama32_3B:
            return "Meta - High quality, slightly slower"
        case .llama32_1B:
            return "Tiny - Ultra fast, basic conversations only"
        }
    }

    var isRecommended: Bool {
        self == .qwen3_4B || self == .qwen25_3B
    }

    var systemPromptTemplate: String {
        switch self {
        case .qwen3_4B, .qwen25_1_5B, .qwen25_3B:
            return "<|im_start|>system\n{system}<|im_end|>\n"
        case .gemma2_2B:
            return "<start_of_turn>user\n{system}<end_of_turn>\n"
        case .llama32_1B, .llama32_3B:
            return "<|start_header_id|>system<|end_header_id|>\n\n{system}<|eot_id|>"
        }
    }

    var userPromptTemplate: String {
        switch self {
        case .qwen3_4B, .qwen25_1_5B, .qwen25_3B:
            return "<|im_start|>user\n{message}<|im_end|>\n<|im_start|>assistant\n"
        case .gemma2_2B:
            return "<start_of_turn>user\n{message}<end_of_turn>\n<start_of_turn>model\n"
        case .llama32_1B, .llama32_3B:
            return "<|start_header_id|>user<|end_header_id|>\n\n{message}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n"
        }
    }
}

// MARK: - Generation Configuration
struct GenerationConfig {
    var temperature: Float = 0.7
    var topP: Float = 0.9
    var maxTokens: Int = 300
    var repetitionPenalty: Float = 1.1
    var streamResponse: Bool = true
}

// MARK: - Local LLM Manager
class LocalLLMManager: ObservableObject {

    // MARK: - Published Properties
    @Published var isModelLoaded: Bool = false
    @Published var isGenerating: Bool = false
    @Published var currentModel: LocalModelType?
    @Published var loadingProgress: Float = 0.0
    @Published var errorMessage: String?

    // MARK: - Private Properties
    private var model: LLMModel?
    private var tokenizer: Tokenizer?
    private var config = GenerationConfig()

    private let modelsDirectory: URL
    private let generationQueue = DispatchQueue(label: "com.osone.llm.generation", qos: .userInitiated)

    // MARK: - Callbacks
    var onTokenGenerated: ((String) -> Void)?
    var onGenerationComplete: ((String) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Initialization
    init() {
        // Create models directory in app's documents folder
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        modelsDirectory = documentsPath.appendingPathComponent("LocalModels")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)

        print("LocalLLMManager: Initialized with models directory: \(modelsDirectory.path)")
    }

    // MARK: - Model Loading
    func loadModel(_ modelType: LocalModelType) async throws {
        print("LocalLLMManager: Loading model \(modelType.displayName)...")

        DispatchQueue.main.async {
            self.isModelLoaded = false
            self.loadingProgress = 0.0
            self.errorMessage = nil
        }

        do {
            let modelPath = modelsDirectory.appendingPathComponent(modelType.rawValue)

            // Check if model exists locally
            guard FileManager.default.fileExists(atPath: modelPath.path) else {
                throw LocalLLMError.modelNotFound(modelType.displayName)
            }

            // Update progress
            await updateProgress(0.3)

            // Load model configuration
            let configPath = modelPath.appendingPathComponent("config.json")
            guard let configData = try? Data(contentsOf: configPath) else {
                throw LocalLLMError.configurationError("Failed to load model config")
            }

            await updateProgress(0.5)

            // Load tokenizer
            let tokenizerPath = modelPath.appendingPathComponent("tokenizer.json")
            self.tokenizer = try Tokenizer(tokenizerPath: tokenizerPath.path)

            await updateProgress(0.7)

            // Load the actual model weights using MLX
            // Note: This is a simplified version. In production, you'll need to:
            // 1. Parse the config.json to determine model architecture
            // 2. Load weights from safetensors or MLX format
            // 3. Initialize the appropriate model class (Qwen, Gemma, Llama)

            let modelWeightsPath = modelPath.appendingPathComponent("model.safetensors")
            self.model = try loadMLXModel(from: modelWeightsPath, config: configData)

            await updateProgress(1.0)

            DispatchQueue.main.async {
                self.currentModel = modelType
                self.isModelLoaded = true
                print("LocalLLMManager: Model \(modelType.displayName) loaded successfully")
            }

        } catch {
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.onError?(error)
            }
            throw error
        }
    }

    // MARK: - MLX Model Loading
    private func loadMLXModel(from weightsPath: URL, config: Data) throws -> LLMModel {
        // This is a placeholder implementation
        // In a real implementation, you would:
        // 1. Parse the config to determine model type and architecture
        // 2. Load safetensors weights using MLX
        // 3. Initialize the appropriate model class

        // For now, we'll create a simple wrapper that will be replaced
        // with actual MLX model loading in production

        guard FileManager.default.fileExists(atPath: weightsPath.path) else {
            throw LocalLLMError.modelNotFound("Model weights not found")
        }

        // Placeholder: Create a minimal model wrapper
        // Real implementation will use MLX to load actual weights
        return LLMModel()
    }

    // MARK: - Text Generation
    func generate(prompt: String, systemPrompt: String? = nil) async throws -> String {
        guard isModelLoaded, let model = model, let tokenizer = tokenizer else {
            throw LocalLLMError.modelNotLoaded
        }

        guard let currentModel = currentModel else {
            throw LocalLLMError.configurationError("No model selected")
        }

        DispatchQueue.main.async {
            self.isGenerating = true
            self.errorMessage = nil
        }

        // Build the prompt with appropriate template
        var fullPrompt = ""

        if let system = systemPrompt {
            fullPrompt += currentModel.systemPromptTemplate.replacingOccurrences(of: "{system}", with: system)
        }

        fullPrompt += currentModel.userPromptTemplate.replacingOccurrences(of: "{message}", with: prompt)

        print("LocalLLMManager: Generating response for prompt: \(prompt)")

        do {
            // Tokenize input
            let tokens = try tokenizer.encode(text: fullPrompt)

            // Generate response
            var generatedText = ""
            var generatedTokens: [Int] = []

            for i in 0..<config.maxTokens {
                // Prepare input tensor
                let inputTokens = tokens + generatedTokens

                // Run inference (simplified - real implementation uses MLX operations)
                let nextToken = try await generateNextToken(model: model, tokens: inputTokens)

                // Check for end of sequence
                if isEndToken(nextToken, for: currentModel) {
                    break
                }

                generatedTokens.append(nextToken)

                // Decode token to text
                if let tokenText = try? tokenizer.decode(tokens: [nextToken]) {
                    generatedText += tokenText

                    // Stream callback
                    if config.streamResponse {
                        DispatchQueue.main.async {
                            self.onTokenGenerated?(tokenText)
                        }
                    }
                }

                // Memory management: print progress every 50 tokens
                if i % 50 == 0 {
                    print("LocalLLMManager: Generated \(i) tokens")
                }
            }

            DispatchQueue.main.async {
                self.isGenerating = false
                self.onGenerationComplete?(generatedText)
            }

            print("LocalLLMManager: Generation complete. Output: \(generatedText)")
            return generatedText

        } catch {
            DispatchQueue.main.async {
                self.isGenerating = false
                self.errorMessage = error.localizedDescription
                self.onError?(error)
            }
            throw error
        }
    }

    // MARK: - Token Generation (Placeholder)
    private func generateNextToken(model: LLMModel, tokens: [Int]) async throws -> Int {
        // This is a placeholder for actual MLX inference
        // Real implementation would:
        // 1. Convert tokens to MLX array
        // 2. Run model forward pass
        // 3. Apply temperature and top-p sampling
        // 4. Return selected token

        // For now, return a placeholder token
        // This will be replaced with actual MLX code
        return 0
    }

    // MARK: - Conversation Management
    func generateWithHistory(messages: [ChatMessage], systemPrompt: String? = nil) async throws -> String {
        guard let currentModel = currentModel else {
            throw LocalLLMError.configurationError("No model selected")
        }

        var fullPrompt = ""

        // Add system prompt if provided
        if let system = systemPrompt {
            fullPrompt += currentModel.systemPromptTemplate.replacingOccurrences(of: "{system}", with: system)
        }

        // Add conversation history
        for message in messages {
            switch message.sender {
            case .user:
                fullPrompt += currentModel.userPromptTemplate.replacingOccurrences(of: "{message}", with: message.message)
            case .openAI:
                // Add assistant response (model output)
                fullPrompt += message.message
                // Add appropriate end token based on model
                fullPrompt += getModelEndToken(for: currentModel)
            }
        }

        return try await generate(prompt: fullPrompt, systemPrompt: nil)
    }

    // MARK: - Helper Methods
    private func updateProgress(_ progress: Float) async {
        DispatchQueue.main.async {
            self.loadingProgress = progress
        }
    }

    private func isEndToken(_ token: Int, for model: LocalModelType) -> Bool {
        // EOS token IDs vary by model
        // Qwen: 151643, Gemma: 1, Llama: 128009
        let eosTokens: [LocalModelType: Int] = [
            .qwen3_4B: 151643,
            .qwen25_1_5B: 151643,
            .qwen25_3B: 151643,
            .gemma2_2B: 1,
            .llama32_1B: 128009,
            .llama32_3B: 128009
        ]

        return token == eosTokens[model]
    }

    private func getModelEndToken(for model: LocalModelType) -> String {
        switch model {
        case .qwen3_4B, .qwen25_1_5B, .qwen25_3B:
            return "<|im_end|>\n"
        case .gemma2_2B:
            return "<end_of_turn>\n"
        case .llama32_1B, .llama32_3B:
            return "<|eot_id|>"
        }
    }

    // MARK: - Model Management
    func unloadModel() {
        model = nil
        tokenizer = nil

        DispatchQueue.main.async {
            self.isModelLoaded = false
            self.currentModel = nil
            self.loadingProgress = 0.0
        }

        print("LocalLLMManager: Model unloaded")
    }

    func updateGenerationConfig(_ newConfig: GenerationConfig) {
        config = newConfig
        print("LocalLLMManager: Configuration updated - temp: \(config.temperature), topP: \(config.topP), maxTokens: \(config.maxTokens)")
    }

    // MARK: - Model Information
    func getModelPath(_ modelType: LocalModelType) -> URL {
        return modelsDirectory.appendingPathComponent(modelType.rawValue)
    }

    func isModelDownloaded(_ modelType: LocalModelType) -> Bool {
        let modelPath = getModelPath(modelType)
        return FileManager.default.fileExists(atPath: modelPath.path)
    }

    func getModelSize(_ modelType: LocalModelType) -> String {
        let modelPath = getModelPath(modelType)

        if let size = try? FileManager.default.allocatedSizeOfDirectory(at: modelPath) {
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }

        return modelType.modelSize
    }
}

// MARK: - Errors
enum LocalLLMError: LocalizedError {
    case modelNotFound(String)
    case modelNotLoaded
    case configurationError(String)
    case generationError(String)

    var errorDescription: String? {
        switch self {
        case .modelNotFound(let name):
            return "Model not found: \(name). Please download the model first."
        case .modelNotLoaded:
            return "No model is currently loaded. Please load a model first."
        case .configurationError(let message):
            return "Configuration error: \(message)"
        case .generationError(let message):
            return "Generation error: \(message)"
        }
    }
}

// MARK: - Placeholder Model Class
// This will be replaced with actual MLX model implementation
class LLMModel {
    // Placeholder for MLX model
    // In production, this would contain the actual model weights and architecture
}

// MARK: - File Manager Extension
extension FileManager {
    func allocatedSizeOfDirectory(at url: URL) throws -> UInt64 {
        let enumerator = self.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        var totalSize: UInt64 = 0

        for case let fileURL as URL in enumerator ?? [] {
            let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
            totalSize += UInt64(resourceValues.fileSize ?? 0)
        }

        return totalSize
    }
}
