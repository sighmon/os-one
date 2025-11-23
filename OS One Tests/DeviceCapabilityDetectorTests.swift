//
//  DeviceCapabilityDetectorTests.swift
//  OS One Tests
//
//  Unit tests for DeviceCapabilityDetector
//  Tests device detection and model recommendation
//

import XCTest
@testable import OS_One

final class DeviceCapabilityDetectorTests: XCTestCase {

    var sut: DeviceCapabilityDetector!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = DeviceCapabilityDetector.shared
    }

    // MARK: - Singleton Tests

    func testSingletonInstance() {
        let instance1 = DeviceCapabilityDetector.shared
        let instance2 = DeviceCapabilityDetector.shared

        XCTAssertTrue(instance1 === instance2, "Should return same instance")
    }

    // MARK: - Device Info Tests

    func testDeviceInfoProperties() {
        let deviceInfo = sut.deviceInfo

        XCTAssertFalse(deviceInfo.modelName.isEmpty, "Model name should not be empty")
        XCTAssertFalse(deviceInfo.systemVersion.isEmpty, "System version should not be empty")
        XCTAssertGreaterThan(deviceInfo.totalRAM, 0, "Total RAM should be greater than 0")
        XCTAssertGreaterThan(deviceInfo.totalRAMInGB, 0.0, "RAM in GB should be greater than 0")
        XCTAssertFalse(deviceInfo.cpuType.isEmpty, "CPU type should not be empty")
    }

    func testTotalRAMInGB() {
        let ramGB = sut.totalRAMInGB

        // Should be reasonable value for iOS device
        XCTAssertGreaterThanOrEqual(ramGB, 2.0, "iOS devices have at least 2GB RAM")
        XCTAssertLessThanOrEqual(ramGB, 32.0, "iOS devices have at most 32GB RAM")
    }

    // MARK: - Performance Tier Tests

    func testPerformanceTierValues() {
        let tier = sut.performanceTier

        let validTiers: [DeviceCapabilityDetector.PerformanceTier] = [
            .ultra, .high, .medium, .low
        ]

        XCTAssertTrue(validTiers.contains(tier), "Tier should be one of the valid values")
    }

    func testPerformanceTierDescriptions() {
        XCTAssertFalse(DeviceCapabilityDetector.PerformanceTier.ultra.description.isEmpty)
        XCTAssertFalse(DeviceCapabilityDetector.PerformanceTier.high.description.isEmpty)
        XCTAssertFalse(DeviceCapabilityDetector.PerformanceTier.medium.description.isEmpty)
        XCTAssertFalse(DeviceCapabilityDetector.PerformanceTier.low.description.isEmpty)
    }

    // MARK: - Model Recommendation Tests

    func testRecommendedModel() {
        let model = sut.recommendedModel

        let validModels = LocalModelType.allCases
        XCTAssertTrue(validModels.contains(model), "Recommended model should be valid")
    }

    func testRecommendationBasedOnRAM() {
        let ramGB = sut.totalRAMInGB
        let model = sut.recommendedModel

        if ramGB >= 8.0 {
            // Should recommend Qwen 3 4B for high-end devices
            XCTAssertTrue([.qwen3_4B].contains(model))
        } else if ramGB >= 6.0 {
            // Should recommend Qwen 2.5 3B for iPhone 12 Pro Max baseline
            XCTAssertTrue([.qwen25_3B, .qwen3_4B].contains(model))
        } else if ramGB >= 4.0 {
            // Should recommend smaller models
            XCTAssertTrue([.qwen25_1_5B, .gemma2_2B].contains(model))
        }
    }

    func testGetRecommendationText() {
        let text = sut.getRecommendationText()

        XCTAssertFalse(text.isEmpty, "Recommendation text should not be empty")
        XCTAssertTrue(text.contains("Detected:"), "Should contain device info")
        XCTAssertTrue(text.contains("Recommended Model:"), "Should contain model recommendation")
        XCTAssertTrue(text.contains("Performance Tier:"), "Should contain tier info")
    }

    // MARK: - Model Compatibility Tests

    func testCanRunModel() {
        // Test with smallest model (should always work)
        let (canRunSmall, reasonSmall) = sut.canRunModel(.llama32_1B)
        XCTAssertTrue(canRunSmall, "Should be able to run smallest model")
        XCTAssertNil(reasonSmall, "Should not have reason if can run")

        // Test with largest model
        let (canRunLarge, reasonLarge) = sut.canRunModel(.qwen3_4B)
        if !canRunLarge {
            XCTAssertNotNil(reasonLarge, "Should have reason if cannot run")
        }
    }

    func testCannotRunModelWithInsufficientRAM() {
        // If device has less than 7GB RAM, cannot run Qwen 3 4B
        if sut.totalRAMInGB < 7.0 {
            let (canRun, reason) = sut.canRunModel(.qwen3_4B)
            XCTAssertFalse(canRun, "Should not be able to run 4B model with insufficient RAM")
            XCTAssertNotNil(reason, "Should provide reason")
            XCTAssertTrue(reason!.contains("requires at least"), "Reason should mention RAM requirement")
        }
    }

    // MARK: - Performance Estimation Tests

    func testEstimatePerformance() {
        let estimate = sut.estimatePerformance(for: .qwen25_3B)

        XCTAssertGreaterThan(estimate.tokensPerSecond, 0.0, "Tokens/sec should be positive")
        XCTAssertGreaterThan(estimate.firstTokenLatency, 0.0, "Latency should be positive")
        XCTAssertGreaterThan(estimate.estimatedResponseTime, 0.0, "Response time should be positive")

        // Sanity checks
        XCTAssertLessThan(estimate.tokensPerSecond, 100.0, "Tokens/sec should be reasonable")
        XCTAssertLessThan(estimate.firstTokenLatency, 5.0, "Latency should be reasonable")
    }

    func testPerformanceEstimateByTier() {
        let qwen3Estimate = sut.estimatePerformance(for: .qwen3_4B)
        let qwen15Estimate = sut.estimatePerformance(for: .qwen25_1_5B)

        // Smaller models should be faster
        XCTAssertGreaterThan(qwen15Estimate.tokensPerSecond, qwen3Estimate.tokensPerSecond)
        XCTAssertLessThan(qwen15Estimate.firstTokenLatency, qwen3Estimate.firstTokenLatency)
    }

    // MARK: - Model Extension Tests

    func testModelParameterCounts() {
        XCTAssertEqual(LocalModelType.qwen3_4B.parameterCount, 4_000_000_000)
        XCTAssertEqual(LocalModelType.qwen25_3B.parameterCount, 3_000_000_000)
        XCTAssertEqual(LocalModelType.qwen25_1_5B.parameterCount, 1_500_000_000)
        XCTAssertEqual(LocalModelType.llama32_1B.parameterCount, 1_000_000_000)
    }

    func testModelRAMRequirements() {
        XCTAssertEqual(LocalModelType.qwen3_4B.requiredRAMInGB, 7.0)
        XCTAssertEqual(LocalModelType.qwen25_3B.requiredRAMInGB, 5.5)
        XCTAssertEqual(LocalModelType.qwen25_1_5B.requiredRAMInGB, 4.5)
        XCTAssertEqual(LocalModelType.llama32_1B.requiredRAMInGB, 3.5)
    }

    func testModelTargetLatency() {
        XCTAssertEqual(LocalModelType.qwen3_4B.targetLatency, 0.30)
        XCTAssertEqual(LocalModelType.qwen25_3B.targetLatency, 0.25)
        XCTAssertEqual(LocalModelType.qwen25_1_5B.targetLatency, 0.20)
    }

    // MARK: - Edge Cases

    func testMultipleCallsToShared() {
        // Should not crash or reinitialize
        for _ in 0..<100 {
            let instance = DeviceCapabilityDetector.shared
            XCTAssertNotNil(instance.deviceInfo)
        }
    }

    func testDeviceInfoConsistency() {
        let info1 = sut.deviceInfo
        Thread.sleep(forTimeInterval: 0.1)
        let info2 = sut.deviceInfo

        // Device info should be consistent
        XCTAssertEqual(info1.totalRAM, info2.totalRAM)
        XCTAssertEqual(info1.modelName, info2.modelName)
        XCTAssertEqual(info1.systemVersion, info2.systemVersion)
    }
}

// MARK: - Performance Tier Tests

final class PerformanceTierTests: XCTestCase {

    func testAllPerformanceTiers() {
        let tiers: [DeviceCapabilityDetector.PerformanceTier] = [
            .ultra, .high, .medium, .low
        ]

        for tier in tiers {
            XCTAssertFalse(tier.description.isEmpty, "\(tier) should have description")
            XCTAssertFalse(tier.rawValue.isEmpty, "\(tier) should have raw value")
        }
    }

    func testTierRawValues() {
        XCTAssertEqual(DeviceCapabilityDetector.PerformanceTier.ultra.rawValue, "ultra")
        XCTAssertEqual(DeviceCapabilityDetector.PerformanceTier.high.rawValue, "high")
        XCTAssertEqual(DeviceCapabilityDetector.PerformanceTier.medium.rawValue, "medium")
        XCTAssertEqual(DeviceCapabilityDetector.PerformanceTier.low.rawValue, "low")
    }
}

// MARK: - Performance Estimate Tests

final class PerformanceEstimateTests: XCTestCase {

    func testPerformanceEstimateCreation() {
        let estimate = DeviceCapabilityDetector.PerformanceEstimate(
            tokensPerSecond: 20.0,
            firstTokenLatency: 0.3,
            estimatedResponseTime: 2.5
        )

        XCTAssertEqual(estimate.tokensPerSecond, 20.0)
        XCTAssertEqual(estimate.firstTokenLatency, 0.3)
        XCTAssertEqual(estimate.estimatedResponseTime, 2.5)
    }
}
