//
//  DeviceCapabilityDetector.swift
//  OS One
//
//  Device capability detection for model recommendation
//  Optimized for iPhone 12 Pro Max (6GB RAM) baseline
//

import Foundation
import UIKit
import os.log

// MARK: - Device Capability Detector
class DeviceCapabilityDetector {

    // MARK: - Singleton
    static let shared = DeviceCapabilityDetector()

    // MARK: - Device Information
    struct DeviceInfo {
        let modelName: String
        let systemVersion: String
        let totalRAM: UInt64  // Bytes
        let totalRAMInGB: Double
        let cpuType: String
        let gpuFamily: String
        let recommendedModel: LocalModelType
        let performanceTier: PerformanceTier
    }

    enum PerformanceTier: String {
        case ultra      // A17 Pro+, M2+, 8GB+ RAM
        case high       // A15-A16, M1, 6GB RAM
        case medium     // A13-A14, 4GB RAM
        case low        // A12 and below, <4GB RAM

        var description: String {
            switch self {
            case .ultra:
                return "Ultra Performance - Run largest models with best quality"
            case .high:
                return "High Performance - Recommended for most users"
            case .medium:
                return "Medium Performance - Optimized for battery life"
            case .low:
                return "Low Performance - Basic functionality only"
            }
        }
    }

    // MARK: - Properties
    private(set) var deviceInfo: DeviceInfo

    var totalRAMInGB: Double {
        deviceInfo.totalRAMInGB
    }

    var recommendedModel: LocalModelType {
        deviceInfo.recommendedModel
    }

    var performanceTier: PerformanceTier {
        deviceInfo.performanceTier
    }

    // MARK: - Initialization
    private init() {
        self.deviceInfo = DeviceCapabilityDetector.detectCapabilities()
        logDeviceInfo()
    }

    // MARK: - Device Detection
    private static func detectCapabilities() -> DeviceInfo {
        let modelName = getDeviceModel()
        let systemVersion = UIDevice.current.systemVersion
        let totalRAM = getTotalRAM()
        let totalRAMInGB = Double(totalRAM) / 1_073_741_824.0  // Convert to GB
        let cpuType = getCPUType()
        let gpuFamily = getGPUFamily()

        // Determine performance tier
        let performanceTier = determinePerformanceTier(
            modelName: modelName,
            ramGB: totalRAMInGB
        )

        // Recommend model based on capabilities
        let recommendedModel = recommendModel(
            ramGB: totalRAMInGB,
            tier: performanceTier
        )

        return DeviceInfo(
            modelName: modelName,
            systemVersion: systemVersion,
            totalRAM: totalRAM,
            totalRAMInGB: totalRAMInGB,
            cpuType: cpuType,
            gpuFamily: gpuFamily,
            recommendedModel: recommendedModel,
            performanceTier: performanceTier
        )
    }

    // MARK: - RAM Detection
    private static func getTotalRAM() -> UInt64 {
        var size: UInt64 = 0
        var sizeOfSize = MemoryLayout<UInt64>.size

        let result = sysctlbyname("hw.memsize", &size, &sizeOfSize, nil, 0)

        if result == 0 {
            return size
        }

        // Fallback: estimate based on device model
        return estimateRAMFromModel()
    }

    private static func estimateRAMFromModel() -> UInt64 {
        let model = getDeviceModel()

        // iPhone RAM estimates
        if model.contains("iPhone15") || model.contains("iPhone16") {
            return 8 * 1_073_741_824  // 8GB
        } else if model.contains("iPhone14") || model.contains("iPhone13Pro") {
            return 6 * 1_073_741_824  // 6GB
        } else if model.contains("iPhone13") || model.contains("iPhone12Pro") {
            return 6 * 1_073_741_824  // 6GB
        } else if model.contains("iPhone12") || model.contains("iPhone11Pro") {
            return 4 * 1_073_741_824  // 4GB
        }

        // iPad RAM estimates
        if model.contains("iPadPro") || model.contains("iPad Air") {
            return 8 * 1_073_741_824  // 8GB
        } else if model.contains("iPad") {
            return 4 * 1_073_741_824  // 4GB
        }

        // Mac estimates
        if model.contains("Mac") {
            return 16 * 1_073_741_824  // 16GB (conservative estimate)
        }

        // Default fallback
        return 4 * 1_073_741_824  // 4GB
    }

    // MARK: - Device Model Detection
    private static func getDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return mapToDeviceName(identifier: identifier)
    }

    private static func mapToDeviceName(identifier: String) -> String {
        // iPhone mappings
        switch identifier {
        // iPhone 15 series
        case "iPhone15,4": return "iPhone 15"
        case "iPhone15,5": return "iPhone 15 Plus"
        case "iPhone16,1": return "iPhone 15 Pro"
        case "iPhone16,2": return "iPhone 15 Pro Max"

        // iPhone 14 series
        case "iPhone14,7": return "iPhone 14"
        case "iPhone14,8": return "iPhone 14 Plus"
        case "iPhone15,2": return "iPhone 14 Pro"
        case "iPhone15,3": return "iPhone 14 Pro Max"

        // iPhone 13 series
        case "iPhone14,4": return "iPhone 13 mini"
        case "iPhone14,5": return "iPhone 13"
        case "iPhone14,2": return "iPhone 13 Pro"
        case "iPhone14,3": return "iPhone 13 Pro Max"

        // iPhone 12 series
        case "iPhone13,1": return "iPhone 12 mini"
        case "iPhone13,2": return "iPhone 12"
        case "iPhone13,3": return "iPhone 12 Pro"
        case "iPhone13,4": return "iPhone 12 Pro Max"  // Our baseline!

        // iPad Pro mappings
        case "iPad14,3", "iPad14,4": return "iPad Pro 11-inch (M2)"
        case "iPad14,5", "iPad14,6": return "iPad Pro 12.9-inch (M2)"

        // Mac mappings
        case let x where x.hasPrefix("Mac"):
            return "Mac (\(x))"

        // Simulator
        case "x86_64", "arm64":
            return "Simulator"

        default:
            return identifier
        }
    }

    // MARK: - CPU Detection
    private static func getCPUType() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        // Detect Apple Silicon generations
        if identifier.contains("iPhone16") {
            return "Apple A17 Pro"
        } else if identifier.contains("iPhone15") {
            return "Apple A16 Bionic"
        } else if identifier.contains("iPhone14") {
            return "Apple A15 Bionic"
        } else if identifier.contains("iPhone13") {
            return "Apple A14 Bionic"
        } else if identifier.contains("Mac14") || identifier.contains("Mac15") {
            return "Apple M2"
        } else if identifier.contains("Mac13") {
            return "Apple M1"
        }

        return "Unknown"
    }

    // MARK: - GPU Detection
    private static func getGPUFamily() -> String {
        // This is simplified - actual GPU detection requires Metal API
        #if targetEnvironment(simulator)
        return "Simulator GPU"
        #else
        return "Apple GPU (Family 5+)"
        #endif
    }

    // MARK: - Performance Tier Detection
    private static func determinePerformanceTier(
        modelName: String,
        ramGB: Double
    ) -> PerformanceTier {
        // Ultra: A17 Pro+, M2+, 8GB+ RAM
        if modelName.contains("A17") || modelName.contains("M2") || modelName.contains("M3") || modelName.contains("M4") {
            return .ultra
        }

        if ramGB >= 8.0 {
            return .ultra
        }

        // High: A15-A16, M1, 6GB RAM (iPhone 12 Pro Max baseline)
        if modelName.contains("A15") || modelName.contains("A16") || modelName.contains("M1") {
            return .high
        }

        if ramGB >= 6.0 {
            return .high
        }

        // Medium: A13-A14, 4GB RAM
        if modelName.contains("A13") || modelName.contains("A14") {
            return .medium
        }

        if ramGB >= 4.0 {
            return .medium
        }

        // Low: Everything else
        return .low
    }

    // MARK: - Model Recommendation
    private static func recommendModel(
        ramGB: Double,
        tier: PerformanceTier
    ) -> LocalModelType {
        switch tier {
        case .ultra:
            // 8GB+ RAM: Can handle Qwen3-4B at 4-bit with plenty of headroom
            return .qwen3_4B

        case .high:
            // 6GB RAM (iPhone 12 Pro Max baseline): Qwen3-4B at 4-bit!
            // 256K context window is the killer feature
            return .qwen3_4B

        case .medium:
            // 4GB RAM: Qwen2.5-1.5B at 4-bit
            return .qwen25_1_5B

        case .low:
            // <4GB RAM: Smallest model
            return .llama32_1B
        }
    }

    // MARK: - Recommendation Text
    func getRecommendationText() -> String {
        let device = deviceInfo.modelName
        let ram = String(format: "%.1f GB", deviceInfo.totalRAMInGB)
        let model = deviceInfo.recommendedModel.displayName

        return """
        Detected: \(device) with \(ram) RAM
        Performance Tier: \(deviceInfo.performanceTier.rawValue)
        Recommended Model: \(model)

        \(deviceInfo.performanceTier.description)
        """
    }

    // MARK: - Can Run Model Check
    func canRunModel(_ modelType: LocalModelType) -> (canRun: Bool, reason: String?) {
        let requiredRAM = modelType.requiredRAMInGB

        if deviceInfo.totalRAMInGB < requiredRAM {
            return (false, "This model requires at least \(String(format: "%.1f", requiredRAM)) GB RAM. Your device has \(String(format: "%.1f", deviceInfo.totalRAMInGB)) GB.")
        }

        // Check if model is too advanced for device
        if deviceInfo.performanceTier == .low && modelType.parameterCount >= 3_000_000_000 {
            return (false, "This model may be too resource-intensive for your device. Consider a smaller model for better performance.")
        }

        return (true, nil)
    }

    // MARK: - Performance Estimates
    func estimatePerformance(for modelType: LocalModelType) -> PerformanceEstimate {
        let baseSpeed: Double

        // Base tokens/sec by tier
        switch deviceInfo.performanceTier {
        case .ultra:
            baseSpeed = 35.0
        case .high:
            baseSpeed = 20.0
        case .medium:
            baseSpeed = 12.0
        case .low:
            baseSpeed = 6.0
        }

        // Adjust for model size
        let sizeMultiplier: Double
        if modelType.parameterCount >= 4_000_000_000 {
            sizeMultiplier = 0.6  // Larger models are slower
        } else if modelType.parameterCount >= 3_000_000_000 {
            sizeMultiplier = 0.75
        } else if modelType.parameterCount >= 1_500_000_000 {
            sizeMultiplier = 0.9
        } else {
            sizeMultiplier = 1.0
        }

        let tokensPerSecond = baseSpeed * sizeMultiplier
        let firstTokenLatency = 1.0 / (baseSpeed / 10.0)  // Rough estimate

        return PerformanceEstimate(
            tokensPerSecond: tokensPerSecond,
            firstTokenLatency: firstTokenLatency,
            estimatedResponseTime: 50.0 / tokensPerSecond  // 50 token response
        )
    }

    struct PerformanceEstimate {
        let tokensPerSecond: Double
        let firstTokenLatency: Double  // Seconds
        let estimatedResponseTime: Double  // Seconds for 50 tokens
    }

    // MARK: - Logging
    private func logDeviceInfo() {
        print("╔════════════════════════════════════════════════════════╗")
        print("║          Device Capability Detection Report           ║")
        print("╠════════════════════════════════════════════════════════╣")
        print("║ Device: \(deviceInfo.modelName.padding(toLength: 44, withPad: " ", startingAt: 0))║")
        print("║ iOS: \(deviceInfo.systemVersion.padding(toLength: 47, withPad: " ", startingAt: 0))║")
        print("║ CPU: \(deviceInfo.cpuType.padding(toLength: 47, withPad: " ", startingAt: 0))║")
        print("║ RAM: \(String(format: "%.2f GB", deviceInfo.totalRAMInGB).padding(toLength: 47, withPad: " ", startingAt: 0))║")
        print("║ Tier: \(deviceInfo.performanceTier.rawValue.padding(toLength: 46, withPad: " ", startingAt: 0))║")
        print("║ Recommended: \(deviceInfo.recommendedModel.displayName.padding(toLength: 39, withPad: " ", startingAt: 0))║")
        print("╚════════════════════════════════════════════════════════╝")
    }
}

// MARK: - LocalModelType Extension
extension LocalModelType {
    var parameterCount: Int {
        switch self {
        case .qwen3_4B:
            return 4_000_000_000
        case .qwen25_3B:
            return 3_000_000_000
        case .qwen25_1_5B:
            return 1_500_000_000
        case .gemma2_2B:
            return 2_000_000_000
        case .llama32_3B:
            return 3_000_000_000
        case .llama32_1B:
            return 1_000_000_000
        }
    }

    var requiredRAMInGB: Double {
        switch self {
        case .qwen3_4B:
            return 7.0  // 4B model @ 4-bit needs ~2GB + 4GB OS + 1GB buffer
        case .qwen25_3B, .llama32_3B:
            return 5.5  // 3B model @ 4-bit needs ~1.5GB + 4GB OS
        case .qwen25_1_5B, .gemma2_2B:
            return 4.5  // 1.5-2B model @ 4-bit needs ~1GB + 3.5GB OS
        case .llama32_1B:
            return 3.5  // 1B model @ 4-bit needs ~0.6GB + 3GB OS
        }
    }

    var targetLatency: Double {
        switch self {
        case .qwen3_4B:
            return 0.30  // <300ms first token
        case .qwen25_3B:
            return 0.25  // <250ms first token
        case .qwen25_1_5B:
            return 0.20  // <200ms first token
        case .gemma2_2B:
            return 0.22
        case .llama32_3B:
            return 0.28
        case .llama32_1B:
            return 0.18
        }
    }
}
