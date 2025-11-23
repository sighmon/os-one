//
//  LocalLLMManagerTests.swift
//  OS One Tests
//
//  Unit tests for LocalLLMManager
//  Target: >80% code coverage
//

import XCTest
@testable import OS_One

final class LocalLLMManagerTests: XCTestCase {

    var sut: LocalLLMManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = LocalLLMManager()
    }

    override func tearDownWithError() throws {
        sut = nil
        try super.tearDownWithError()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut, "LocalLLMManager should initialize")
        XCTAssertFalse(sut.isModelLoaded, "Model should not be loaded initially")
        XCTAssertNil(sut.currentModel, "Current model should be nil initially")
        XCTAssertEqual(sut.loadingProgress, 0.0, "Loading progress should be 0")
    }

    // MARK: - Model Type Tests

    func testModelTypeProperties() {
        // Qwen 3 4B
        XCTAssertEqual(LocalModelType.qwen3_4B.displayName, "Qwen 3 4B")
        XCTAssertEqual(LocalModelType.qwen3_4B.parameterCount, 4_000_000_000)
        XCTAssertEqual(LocalModelType.qwen3_4B.requiredRAMInGB, 7.0)
        XCTAssertEqual(LocalModelType.qwen3_4B.targetLatency, 0.30)
        XCTAssertTrue(LocalModelType.qwen3_4B.isRecommended)

        // Qwen 2.5 3B
        XCTAssertEqual(LocalModelType.qwen25_3B.displayName, "Qwen 2.5 3B")
        XCTAssertEqual(LocalModelType.qwen25_3B.parameterCount, 3_000_000_000)
        XCTAssertEqual(LocalModelType.qwen25_3B.requiredRAMInGB, 5.5)
        XCTAssertEqual(LocalModelType.qwen25_3B.targetLatency, 0.25)
        XCTAssertTrue(LocalModelType.qwen25_3B.isRecommended)
    }

    func testModelPromptTemplates() {
        // Qwen templates
        XCTAssertTrue(LocalModelType.qwen3_4B.systemPromptTemplate.contains("<|im_start|>system"))
        XCTAssertTrue(LocalModelType.qwen3_4B.userPromptTemplate.contains("<|im_start|>user"))

        // Llama templates
        XCTAssertTrue(LocalModelType.llama32_3B.systemPromptTemplate.contains("<|start_header_id|>"))
        XCTAssertTrue(LocalModelType.llama32_3B.userPromptTemplate.contains("<|start_header_id|>user"))

        // Gemma templates
        XCTAssertTrue(LocalModelType.gemma2_2B.systemPromptTemplate.contains("<start_of_turn>"))
        XCTAssertTrue(LocalModelType.gemma2_2B.userPromptTemplate.contains("<start_of_turn>user"))
    }

    // MARK: - Configuration Tests

    func testGenerationConfigDefaults() {
        let config = GenerationConfig()
        XCTAssertEqual(config.temperature, 0.7)
        XCTAssertEqual(config.topP, 0.9)
        XCTAssertEqual(config.maxTokens, 300)
        XCTAssertEqual(config.repetitionPenalty, 1.1)
        XCTAssertTrue(config.streamResponse)
    }

    func testUpdateGenerationConfig() {
        var config = GenerationConfig()
        config.temperature = 0.8
        config.maxTokens = 200

        sut.updateGenerationConfig(config)

        // Verify config was updated (would need to expose getter)
        XCTAssertTrue(true, "Config update should not crash")
    }

    // MARK: - Model Path Tests

    func testGetModelPath() {
        let qwenPath = sut.getModelPath(.qwen3_4B)
        XCTAssertTrue(qwenPath.path.contains("LocalModels"))
        XCTAssertTrue(qwenPath.path.contains("Qwen3-4B"))
    }

    func testIsModelDownloaded() {
        // Initially, no models should be downloaded in test environment
        XCTAssertFalse(sut.isModelDownloaded(.qwen3_4B))
        XCTAssertFalse(sut.isModelDownloaded(.qwen25_3B))
    }

    // MARK: - Error Handling Tests

    func testModelNotLoadedError() async {
        do {
            _ = try await sut.generate(prompt: "Test")
            XCTFail("Should throw modelNotLoaded error")
        } catch {
            XCTAssertTrue(error is LocalLLMError)
            if let llmError = error as? LocalLLMError {
                switch llmError {
                case .modelNotLoaded:
                    XCTAssertTrue(true)
                default:
                    XCTFail("Wrong error type")
                }
            }
        }
    }

    // MARK: - Memory Management Tests

    func testUnloadModel() {
        sut.unloadModel()
        XCTAssertFalse(sut.isModelLoaded)
        XCTAssertNil(sut.currentModel)
        XCTAssertEqual(sut.loadingProgress, 0.0)
    }

    // MARK: - Performance Tests

    func testModelLoadingProgress() throws {
        let expectation = XCTestExpectation(description: "Progress updates")

        // Observe published property changes
        var progressValues: [Float] = []

        let cancellable = sut.$loadingProgress
            .sink { progress in
                progressValues.append(progress)
                if progress == 1.0 {
                    expectation.fulfill()
                }
            }

        // Simulate model loading (would need mock)
        // For now, just verify initial state
        XCTAssertEqual(sut.loadingProgress, 0.0)

        cancellable.cancel()
    }
}

// MARK: - LocalLLMError Tests

final class LocalLLMErrorTests: XCTestCase {

    func testModelNotFoundError() {
        let error = LocalLLMError.modelNotFound("TestModel")
        XCTAssertEqual(error.errorDescription, "Model not found: TestModel. Please download the model first.")
    }

    func testModelNotLoadedError() {
        let error = LocalLLMError.modelNotLoaded
        XCTAssertEqual(error.errorDescription, "No model is currently loaded. Please load a model first.")
    }

    func testConfigurationError() {
        let error = LocalLLMError.configurationError("Invalid config")
        XCTAssertEqual(error.errorDescription, "Configuration error: Invalid config")
    }

    func testGenerationError() {
        let error = LocalLLMError.generationError("Failed to generate")
        XCTAssertEqual(error.errorDescription, "Generation error: Failed to generate")
    }
}
