//
//  PlatformUtility.swift
//  OS One
//
//  Cross-platform utilities for iOS and macOS support
//

import Foundation
import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Platform Detection
enum Platform {
    case iOS
    case macOS

    static var current: Platform {
        #if os(iOS)
        return .iOS
        #elseif os(macOS)
        return .macOS
        #endif
    }

    var displayName: String {
        switch self {
        case .iOS:
            return "iOS"
        case .macOS:
            return "macOS"
        }
    }
}

// MARK: - Device Info (Cross-Platform)
struct DeviceInfo {
    let platform: Platform
    let modelName: String
    let systemVersion: String
    let totalRAM: UInt64
    let totalRAMInGB: Double
    let processorName: String

    static func detect() -> DeviceInfo {
        let totalRAM = getTotalRAM()
        let totalRAMInGB = Double(totalRAM) / 1_073_741_824.0

        #if os(iOS)
        return DeviceInfo(
            platform: .iOS,
            modelName: getIOSDeviceName(),
            systemVersion: UIDevice.current.systemVersion,
            totalRAM: totalRAM,
            totalRAMInGB: totalRAMInGB,
            processorName: getProcessorName()
        )
        #elseif os(macOS)
        return DeviceInfo(
            platform: .macOS,
            modelName: getMacModel(),
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            totalRAM: totalRAM,
            totalRAMInGB: totalRAMInGB,
            processorName: getProcessorName()
        )
        #endif
    }

    // MARK: - RAM Detection
    private static func getTotalRAM() -> UInt64 {
        var size: UInt64 = 0
        var sizeOfSize = MemoryLayout<UInt64>.size

        let result = sysctlbyname("hw.memsize", &size, &sizeOfSize, nil, 0)

        if result == 0 {
            return size
        }

        return 8 * 1_073_741_824  // Default 8GB
    }

    // MARK: - iOS Device Name
    #if os(iOS)
    private static func getIOSDeviceName() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }

        return identifier
    }
    #endif

    // MARK: - macOS Model Name
    #if os(macOS)
    private static func getMacModel() -> String {
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)

        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &machine, &size, nil, 0)

        let model = String(cString: machine)

        // Map to friendly names
        if model.contains("MacBookPro") {
            return "MacBook Pro"
        } else if model.contains("MacBookAir") {
            return "MacBook Air"
        } else if model.contains("iMac") {
            return "iMac"
        } else if model.contains("Macmini") {
            return "Mac mini"
        } else if model.contains("MacPro") {
            return "Mac Pro"
        } else if model.contains("MacStudio") {
            return "Mac Studio"
        }

        return model
    }
    #endif

    // MARK: - Processor Name
    private static func getProcessorName() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)

        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)

        let processor = String(cString: machine)

        // Simplify Apple Silicon names
        if processor.contains("Apple M1") {
            return "Apple M1"
        } else if processor.contains("Apple M2") {
            return "Apple M2"
        } else if processor.contains("Apple M3") {
            return "Apple M3"
        } else if processor.contains("Apple M4") {
            return "Apple M4"
        }

        return processor
    }
}

// MARK: - Platform-Specific UI
#if os(iOS)
typealias PlatformColor = UIColor
typealias PlatformFont = UIFont
typealias PlatformImage = UIImage
#elseif os(macOS)
typealias PlatformColor = NSColor
typealias PlatformFont = NSFont
typealias PlatformImage = NSImage
#endif

// MARK: - Keyboard Shortcuts (macOS)
#if os(macOS)
struct KeyboardShortcut {
    let key: String
    let modifiers: EventModifiers
    let action: () -> Void

    static let recordVoice = KeyboardShortcut(
        key: "r",
        modifiers: .command,
        action: {}
    )

    static let newConversation = KeyboardShortcut(
        key: "n",
        modifiers: .command,
        action: {}
    )

    static let settings = KeyboardShortcut(
        key: ",",
        modifiers: .command,
        action: {}
    )

    static let toggleMute = KeyboardShortcut(
        key: "m",
        modifiers: [.command, .shift],
        action: {}
    )
}
#endif

// MARK: - Platform Capabilities
extension Platform {
    var supportsVoiceInput: Bool {
        return true  // Both iOS and macOS support microphone
    }

    var supportsKeyboardShortcuts: Bool {
        switch self {
        case .iOS:
            return false  // iPad can support keyboard shortcuts, but primarily touch
        case .macOS:
            return true
        }
    }

    var recommendedWindowSize: CGSize {
        switch self {
        case .iOS:
            return .zero  // iOS handles this automatically
        case .macOS:
            return CGSize(width: 800, height: 600)
        }
    }

    var supportsMenuBar: Bool {
        switch self {
        case .iOS:
            return false
        case .macOS:
            return true
        }
    }
}

// MARK: - Model Recommendations (Platform-Aware)
extension Platform {
    func recommendModel(ramGB: Double) -> LocalModelType {
        switch self {
        case .iOS:
            // iPhone/iPad recommendations
            if ramGB >= 8.0 {
                return .qwen3_4B
            } else if ramGB >= 6.0 {
                return .qwen3_4B  // iPhone 12 Pro Max baseline
            } else if ramGB >= 4.0 {
                return .qwen25_1_5B
            } else {
                return .llama32_1B
            }

        case .macOS:
            // Mac recommendations (more generous)
            if ramGB >= 16.0 {
                return .qwen3_4B  // Can handle larger models easily
            } else if ramGB >= 8.0 {
                return .qwen3_4B  // Still good for 8GB Macs
            } else {
                return .qwen25_3B
            }
        }
    }

    var maxRecommendedModelSize: LocalModelType {
        switch self {
        case .iOS:
            return .qwen3_4B  // 4B is max for mobile
        case .macOS:
            return .qwen3_4B  // Could support larger in future (7B+)
        }
    }
}
