//
//  UIModeManager.swift
//  OS One
//
//  Progressive Disclosure UX - Clean/Flexible/Pro Modes
//  Provides different UI complexity levels for different user needs
//

import SwiftUI
import Combine

// MARK: - UI Mode Types
enum UIMode: String, CaseIterable, Identifiable {
    case clean = "Clean"
    case flexible = "Flexible"
    case pro = "Pro"

    var id: String { rawValue }

    var description: String {
        switch self {
        case .clean:
            return "Minimalist interface - just conversation and microphone"
        case .flexible:
            return "Swipe-up drawer with quick controls"
        case .pro:
            return "Full dashboard with live metrics and advanced controls"
        }
    }

    var icon: String {
        switch self {
        case .clean:
            return "circle"
        case .flexible:
            return "circle.lefthalf.filled"
        case .pro:
            return "circle.grid.3x3.fill"
        }
    }
}

// MARK: - UI Mode Manager
class UIModeManager: ObservableObject {

    // MARK: - Published Properties
    @Published var currentMode: UIMode {
        didSet {
            UserDefaults.standard.set(currentMode.rawValue, forKey: "uiMode")
            print("UIModeManager: Mode changed to \(currentMode.rawValue)")
        }
    }

    @Published var showModeSelector: Bool = false
    @Published var drawerOffset: CGFloat = 0.0  // For Flexible mode drawer
    @Published var drawerIsExpanded: Bool = false

    // MARK: - Initialization
    init() {
        // Load saved mode
        let savedMode = UserDefaults.standard.string(forKey: "uiMode") ?? UIMode.clean.rawValue
        currentMode = UIMode(rawValue: savedMode) ?? .clean

        print("UIModeManager: Initialized with mode: \(currentMode.rawValue)")
    }

    // MARK: - Mode Management
    func switchMode(to mode: UIMode) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            currentMode = mode
        }
    }

    func cycleModes() {
        let modes = UIMode.allCases
        guard let currentIndex = modes.firstIndex(of: currentMode) else { return }

        let nextIndex = (currentIndex + 1) % modes.count
        switchMode(to: modes[nextIndex])
    }

    // MARK: - Flexible Mode Drawer Control
    func expandDrawer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            drawerIsExpanded = true
            drawerOffset = -300  // Move drawer up
        }
    }

    func collapseDrawer() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
            drawerIsExpanded = false
            drawerOffset = 0
        }
    }

    func toggleDrawer() {
        if drawerIsExpanded {
            collapseDrawer()
        } else {
            expandDrawer()
        }
    }

    // MARK: - Pro Mode Features
    var shouldShowMetrics: Bool {
        currentMode == .pro
    }

    var shouldShowAdvancedControls: Bool {
        currentMode == .pro || currentMode == .flexible
    }

    var shouldShowQuickActions: Bool {
        currentMode != .clean
    }

    // MARK: - First-Time Setup
    func recommendModeForDevice() -> UIMode {
        // Recommend based on device capabilities
        let deviceRAM = DeviceCapabilityDetector.shared.totalRAMInGB

        if deviceRAM >= 8 {
            return .pro  // High-end devices get full experience
        } else if deviceRAM >= 6 {
            return .flexible  // Mid-range gets drawer
        } else {
            return .clean  // Lower-end gets minimal UI
        }
    }

    func setupFirstTime() {
        // Check if first launch
        let hasLaunchedBefore = UserDefaults.standard.bool(forKey: "hasLaunchedBefore")

        if !hasLaunchedBefore {
            let recommendedMode = recommendModeForDevice()
            currentMode = recommendedMode
            UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
            print("UIModeManager: First launch - recommended mode: \(recommendedMode.rawValue)")
        }
    }
}

// MARK: - Mode Selector View
struct ModeSelectorView: View {
    @ObservedObject var modeManager: UIModeManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Choose Your Experience")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Select the interface complexity that works best for you")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 30)
                .padding(.horizontal)

                // Mode Options
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(UIMode.allCases) { mode in
                            ModeCard(
                                mode: mode,
                                isSelected: modeManager.currentMode == mode,
                                action: {
                                    modeManager.switchMode(to: mode)
                                }
                            )
                        }
                    }
                    .padding()
                }

                // Current Mode Indicator
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Current: \(modeManager.currentMode.rawValue)")
                        .fontWeight(.medium)
                }
                .padding()
                .background(Color(.systemGray6))
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Mode Card
struct ModeCard: View {
    let mode: UIMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: mode.icon)
                        .font(.system(size: 30))
                        .foregroundColor(isSelected ? .white : .accentColor)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                    }
                }

                Text(mode.rawValue)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .white : .primary)

                Text(mode.description)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                    .fixedSize(horizontal: false, vertical: true)

                // Preview images would go here
                if mode == .clean {
                    previewClean
                } else if mode == .flexible {
                    previewFlexible
                } else {
                    previewPro
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.accentColor : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var previewClean: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 40, height: 40)
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 20)
                .cornerRadius(4)
        }
        .padding(.top, 8)
    }

    private var previewFlexible: some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 60)
                .cornerRadius(8)
            HStack(spacing: 8) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 30, height: 30)
                }
            }
        }
        .padding(.top, 8)
    }

    private var previewPro: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 40)
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 40)
            }
            HStack(spacing: 8) {
                ForEach(0..<4) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 25, height: 25)
                }
            }
        }
        .padding(.top, 8)
    }
}

// MARK: - Quick Mode Switcher Button
struct QuickModeSwitcherButton: View {
    @ObservedObject var modeManager: UIModeManager

    var body: some View {
        Button(action: {
            modeManager.cycleModes()
        }) {
            Image(systemName: modeManager.currentMode.icon)
                .font(.system(size: 20))
                .foregroundColor(.primary)
        }
    }
}
