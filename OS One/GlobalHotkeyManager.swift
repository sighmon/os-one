//
//  GlobalHotkeyManager.swift
//  OS One
//
//  Global hotkey monitoring for macOS dictation
//  Similar to Whisper Flow / Super Whisper functionality
//

#if os(macOS)

import Foundation
import Cocoa
import Carbon
import ApplicationServices

/// Manages global hotkeys for system-wide dictation
/// Monitors Fn key presses to trigger recording and text insertion
@MainActor
class GlobalHotkeyManager: ObservableObject {

    // MARK: - Published Properties
    @Published var isEnabled: Bool = false
    @Published var isRecording: Bool = false
    @Published var lastError: String?
    @Published var selectedHotkey: HotkeyType = .leftFn

    // MARK: - Hotkey Configuration
    enum HotkeyType: String, CaseIterable {
        case leftFn = "left_fn"
        case rightFn = "right_fn"
        case doubleFn = "double_fn"
        case customCombo = "custom"

        var displayName: String {
            switch self {
            case .leftFn:
                return "Left Fn Key"
            case .rightFn:
                return "Right Fn Key"
            case .doubleFn:
                return "Double Fn Tap"
            case .customCombo:
                return "Custom Shortcut"
            }
        }

        var description: String {
            switch self {
            case .leftFn:
                return "Press and hold left Fn to record"
            case .rightFn:
                return "Press and hold right Fn to record"
            case .doubleFn:
                return "Double-tap Fn to start/stop recording"
            case .customCombo:
                return "Define custom keyboard shortcut"
            }
        }
    }

    // MARK: - Private Properties
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnKeyDownTime: Date?
    private var doubleTapTimer: Timer?
    private let doubleTapThreshold: TimeInterval = 0.3  // 300ms for double tap

    // Callbacks
    var onRecordingStart: (() -> Void)?
    var onRecordingStop: ((String) -> Void)?  // Called with transcribed text

    // MARK: - Initialization
    override init() {
        super.init()
        loadSettings()
    }

    deinit {
        stop()
    }

    // MARK: - Settings Management
    private func loadSettings() {
        isEnabled = UserDefaults.standard.bool(forKey: "globalHotkeyEnabled")

        if let hotkeyString = UserDefaults.standard.string(forKey: "selectedHotkey"),
           let hotkey = HotkeyType(rawValue: hotkeyString) {
            selectedHotkey = hotkey
        }
    }

    func saveSettings() {
        UserDefaults.standard.set(isEnabled, forKey: "globalHotkeyEnabled")
        UserDefaults.standard.set(selectedHotkey.rawValue, forKey: "selectedHotkey")
    }

    // MARK: - Accessibility Permissions

    /// Check if app has accessibility permissions
    func hasAccessibilityPermissions() -> Bool {
        return AXIsProcessTrusted()
    }

    /// Request accessibility permissions
    func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Global Event Monitoring

    /// Start monitoring global keyboard events
    func start() {
        guard !isEnabled else { return }

        // Check permissions first
        guard hasAccessibilityPermissions() else {
            lastError = "Accessibility permissions required. Click 'Grant Permissions' in Settings."
            requestAccessibilityPermissions()
            return
        }

        // Create event tap
        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { proxy, type, event, refcon in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }

                let manager = Unmanaged<GlobalHotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

                Task { @MainActor in
                    manager.handleEvent(type: type, event: event)
                }

                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            lastError = "Failed to create event tap"
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        guard let runLoopSource = runLoopSource else {
            lastError = "Failed to create run loop source"
            return
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        isEnabled = true
        saveSettings()

        print("GlobalHotkeyManager: Started monitoring for \(selectedHotkey.displayName)")
    }

    /// Stop monitoring global keyboard events
    func stop() {
        guard isEnabled else { return }

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
        }

        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
        isEnabled = false
        saveSettings()

        print("GlobalHotkeyManager: Stopped monitoring")
    }

    // MARK: - Event Handling

    private func handleEvent(type: CGEventType, event: CGEvent) {
        switch selectedHotkey {
        case .leftFn, .rightFn:
            handleHoldToRecord(type: type, event: event)
        case .doubleFn:
            handleDoubleTap(type: type, event: event)
        case .customCombo:
            handleCustomCombo(type: type, event: event)
        }
    }

    private func handleHoldToRecord(type: CGEventType, event: CGEvent) {
        // Monitor Fn key (keyCode 63 for Fn on macOS)
        if type == .flagsChanged {
            let flags = event.flags

            // Check if Fn is pressed
            if flags.contains(.secondaryFn) {
                // Fn key is down
                if !isRecording {
                    fnKeyDownTime = Date()
                    startRecording()
                }
            } else {
                // Fn key is up
                if isRecording {
                    stopRecording()
                }
                fnKeyDownTime = nil
            }
        }
    }

    private func handleDoubleTap(type: CGEventType, event: CGEvent) {
        if type == .flagsChanged {
            let flags = event.flags

            if flags.contains(.secondaryFn) {
                // Fn pressed
                if let timer = doubleTapTimer, timer.isValid {
                    // Second tap detected - toggle recording
                    doubleTapTimer?.invalidate()
                    doubleTapTimer = nil

                    if isRecording {
                        stopRecording()
                    } else {
                        startRecording()
                    }
                } else {
                    // First tap - start timer
                    doubleTapTimer = Timer.scheduledTimer(withTimeInterval: doubleTapThreshold, repeats: false) { [weak self] _ in
                        self?.doubleTapTimer = nil
                    }
                }
            }
        }
    }

    private func handleCustomCombo(type: CGEventType, event: CGEvent) {
        // Placeholder for custom keyboard shortcuts
        // Could monitor combinations like Fn+Space, Fn+D, etc.
    }

    // MARK: - Recording Control

    private func startRecording() {
        guard !isRecording else { return }

        isRecording = true
        onRecordingStart?()

        // Visual feedback
        showRecordingIndicator()

        print("GlobalHotkeyManager: Started recording")
    }

    private func stopRecording() {
        guard isRecording else { return }

        isRecording = false

        // Hide indicator
        hideRecordingIndicator()

        print("GlobalHotkeyManager: Stopped recording")

        // Trigger transcription callback
        // The actual transcription happens in the parent view/manager
        onRecordingStop?("")
    }

    // MARK: - Text Insertion

    /// Insert transcribed text at the current cursor position
    func insertTextAtCursor(_ text: String) {
        // Get the currently focused application
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            print("No frontmost application")
            return
        }

        // Simulate typing the text
        // Method 1: Using CGEvent (more reliable)
        insertTextViaCGEvents(text)

        // Method 2 (alternative): Use AppleScript
        // insertTextViaAppleScript(text)
    }

    private func insertTextViaCGEvents(_ text: String) {
        // Small delay to ensure the app is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Create and post key events for each character
            for char in text {
                if let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
                    let nsString = NSString(string: String(char))
                    event.keyboardSetUnicodeString(stringLength: nsString.length, unicodeString: nsString.utf16)
                    event.post(tap: .cghidEventTap)

                    // Small delay between characters
                    Thread.sleep(forTimeInterval: 0.001)
                }
            }
        }
    }

    private func insertTextViaAppleScript(_ text: String) {
        let escapedText = text.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "System Events"
            keystroke "\(escapedText)"
        end tell
        """

        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: script) {
            scriptObject.executeAndReturnError(&error)

            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }

    // MARK: - Visual Feedback

    private var recordingWindow: NSWindow?

    private func showRecordingIndicator() {
        // Create a small floating window showing recording status
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.ignoresMouseEvents = true

        // Position in top-right corner
        if let screen = NSScreen.main {
            let x = screen.frame.width - 220
            let y = screen.frame.height - 80
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        // Create content view with recording indicator
        let contentView = NSView(frame: window.contentRect(forFrameRect: window.frame))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.9).cgColor
        contentView.layer?.cornerRadius = 8

        let label = NSTextField(labelWithString: "🎤 Recording...")
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.alignment = .center
        label.frame = contentView.bounds
        contentView.addSubview(label)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)

        recordingWindow = window
    }

    private func hideRecordingIndicator() {
        recordingWindow?.close()
        recordingWindow = nil
    }
}

#endif
