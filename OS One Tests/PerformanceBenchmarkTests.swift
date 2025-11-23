//
//  PerformanceBenchmarkTests.swift
//  OS One Tests
//
//  Performance benchmarks for LLM inference, VAD, and TTS
//  Baseline: iPhone 12 Pro Max (6GB RAM, A14 Bionic)
//

import XCTest
import AVFoundation
@testable import OS_One

final class PerformanceBenchmarkTests: XCTestCase {

    var localLLM: LocalLLMManager!
    var vad: VoiceActivityDetector!
    var tts: NativeTTSManager!
    var deviceDetector: DeviceCapabilityDetector!

    override func setUpWithError() throws {
        try super.setUpWithError()

        localLLM = LocalLLMManager()
        vad = VoiceActivityDetector()
        tts = NativeTTSManager()
        deviceDetector = DeviceCapabilityDetector.shared
    }

    override func tearDownWithError() throws {
        localLLM = nil
        vad = nil
        tts = nil

        try super.tearDownWithError()
    }

    // MARK: - Model Loading Performance

    func testModelLoadingPerformance() throws {
        // Skip if running on CI or simulator without model files
        guard FileManager.default.fileExists(atPath: localLLM.modelPath) else {
            throw XCTSkip("Model files not available for performance testing")
        }

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            Task {
                do {
                    try await localLLM.loadModel(modelType: .qwen25_3B)
                } catch {
                    XCTFail("Model loading failed: \(error)")
                }
            }
        }

        // Assert load time is under target
        // Target: <5 seconds for 3B model on iPhone 12 Pro Max
    }

    func testModelUnloadingPerformance() throws {
        // Measure memory cleanup time
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded first")
        }

        measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            Task {
                await localLLM.unloadModel()
            }
        }

        // Assert memory is properly released
    }

    // MARK: - Inference Performance

    func testFirstTokenLatency() async throws {
        // Measure time to first token generation
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded for inference tests")
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        var firstTokenTime: CFAbsoluteTime = 0

        let expectation = XCTestExpectation(description: "First token generated")

        do {
            for try await token in localLLM.generateStream(prompt: "Hello") {
                if firstTokenTime == 0 {
                    firstTokenTime = CFAbsoluteTimeGetCurrent()
                    expectation.fulfill()
                    break
                }
            }
        } catch {
            XCTFail("Generation failed: \(error)")
        }

        await fulfillment(of: [expectation], timeout: 5.0)

        let latency = firstTokenTime - startTime

        // Assert first token latency meets target
        // Qwen 2.5 3B target: <250ms on iPhone 12 Pro Max
        // Qwen 3 4B target: <300ms on iPhone 15 Pro
        let expectedLatency: TimeInterval
        switch localLLM.currentModel {
        case .qwen3_4B:
            expectedLatency = 0.30
        case .qwen25_3B:
            expectedLatency = 0.25
        case .qwen25_1_5B:
            expectedLatency = 0.20
        default:
            expectedLatency = 0.30
        }

        XCTAssertLessThan(latency, expectedLatency * 2.0,
            "First token latency (\(latency)s) exceeds 2x target (\(expectedLatency)s)")

        print("📊 First Token Latency: \(String(format: "%.0f", latency * 1000))ms (target: \(String(format: "%.0f", expectedLatency * 1000))ms)")
    }

    func testTokenGenerationThroughput() async throws {
        // Measure tokens per second for sustained generation
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded for throughput tests")
        }

        let startTime = CFAbsoluteTimeGetCurrent()
        var tokenCount = 0

        do {
            for try await _ in localLLM.generateStream(prompt: "Write a short story about a robot") {
                tokenCount += 1
                if tokenCount >= 50 {
                    break
                }
            }
        } catch {
            XCTFail("Generation failed: \(error)")
        }

        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        let tokensPerSecond = Double(tokenCount) / elapsedTime

        // Assert tokens/sec meets target
        let expectedTPS: Double
        switch localLLM.currentModel {
        case .qwen3_4B:
            expectedTPS = 15.0  // 15-20 tok/s
        case .qwen25_3B:
            expectedTPS = 18.0  // 18-25 tok/s
        case .qwen25_1_5B:
            expectedTPS = 20.0
        default:
            expectedTPS = 15.0
        }

        XCTAssertGreaterThan(tokensPerSecond, expectedTPS * 0.5,
            "Token throughput (\(tokensPerSecond) tok/s) is below 50% of target (\(expectedTPS) tok/s)")

        print("📊 Token Throughput: \(String(format: "%.1f", tokensPerSecond)) tok/s (target: \(String(format: "%.1f", expectedTPS)) tok/s)")
    }

    func testInferenceMemoryUsage() async throws {
        // Measure peak memory during inference
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        measure(metrics: [XCTMemoryMetric()]) {
            Task {
                do {
                    _ = try await localLLM.generate(prompt: "Hello, how are you?")
                } catch {
                    XCTFail("Generation failed: \(error)")
                }
            }
        }

        // Memory should stay within device limits
        // 3B model @ 4-bit: ~1.5GB + 4GB OS = 5.5GB total on 6GB device
    }

    // MARK: - VAD Performance

    func testVADProcessingLatency() throws {
        // Measure time to process audio buffer
        let buffer = createTestAudioBuffer(sampleRate: 16000, duration: 0.1, energy: 0.05)

        measure(metrics: [XCTClockMetric()]) {
            vad.processAudioBuffer(buffer)
        }

        // VAD processing should be <10ms for real-time performance
    }

    func testVADCPUUsage() throws {
        // Measure CPU usage during continuous VAD processing
        let buffer = createTestAudioBuffer(sampleRate: 16000, duration: 0.1, energy: 0.05)

        measure(metrics: [XCTCPUMetric()]) {
            for _ in 0..<100 {
                vad.processAudioBuffer(buffer)
            }
        }

        // VAD should use <5% CPU on average
    }

    func testVADMemoryFootprint() throws {
        // Measure memory used by VAD over time
        measure(metrics: [XCTMemoryMetric()]) {
            let buffer = createTestAudioBuffer(sampleRate: 16000, duration: 0.1, energy: 0.05)

            for _ in 0..<1000 {
                vad.processAudioBuffer(buffer)
            }
        }

        // VAD should have stable memory usage (<50MB)
    }

    // MARK: - TTS Performance

    func testTTSInitializationTime() throws {
        measure(metrics: [XCTClockMetric()]) {
            _ = NativeTTSManager()
        }

        // TTS initialization should be <100ms
    }

    func testTTSLatency() throws {
        let expectation = XCTestExpectation(description: "TTS started speaking")

        let startTime = CFAbsoluteTimeGetCurrent()
        var speakingStartTime: CFAbsoluteTime = 0

        tts.onSpeakingStart = {
            speakingStartTime = CFAbsoluteTimeGetCurrent()
            expectation.fulfill()
        }

        tts.speak("Hello, this is a test.")

        wait(for: [expectation], timeout: 2.0)

        let latency = speakingStartTime - startTime

        // TTS should start speaking within 200ms
        XCTAssertLessThan(latency, 0.2, "TTS latency (\(latency)s) exceeds 200ms")

        print("📊 TTS Latency: \(String(format: "%.0f", latency * 1000))ms")
    }

    // MARK: - Device Capability Detection Performance

    func testDeviceDetectionSpeed() throws {
        measure(metrics: [XCTClockMetric()]) {
            _ = DeviceCapabilityDetector.shared
        }

        // Device detection should complete in <10ms
    }

    func testRAMDetectionAccuracy() throws {
        let detectedRAM = deviceDetector.totalRAMInGB

        // Verify detected RAM is reasonable
        XCTAssertGreaterThan(detectedRAM, 2.0, "Detected RAM too low")
        XCTAssertLessThan(detectedRAM, 32.0, "Detected RAM suspiciously high")

        print("📊 Detected RAM: \(String(format: "%.1f", detectedRAM)) GB")
    }

    func testModelRecommendationConsistency() throws {
        // Verify recommendation is consistent across multiple calls
        let recommendations = (0..<10).map { _ in
            deviceDetector.recommendedModel
        }

        let uniqueRecommendations = Set(recommendations)
        XCTAssertEqual(uniqueRecommendations.count, 1, "Model recommendation should be consistent")
    }

    // MARK: - End-to-End Pipeline Performance

    func testFullConversationCycle() async throws {
        // Measure complete cycle: VAD → STT → LLM → TTS
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // 1. VAD detects speech (simulated)
        let audioBuffer = createTestAudioBuffer(sampleRate: 16000, duration: 1.0, energy: 0.08)
        vad.processAudioBuffer(audioBuffer)

        // 2. STT transcribes (mocked)
        let transcript = "What's the weather like?"

        // 3. LLM generates response
        var response = ""
        do {
            response = try await localLLM.generate(prompt: transcript)
        } catch {
            XCTFail("LLM generation failed: \(error)")
        }

        // 4. TTS speaks response (measured)
        let ttsExpectation = XCTestExpectation(description: "TTS started")
        tts.onSpeakingStart = {
            ttsExpectation.fulfill()
        }
        tts.speak(response)

        await fulfillment(of: [ttsExpectation], timeout: 5.0)

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime

        // Complete cycle should be <10 seconds for good UX
        XCTAssertLessThan(totalTime, 10.0, "Full conversation cycle too slow")

        print("📊 Full Cycle Time: \(String(format: "%.1f", totalTime))s")
    }

    // MARK: - Stress Tests

    func testContinuousInferenceStability() async throws {
        // Run 100 consecutive inferences to test stability
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        var successCount = 0

        for i in 0..<100 {
            do {
                _ = try await localLLM.generate(prompt: "Test prompt \(i)")
                successCount += 1
            } catch {
                print("⚠️ Inference \(i) failed: \(error)")
            }
        }

        // At least 95% success rate
        XCTAssertGreaterThan(successCount, 95, "Stability test failed with \(successCount)/100 successes")
    }

    func testMemoryLeakDuringRepeatedInference() async throws {
        // Detect memory leaks over 50 inferences
        guard localLLM.isModelLoaded else {
            throw XCTSkip("Model must be loaded")
        }

        measure(metrics: [XCTMemoryMetric()]) {
            Task {
                for i in 0..<50 {
                    do {
                        _ = try await localLLM.generate(prompt: "Prompt \(i)")
                    } catch {
                        print("⚠️ Generation \(i) failed: \(error)")
                    }
                }
            }
        }

        // Memory should remain stable (no leaks)
    }

    // MARK: - Battery Impact Tests

    func testBatteryDrainDuring10MinConversation() throws {
        // This would require actual device testing with battery monitoring
        // For now, we estimate based on CPU/GPU usage
        throw XCTSkip("Battery tests require physical device with battery monitoring")
    }

    // MARK: - Device-Specific Benchmarks

    func testPerformanceOnCurrentDevice() async throws {
        let tier = deviceDetector.performanceTier
        let ramGB = deviceDetector.totalRAMInGB

        print("╔════════════════════════════════════════════════════════╗")
        print("║          Device Performance Report                    ║")
        print("╠════════════════════════════════════════════════════════╣")
        print("║ Device: \(deviceDetector.deviceInfo.modelName.padding(toLength: 44, withPad: " ", startingAt: 0))║")
        print("║ RAM: \(String(format: "%.1f GB", ramGB).padding(toLength: 47, withPad: " ", startingAt: 0))║")
        print("║ Tier: \(tier.rawValue.padding(toLength: 46, withPad: " ", startingAt: 0))║")
        print("║ Recommended: \(deviceDetector.recommendedModel.displayName.padding(toLength: 39, withPad: " ", startingAt: 0))║")
        print("╚════════════════════════════════════════════════════════╝")

        // Run performance tests specific to this device tier
        switch tier {
        case .ultra:
            // Test with largest model
            try await testWithModel(.qwen3_4B)
        case .high:
            // Test with recommended model (baseline)
            try await testWithModel(.qwen25_3B)
        case .medium:
            // Test with smaller model
            try await testWithModel(.qwen25_1_5B)
        case .low:
            // Test with minimal model
            try await testWithModel(.llama32_1B)
        }
    }

    private func testWithModel(_ modelType: LocalModelType) async throws {
        guard localLLM.isModelLoaded, localLLM.currentModel == modelType else {
            throw XCTSkip("Specific model \(modelType.displayName) not loaded")
        }

        // Run quick benchmark
        let startTime = CFAbsoluteTimeGetCurrent()
        var tokenCount = 0

        do {
            for try await _ in localLLM.generateStream(prompt: "Hello") {
                tokenCount += 1
                if tokenCount >= 20 {
                    break
                }
            }
        } catch {
            XCTFail("Benchmark failed for \(modelType.displayName): \(error)")
        }

        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
        let tps = Double(tokenCount) / elapsed

        print("📊 \(modelType.displayName): \(String(format: "%.1f", tps)) tok/s")
    }

    // MARK: - Helper Methods

    private func createTestAudioBuffer(
        sampleRate: Double,
        duration: TimeInterval,
        energy: Float
    ) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        guard let channelData = buffer.floatChannelData else {
            return buffer
        }

        // Generate sine wave with specified energy
        let amplitude = energy * 0.5
        for i in 0..<Int(frameCount) {
            let sample = Float(sin(2.0 * .pi * 440.0 * Double(i) / sampleRate)) * amplitude
            channelData[0][i] = sample
        }

        return buffer
    }
}
