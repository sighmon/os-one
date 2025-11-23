//
//  MacOSSupport.swift
//  OS One
//
//  macOS-specific UI adaptations and features
//

import SwiftUI

#if os(macOS)
import AppKit

// MARK: - macOS Window Manager
class WindowManager: ObservableObject {
    @Published var windowSize: CGSize = CGSize(width: 800, height: 600)

    static let shared = WindowManager()

    func setWindowSize(_ size: CGSize) {
        if let window = NSApplication.shared.windows.first {
            window.setContentSize(size)
            windowSize = size
        }
    }

    func centerWindow() {
        if let window = NSApplication.shared.windows.first {
            window.center()
        }
    }

    func toggleFullScreen() {
        if let window = NSApplication.shared.windows.first {
            window.toggleFullScreen(nil)
        }
    }
}

// MARK: - Keyboard Shortcuts Handler
struct KeyboardShortcutsHandler: ViewModifier {
    @Binding var showingSettings: Bool
    @Binding var isRecording: Bool
    @Binding var mute: Bool

    var onNewConversation: () -> Void
    var onToggleRecording: () -> Void

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NewConversation"))) { _ in
                onNewConversation()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleRecording"))) { _ in
                onToggleRecording()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ToggleMute"))) { _ in
                mute.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowSettings"))) { _ in
                showingSettings = true
            }
    }
}

extension View {
    func macOSKeyboardShortcuts(
        showingSettings: Binding<Bool>,
        isRecording: Binding<Bool>,
        mute: Binding<Bool>,
        onNewConversation: @escaping () -> Void,
        onToggleRecording: @escaping () -> Void
    ) -> some View {
        modifier(KeyboardShortcutsHandler(
            showingSettings: showingSettings,
            isRecording: isRecording,
            mute: mute,
            onNewConversation: onNewConversation,
            onToggleRecording: onToggleRecording
        ))
    }
}

// MARK: - macOS Menu Bar Configuration
struct MenuBarCommands: Commands {
    @Binding var showingSettings: Bool

    var body: some Commands {
        // File Menu
        CommandGroup(replacing: .newItem) {
            Button("New Conversation") {
                NotificationCenter.default.post(name: NSNotification.Name("NewConversation"), object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // Edit Menu - keep defaults

        // View Menu
        CommandMenu("Voice") {
            Button("Start/Stop Recording") {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleRecording"), object: nil)
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Toggle Mute") {
                NotificationCenter.default.post(name: NSNotification.Name("ToggleMute"), object: nil)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])

            Divider()

            Button("Clear Conversation") {
                NotificationCenter.default.post(name: NSNotification.Name("ClearConversation"), object: nil)
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
        }

        // Settings
        CommandGroup(replacing: .appSettings) {
            Button("Settings...") {
                NotificationCenter.default.post(name: NSNotification.Name("ShowSettings"), object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)
        }

        // Help Menu
        CommandGroup(replacing: .help) {
            Button("OS One Help") {
                if let url = URL(string: "https://github.com/anthropics/os-one") {
                    NSWorkspace.shared.open(url)
                }
            }

            Button("Report Issue") {
                if let url = URL(string: "https://github.com/anthropics/os-one/issues") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

// MARK: - macOS Responsive Layout
struct ResponsiveLayout<Content: View>: View {
    let content: Content
    @State private var windowSize: CGSize = CGSize(width: 800, height: 600)

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            let isCompact = geometry.size.width < 600

            content
                .frame(maxWidth: isCompact ? .infinity : 900)
                .padding(isCompact ? 20 : 40)
                .onChange(of: geometry.size) { newSize in
                    windowSize = newSize
                }
        }
    }
}

// MARK: - macOS-Specific Views

struct MacOSHomeView: View {
    @StateObject private var windowManager = WindowManager.shared

    var body: some View {
        VStack {
            // macOS-optimized UI
            Text("macOS Home View")
        }
        .frame(minWidth: 600, minHeight: 400)
        .onAppear {
            windowManager.centerWindow()
        }
    }
}

// MARK: - Microphone Permissions (macOS)
class MacOSMicrophonePermissions: ObservableObject {
    @Published var hasPermission: Bool = false

    func requestPermission() {
        #if os(macOS)
        // Check if permission is granted
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            hasPermission = true

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.hasPermission = granted
                }
            }

        case .denied, .restricted:
            hasPermission = false
            showPermissionAlert()

        @unknown default:
            hasPermission = false
        }
        #endif
    }

    private func showPermissionAlert() {
        #if os(macOS)
        let alert = NSAlert()
        alert.messageText = "Microphone Access Required"
        alert.informativeText = "OS One needs access to your microphone for voice input. Please enable microphone access in System Settings > Privacy & Security > Microphone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
        #endif
    }
}

#endif

// MARK: - Cross-Platform UI Helpers
extension View {
    @ViewBuilder
    func platformSpecificPadding() -> some View {
        #if os(iOS)
        self.padding(.horizontal, 20)
        #elseif os(macOS)
        self.padding(.horizontal, 40)
        #endif
    }

    @ViewBuilder
    func platformSpecificFont(size: CGFloat, weight: Font.Weight = .regular) -> some View {
        #if os(iOS)
        self.font(.system(size: size, weight: weight))
        #elseif os(macOS)
        self.font(.system(size: size * 0.9, weight: weight))  // Slightly smaller on macOS
        #endif
    }
}
