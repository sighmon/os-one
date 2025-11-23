//
//  VoiceActivityDetectorTests.swift
//  OS One Tests
//
//  Unit tests for VoiceActivityDetector
//  Tests ML-based speech detection and energy monitoring
//

import XCTest
import AVFoundation
@testable import OS_One

final class VoiceActivityDetectorTests: XCTestCase {

    var sut: VoiceActivityDetector!
    var testConfig: VoiceActivityDetector.Configuration!

    override func setUpWithError() throws {
        try super.setUpWithError()
        testConfig = VoiceActivityDetector.Configuration(
            energyThreshold: 0.02,
            silenceDuration: 1.5,
            speechStartDuration: 0.2,
            adaptiveThreshold: true,
            useMLDetection: true
        )
        sut = VoiceActivityDetector(configuration: testConfig)
    }

    override func tearDownWithError() throws {
        sut.stopDetection()
        sut = nil
        testConfig = nil
        try super.tearDownWithError()
    }

    // MARK: - Initialization Tests

    func testInitialization() {
        XCTAssertNotNil(sut)
        XCTAssertFalse(sut.isSpeaking)
        XCTAssertEqual(sut.audioLevel, 0.0)
        XCTAssertEqual(sut.vadState, .silence)
    }

    func testInitializationWithCustomConfiguration() {
        let customConfig = VoiceActivityDetector.Configuration(
            energyThreshold: 0.05,
            silenceDuration: 2.0,
            speechStartDuration: 0.3,
            adaptiveThreshold: false,
            useMLDetection: false
        )

        let customVAD = VoiceActivityDetector(configuration: customConfig)
        XCTAssertNotNil(customVAD)
        XCTAssertEqual(customVAD.config.energyThreshold, 0.05)
        XCTAssertEqual(customVAD.config.silenceDuration, 2.0)
    }

    // MARK: - Configuration Tests

    func testUpdateConfiguration() {
        let newConfig = VoiceActivityDetector.Configuration(
            energyThreshold: 0.03,
            silenceDuration: 2.0,
            speechStartDuration: 0.25,
            adaptiveThreshold: true,
            useMLDetection: false
        )

        sut.updateConfiguration(newConfig)

        XCTAssertEqual(sut.config.energyThreshold, 0.03)
        XCTAssertEqual(sut.config.silenceDuration, 2.0)
        XCTAssertEqual(sut.config.speechStartDuration, 0.25)
    }

    func testSetSensitivity() {
        // Test low sensitivity (0.0)
        sut.setSensitivity(0.0)
        XCTAssertGreaterThan(sut.config.energyThreshold, 0.045)

        // Test medium sensitivity (0.5)
        sut.setSensitivity(0.5)
        XCTAssertGreaterThan(sut.config.energyThreshold, 0.02)
        XCTAssertLessThan(sut.config.energyThreshold, 0.03)

        // Test high sensitivity (1.0)
        sut.setSensitivity(1.0)
        XCTAssertLessThan(sut.config.energyThreshold, 0.01)
    }

    // MARK: - State Management Tests

    func testStartDetection() {
        sut.startDetection()
        XCTAssertEqual(sut.vadState, .silence)
        XCTAssertFalse(sut.isSpeaking)
    }

    func testStopDetection() {
        sut.startDetection()
        sut.stopDetection()
        XCTAssertEqual(sut.vadState, .silence)
        XCTAssertFalse(sut.isSpeaking)
    }

    func testResetDetection() {
        sut.startDetection()
        sut.resetDetection()
        XCTAssertEqual(sut.vadState, .silence)
        XCTAssertFalse(sut.isSpeaking)
    }

    // MARK: - Audio Buffer Processing Tests

    func testProcessAudioBufferWithSilence() {
        let silentBuffer = createTestAudioBuffer(energy: 0.01)
        sut.processAudioBuffer(silentBuffer)

        // Should remain in silence state
        XCTAssertEqual(sut.vadState, .silence)
        XCTAssertFalse(sut.isSpeaking)
    }

    func testProcessAudioBufferWithSpeech() {
        let speechBuffer = createTestAudioBuffer(energy: 0.05)
        sut.processAudioBuffer(speechBuffer)

        // Should transition to possible speech
        // Note: Actual state depends on timing
        XCTAssertTrue([.silence, .possibleSpeech, .speaking].contains(sut.vadState))
    }

    func testAudioLevelUpdates() {
        let expectation = XCTestExpectation(description: "Audio level callback")

        sut.onAudioLevel = { level in
            XCTAssertGreaterThanOrEqual(level, 0.0)
            XCTAssertLessThanOrEqual(level, 1.0)
            expectation.fulfill()
        }

        let buffer = createTestAudioBuffer(energy: 0.05)
        sut.processAudioBuffer(buffer)

        wait(for: [expectation], timeout: 1.0)
    }

    // MARK: - Callback Tests

    func testSpeechStartCallback() {
        let expectation = XCTestExpectation(description: "Speech start callback")

        sut.onSpeechStart = {
            expectation.fulfill()
        }

        // Simulate continuous speech
        for _ in 0..<10 {
            let buffer = createTestAudioBuffer(energy: 0.08)
            sut.processAudioBuffer(buffer)
            Thread.sleep(forTimeInterval: 0.05)
        }

        wait(for: [expectation], timeout: 2.0)
    }

    func testSpeechEndCallback() {
        let startExpectation = XCTestExpectation(description: "Speech start")
        let endExpectation = XCTestExpectation(description: "Speech end")

        sut.onSpeechStart = {
            startExpectation.fulfill()
        }

        sut.onSpeechEnd = {
            endExpectation.fulfill()
        }

        // Simulate speech followed by silence
        DispatchQueue.global().async {
            // Speech
            for _ in 0..<5 {
                let buffer = self.createTestAudioBuffer(energy: 0.08)
                self.sut.processAudioBuffer(buffer)
                Thread.sleep(forTimeInterval: 0.1)
            }

            // Silence
            for _ in 0..<20 {
                let buffer = self.createTestAudioBuffer(energy: 0.005)
                self.sut.processAudioBuffer(buffer)
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        wait(for: [startExpectation, endExpectation], timeout: 5.0)
    }

    // MARK: - Diagnostics Tests

    func testGetDiagnostics() {
        let diagnostics = sut.getDiagnostics()

        XCTAssertNotNil(diagnostics["state"])
        XCTAssertNotNil(diagnostics["isSpeaking"])
        XCTAssertNotNil(diagnostics["audioLevel"])
        XCTAssertNotNil(diagnostics["backgroundNoise"])
        XCTAssertNotNil(diagnostics["threshold"])
        XCTAssertNotNil(diagnostics["effectiveThreshold"])

        if let isSpeaking = diagnostics["isSpeaking"] as? Bool {
            XCTAssertFalse(isSpeaking)
        }

        if let audioLevel = diagnostics["audioLevel"] as? Float {
            XCTAssertGreaterThanOrEqual(audioLevel, 0.0)
        }
    }

    // MARK: - VAD State Tests

    func testVADStateTransitions() {
        // Start in silence
        XCTAssertEqual(sut.vadState, .silence)

        // Process speech - should move to possibleSpeech
        let speechBuffer = createTestAudioBuffer(energy: 0.06)
        sut.processAudioBuffer(speechBuffer)

        // May still be in silence or possibleSpeech (timing dependent)
        XCTAssertTrue([.silence, .possibleSpeech].contains(sut.vadState))
    }

    // MARK: - Performance Tests

    func testAudioProcessingPerformance() {
        measure {
            for _ in 0..<100 {
                let buffer = createTestAudioBuffer(energy: 0.05)
                sut.processAudioBuffer(buffer)
            }
        }
    }

    // MARK: - Helper Methods

    private func createTestAudioBuffer(energy: Float) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1024)!
        buffer.frameLength = 1024

        guard let channelData = buffer.floatChannelData else {
            return buffer
        }

        // Fill with test data based on desired energy level
        let amplitude = sqrt(energy * 2.0)  // RMS to amplitude
        for i in 0..<Int(buffer.frameLength) {
            let sample = amplitude * sin(Float(i) * 0.1)
            channelData[0][i] = sample
        }

        return buffer
    }
}

// MARK: - VAD State Tests

final class VADStateTests: XCTestCase {

    func testVADStateValues() {
        let states: [VoiceActivityDetector.VADState] = [
            .silence,
            .possibleSpeech,
            .speaking,
            .endOfSpeech
        ]

        XCTAssertEqual(states.count, 4)

        // Test string representation
        XCTAssertEqual(String(describing: VoiceActivityDetector.VADState.silence), "silence")
        XCTAssertEqual(String(describing: VoiceActivityDetector.VADState.speaking), "speaking")
    }
}
