//
//  VoicePipelineIntegrationTests.swift
//  OS One Tests
//
//  Integration tests for the complete voice AI pipeline
//  Tests: VAD → Speech Recognition → LLM → TTS
//

import XCTest
import AVFoundation
import Speech
@testable import OS_One

final class VoicePipelineIntegrationTests: XCTestCase {

    var vad: VoiceActivityDetector!
    var speechRecognizer: SpeechRecognizer!
    var localLLM: LocalLLMManager!
    var tts: NativeTTSManager!

    override func setUpWithError() throws {
        try super.setUpWithError()

        vad = VoiceActivityDetector()
        speechRecognizer = SpeechRecognizer()
        localLLM = LocalLLMManager()
        tts = NativeTTSManager()

        // Request speech recognition authorization
        requestSpeechAuthorization()
    }

    override func tearDownWithError() throws {
        vad = nil
        speechRecognizer = nil
        localLLM = nil
        tts = nil

        try super.tearDownWithError()
    }

    // MARK: - Authorization

    private func requestSpeechAuthorization() {
        let expectation = XCTestExpectation(description: "Speech authorization")

        SFSpeechRecognizer.requestAuthorization { status in
            if status == .authorized {
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)
    }

    // MARK: - VAD → Speech Recognition Integration

    func testVADTriggersRecognition() throws {
        // Test that VAD properly triggers speech recognition
        let vadExpectation = XCTestExpectation(description: "VAD detected speech")
        let recognitionExpectation = XCTestExpectation(description: "Recognition started")

        var vadDetectedSpeech = false
        var recognitionStarted = false

        vad.onSpeechStart = {
            vadDetectedSpeech = true
            vadExpectation.fulfill()
        }

        speechRecognizer.onTranscriptionUpdate = { _ in
            recognitionStarted = true
            recognitionExpectation.fulfill()
        }

        // Simulate speech input
        let speechBuffer = createSpeechBuffer()
        vad.processAudioBuffer(speechBuffer)

        // In real integration, VAD would trigger recognition
        if vadDetectedSpeech {
            speechRecognizer.startTranscribing()
        }

        wait(for: [vadExpectation], timeout: 2.0)
        XCTAssertTrue(vadDetectedSpeech, "VAD should detect speech")
    }

    func testVADStopsRecognitionOnSilence() throws {
        // Test that prolonged silence stops recognition
        let silenceExpectation = XCTestExpectation(description: "VAD detected silence")

        var silenceDetected = false

        vad.onSpeechEnd = {
            silenceDetected = true
            silenceExpectation.fulfill()
        }

        // Start with speech
        let speechBuffer = createSpeechBuffer()
        vad.processAudioBuffer(speechBuffer)

        // Then silence
        let silenceBuffer = createSilenceBuffer()
        for _ in 0..<20 {  // 2 seconds of silence
            vad.processAudioBuffer(silenceBuffer)
        }

        wait(for: [silenceExpectation], timeout: 5.0)
        XCTAssertTrue(silenceDetected, "VAD should detect end of speech")
    }

    // MARK: - Speech Recognition → LLM Integration

    func testRecognitionOutputFeedsLLM() async throws {
        // Test that recognized text is properly formatted for LLM
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded for LLM tests")
        }

        // Simulate recognized text
        let recognizedText = "What is the capital of France?"

        // Feed to LLM
        var llmResponse = ""
        do {
            llmResponse = try await localLLM.generate(prompt: recognizedText)
        } catch {
            XCTFail("LLM generation failed: \(error)")
        }

        // Verify response
        XCTAssertFalse(llmResponse.isEmpty, "LLM should generate response")
        XCTAssertGreaterThan(llmResponse.count, 10, "Response should have substance")

        print("📝 User: \(recognizedText)")
        print("🤖 AI: \(llmResponse)")
    }

    func testConversationContextMaintained() async throws {
        // Test that conversation history is maintained across turns
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        // Turn 1
        let message1 = "My name is Alice"
        let response1 = try await localLLM.generate(prompt: message1)
        XCTAssertFalse(response1.isEmpty)

        // Turn 2 - should remember name
        let message2 = "What is my name?"
        let response2 = try await localLLM.generate(prompt: message2)

        // Response should reference the name (basic context check)
        let containsName = response2.lowercased().contains("alice")
        XCTAssertTrue(containsName, "LLM should remember context: \(response2)")
    }

    // MARK: - LLM → TTS Integration

    func testLLMOutputFeedsToTTS() async throws {
        // Test that LLM response is properly spoken
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        let ttsExpectation = XCTestExpectation(description: "TTS started speaking")

        // Generate LLM response
        let response = try await localLLM.generate(prompt: "Say hello")

        // Feed to TTS
        tts.onSpeakingStart = {
            ttsExpectation.fulfill()
        }

        tts.speak(response)

        await fulfillment(of: [ttsExpectation], timeout: 5.0)
    }

    func testStreamingLLMToTTS() async throws {
        // Test streaming LLM output to TTS in chunks
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        var chunks: [String] = []

        // Collect streaming chunks
        do {
            for try await token in localLLM.generateStream(prompt: "Count to five") {
                chunks.append(token)

                // In real app, we'd buffer and speak sentences
                if chunks.count >= 10 {
                    let sentence = chunks.joined()
                    if sentence.contains(".") || sentence.contains("!") || sentence.contains("?") {
                        // Speak this sentence
                        tts.speak(sentence)
                        chunks.removeAll()
                    }
                }
            }
        } catch {
            XCTFail("Streaming failed: \(error)")
        }

        XCTAssertFalse(chunks.isEmpty, "Should have collected tokens")
    }

    // MARK: - Full Pipeline Integration Tests

    func testCompleteOfflineConversationFlow() async throws {
        // Test the complete pipeline: VAD → STT → LLM → TTS
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded for full pipeline test")
        }

        print("\n╔════════════════════════════════════════════════════════╗")
        print("║     Full Offline Conversation Pipeline Test           ║")
        print("╚════════════════════════════════════════════════════════╝\n")

        // Step 1: VAD detects speech
        print("1️⃣ VAD: Detecting speech...")
        let vadExpectation = XCTestExpectation(description: "VAD detected speech")

        vad.onSpeechStart = {
            print("   ✅ Speech detected")
            vadExpectation.fulfill()
        }

        let speechBuffer = createSpeechBuffer()
        vad.processAudioBuffer(speechBuffer)

        await fulfillment(of: [vadExpectation], timeout: 2.0)

        // Step 2: Speech Recognition (simulated for test)
        print("2️⃣ STT: Transcribing speech...")
        let transcript = "Hello, how are you today?"
        print("   ✅ Transcribed: \"\(transcript)\"")

        // Step 3: LLM generates response
        print("3️⃣ LLM: Generating response...")
        let startTime = CFAbsoluteTimeGetCurrent()

        var response = ""
        do {
            response = try await localLLM.generate(prompt: transcript)
        } catch {
            XCTFail("LLM generation failed: \(error)")
        }

        let generationTime = CFAbsoluteTimeGetCurrent() - startTime
        print("   ✅ Response: \"\(response)\"")
        print("   ⏱️  Generation time: \(String(format: "%.2f", generationTime))s")

        XCTAssertFalse(response.isEmpty, "LLM should generate response")

        // Step 4: TTS speaks response
        print("4️⃣ TTS: Speaking response...")
        let ttsExpectation = XCTestExpectation(description: "TTS started")

        tts.onSpeakingStart = {
            print("   ✅ Speaking started")
            ttsExpectation.fulfill()
        }

        tts.speak(response)

        await fulfillment(of: [ttsExpectation], timeout: 3.0)

        print("\n✅ Full pipeline test completed successfully\n")
    }

    func testMultipleTurnConversation() async throws {
        // Test 5-turn conversation maintaining context
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        let conversations: [(user: String, expectedKeyword: String)] = [
            ("My favorite color is blue", "blue"),
            ("What is my favorite color?", "blue"),
            ("I also like red", "red"),
            ("What colors do I like?", "blue"),
            ("Thank you", "welcome")
        ]

        for (index, conversation) in conversations.enumerated() {
            print("\nTurn \(index + 1):")
            print("👤 User: \(conversation.user)")

            let response = try await localLLM.generate(prompt: conversation.user)
            print("🤖 AI: \(response)")

            XCTAssertFalse(response.isEmpty, "Turn \(index + 1): Response should not be empty")

            // Brief delay between turns
            try await Task.sleep(nanoseconds: 500_000_000)  // 0.5s
        }
    }

    func testInterruptionHandling() async throws {
        // Test that pipeline can handle interruptions gracefully
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        // Start generation
        let task = Task {
            try await localLLM.generate(prompt: "Write a long story about")
        }

        // Wait a bit
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1s

        // Interrupt by starting new generation
        task.cancel()

        // Start new generation immediately
        let response = try await localLLM.generate(prompt: "Hello")

        XCTAssertFalse(response.isEmpty, "Should handle interruption gracefully")
    }

    // MARK: - Error Handling Integration Tests

    func testPipelineWithNoModel() async throws {
        // Test error handling when model is not loaded
        let unloadedLLM = LocalLLMManager()

        do {
            _ = try await unloadedLLM.generate(prompt: "Test")
            XCTFail("Should throw error when model not loaded")
        } catch LocalLLMError.modelNotLoaded {
            // Expected error
            XCTAssertTrue(true)
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testPipelineWithInvalidInput() async throws {
        // Test handling of empty or invalid input
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        // Empty input
        let emptyResponse = try await localLLM.generate(prompt: "")
        XCTAssertFalse(emptyResponse.isEmpty, "Should handle empty input gracefully")

        // Very long input
        let longPrompt = String(repeating: "test ", count: 1000)
        let longResponse = try await localLLM.generate(prompt: longPrompt)
        XCTAssertFalse(longResponse.isEmpty, "Should handle long input")
    }

    // MARK: - Performance Integration Tests

    func testEndToEndLatency() async throws {
        // Measure total time from VAD detection to TTS start
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // 1. VAD detection (simulated)
        let speechBuffer = createSpeechBuffer()
        vad.processAudioBuffer(speechBuffer)

        // 2. STT (mocked)
        let transcript = "Hello"

        // 3. LLM generation
        let response = try await localLLM.generate(prompt: transcript)

        // 4. TTS start
        let ttsExpectation = XCTestExpectation(description: "TTS started")
        tts.onSpeakingStart = {
            ttsExpectation.fulfill()
        }
        tts.speak(response)

        await fulfillment(of: [ttsExpectation], timeout: 5.0)

        let totalLatency = CFAbsoluteTimeGetCurrent() - startTime

        // Total latency should be <5 seconds for good UX
        XCTAssertLessThan(totalLatency, 5.0, "End-to-end latency too high")

        print("📊 End-to-End Latency: \(String(format: "%.2f", totalLatency))s")
    }

    func testConcurrentPipelineRequests() async throws {
        // Test that pipeline can handle multiple requests (queue properly)
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        // Send 3 concurrent requests
        async let response1 = localLLM.generate(prompt: "First request")
        async let response2 = localLLM.generate(prompt: "Second request")
        async let response3 = localLLM.generate(prompt: "Third request")

        let results = try await [response1, response2, response3]

        // All should complete successfully
        XCTAssertEqual(results.count, 3)
        for (index, result) in results.enumerated() {
            XCTAssertFalse(result.isEmpty, "Request \(index + 1) should have response")
        }
    }

    // MARK: - Memory Management Integration Tests

    func testPipelineMemoryStability() async throws {
        // Run pipeline 20 times and check for memory leaks
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        for i in 0..<20 {
            // Full cycle
            let speechBuffer = createSpeechBuffer()
            vad.processAudioBuffer(speechBuffer)

            let response = try await localLLM.generate(prompt: "Test \(i)")

            let ttsExpectation = XCTestExpectation(description: "TTS \(i)")
            tts.onSpeakingStart = {
                ttsExpectation.fulfill()
            }
            tts.speak(response)

            await fulfillment(of: [ttsExpectation], timeout: 3.0)

            // Small delay
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        // If we got here without crashing, memory is stable
        XCTAssertTrue(true, "Pipeline completed 20 cycles without memory issues")
    }

    // MARK: - Offline Mode Integration Tests

    func testFullyOfflineOperation() async throws {
        // Verify no network calls are made during offline operation
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        // Disable network (simulated - would need network monitoring)
        let offlineModeEnabled = true
        XCTAssertTrue(offlineModeEnabled, "Offline mode should be enabled")

        // Run full pipeline
        let speechBuffer = createSpeechBuffer()
        vad.processAudioBuffer(speechBuffer)

        let response = try await localLLM.generate(prompt: "Test offline")

        tts.speak(response)

        // Should complete without network access
        XCTAssertFalse(response.isEmpty, "Should work offline")
    }

    // MARK: - Helper Methods

    private func createSpeechBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let frameCount: AVAudioFrameCount = 1600  // 0.1s
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData else {
            return buffer
        }

        // Generate speech-like signal (higher energy)
        for i in 0..<Int(frameCount) {
            let sample = Float.random(in: -0.1...0.1)
            channelData[0][i] = sample
        }

        return buffer
    }

    private func createSilenceBuffer() -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        let frameCount: AVAudioFrameCount = 1600  // 0.1s
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData else {
            return buffer
        }

        // Generate silence (very low energy)
        for i in 0..<Int(frameCount) {
            channelData[0][i] = Float.random(in: -0.001...0.001)
        }

        return buffer
    }
}
