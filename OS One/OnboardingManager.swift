//
//  OnboardingManager.swift
//  OS One
//
//  First-launch onboarding - best friend vibes, zero corporate BS
//

import Foundation
import SwiftUI

// MARK: - Onboarding Manager
class OnboardingManager: ObservableObject {

    // MARK: - Published Properties
    @Published var shouldShowOnboarding: Bool
    @Published var currentStep: OnboardingStep = .welcome
    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding")
        }
    }

    // MARK: - Onboarding Steps
    enum OnboardingStep: Int, CaseIterable {
        case welcome = 0
        case modelSelection = 1
        case personalInfo = 2
        case importClaude = 3
        case ready = 4

        var title: String {
            switch self {
            case .welcome:
                return "yo, welcome to OS One 👋"
            case .modelSelection:
                return "pick your model"
            case .personalInfo:
                return "who are you? (optional)"
            case .importClaude:
                return "import your claude chats?"
            case .ready:
                return "you're all set! 🚀"
            }
        }
    }

    // MARK: - Initialization
    init() {
        let completed = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        self.hasCompletedOnboarding = completed
        self.shouldShowOnboarding = !completed
    }

    // MARK: - Navigation
    func nextStep() {
        if let next = OnboardingStep(rawValue: currentStep.rawValue + 1) {
            withAnimation {
                currentStep = next
            }
        }
    }

    func previousStep() {
        if let previous = OnboardingStep(rawValue: currentStep.rawValue - 1) {
            withAnimation {
                currentStep = previous
            }
        }
    }

    func skipOnboarding() {
        hasCompletedOnboarding = true
        shouldShowOnboarding = false
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        shouldShowOnboarding = false
    }

    // MARK: - Reset (for testing)
    func resetOnboarding() {
        hasCompletedOnboarding = false
        shouldShowOnboarding = true
        currentStep = .welcome
    }
}

// MARK: - Onboarding View
struct OnboardingView: View {
    @ObservedObject var onboardingManager: OnboardingManager
    @ObservedObject var anthropicClient: AnthropicClient
    @ObservedObject var customInstructions: CustomInstructionsManager
    @ObservedObject var memoryManager: MemoryManager

    @State private var selectedModel: ModelProvider = .local
    @State private var apiKey: String = ""
    @State private var userName: String = ""
    @State private var userRole: String = ""
    @State private var keepItTechnical: Bool = false
    @State private var beConcise: Bool = false
    @State private var explainLikeSmart: Bool = false
    @State private var showingFilePicker: Bool = false
    @State private var importResult: ImportResult?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                // Progress indicator
                if onboardingManager.currentStep != .welcome && onboardingManager.currentStep != .ready {
                    ProgressView(value: Double(onboardingManager.currentStep.rawValue), total: 4.0)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .padding(.horizontal)
                        .padding(.top)
                }

                Spacer()

                // Current step content
                Group {
                    switch onboardingManager.currentStep {
                    case .welcome:
                        WelcomeStep(
                            onSkip: { onboardingManager.skipOnboarding() },
                            onContinue: { onboardingManager.nextStep() }
                        )

                    case .modelSelection:
                        ModelSelectionStep(
                            selectedModel: $selectedModel,
                            apiKey: $apiKey,
                            anthropicClient: anthropicClient,
                            onNext: { onboardingManager.nextStep() }
                        )

                    case .personalInfo:
                        PersonalInfoStep(
                            userName: $userName,
                            userRole: $userRole,
                            keepItTechnical: $keepItTechnical,
                            beConcise: $beConcise,
                            explainLikeSmart: $explainLikeSmart,
                            onSkip: { onboardingManager.nextStep() },
                            onSave: {
                                savePersonalInfo()
                                onboardingManager.nextStep()
                            }
                        )

                    case .importClaude:
                        ImportClaudeStep(
                            importResult: $importResult,
                            onSkip: { onboardingManager.nextStep() },
                            onImport: { showingFilePicker = true }
                        )

                    case .ready:
                        ReadyStep(
                            onStart: {
                                applyImportIfNeeded()
                                onboardingManager.completeOnboarding()
                            }
                        )
                    }
                }

                Spacer()
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.json, .zip],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
    }

    private func savePersonalInfo() {
        customInstructions.userName = userName
        customInstructions.userRole = userRole
        customInstructions.preferences.keepItTechnical = keepItTechnical
        customInstructions.preferences.beConcise = beConcise
        customInstructions.preferences.explainLikeSmart = explainLikeSmart

        let generated = customInstructions.generateInstructionsFromPreferences()
        if !generated.isEmpty {
            customInstructions.customInstructions = generated
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        Task {
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }

                let importer = ClaudeImporter(
                    memoryManager: memoryManager,
                    customInstructionsManager: customInstructions
                )

                if let result = await importer.previewImport(url) {
                    await MainActor.run {
                        importResult = result
                    }
                }

            case .failure(let error):
                print("❌ File import failed: \(error)")
            }
        }
    }

    private func applyImportIfNeeded() {
        if let result = importResult {
            let importer = ClaudeImporter(
                memoryManager: memoryManager,
                customInstructionsManager: customInstructions
            )
            importer.applyImportResults(result, confirmFacts: true, applySuggestedInstructions: true)
        }
    }
}

// MARK: - Welcome Step
struct WelcomeStep: View {
    let onSkip: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("yo, welcome to OS One 👋")
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                Text("this is your AI assistant. it runs on your phone.")
                Text("no cloud BS unless you want it. your stuff stays yours.")
            }
            .font(.system(size: 18))
            .foregroundColor(.gray)
            .padding(.horizontal, 40)

            Text("wanna take 30 seconds to set this up? or nah, just dive in?")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 20)

            VStack(spacing: 16) {
                Button(action: onContinue) {
                    Text("yeah, let's do this")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }

                Button(action: onSkip) {
                    Text("skip setup - just go")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }
}

// MARK: - Model Selection Step
struct ModelSelectionStep: View {
    @Binding var selectedModel: ModelProvider
    @Binding var apiKey: String
    @ObservedObject var anthropicClient: AnthropicClient

    let onNext: () -> Void

    @State private var isTestingKey: Bool = false
    @State private var keyTestResult: String?

    var body: some View {
        VStack(spacing: 24) {
            Text("aight, so here's the deal:")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 20) {
                // Local Model Option
                ModelOptionCard(
                    icon: "🔒",
                    title: "LOCAL MODE",
                    subtitle: "(default)",
                    features: [
                        "your phone does the thinking. totally private.",
                        "decent speed, good enough for most stuff.",
                        "works offline. zero cost."
                    ],
                    isSelected: selectedModel == .local,
                    action: { selectedModel = .local }
                )

                // Haiku Option
                ModelOptionCard(
                    icon: "⚡",
                    title: "HAIKU 4.5 MODE",
                    subtitle: "(if you got API credits)",
                    features: [
                        "claude's fastest model. stupid fast responses.",
                        "needs internet. costs like $0.25 per million words.",
                        "(that's VERY cheap btw)"
                    ],
                    isSelected: selectedModel == .haiku,
                    action: { selectedModel = .haiku }
                )
            }
            .padding(.horizontal, 24)

            // API Key Input (if Haiku selected)
            if selectedModel == .haiku {
                VStack(spacing: 12) {
                    Text("cool! paste your anthropic API key:")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    Text("(get one at console.anthropic.com)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))

                    TextField("sk-ant-api03-...", text: $apiKey)
                        .font(.system(size: 14, design: .monospaced))
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    if let result = keyTestResult {
                        Text(result)
                            .font(.system(size: 12))
                            .foregroundColor(result.contains("✅") ? .green : .red)
                    }

                    Button(action: testAPIKey) {
                        HStack {
                            if isTestingKey {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            }
                            Text(isTestingKey ? "testing..." : "test & save")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(8)
                    }
                    .disabled(apiKey.isEmpty || isTestingKey)
                }
                .padding(.horizontal, 40)
                .padding(.top, 12)
            }

            Button(action: onNext) {
                Text("next")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }

    private func testAPIKey() {
        isTestingKey = true
        keyTestResult = nil

        anthropicClient.saveAPIKey(apiKey)

        Task {
            let success = await anthropicClient.testConnection()

            await MainActor.run {
                isTestingKey = false
                keyTestResult = success ? "✅ nice! you're set up" : "❌ key doesn't work - check it?"
            }
        }
    }
}

// MARK: - Model Option Card
struct ModelOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let features: [String]
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(icon)
                        .font(.system(size: 32))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)

                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    }
                }

                ForEach(features, id: \.self) { feature in
                    Text("• \(feature)")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
            }
            .padding()
            .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.white : Color.gray.opacity(0.3), lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Personal Info Step
struct PersonalInfoStep: View {
    @Binding var userName: String
    @Binding var userRole: String
    @Binding var keepItTechnical: Bool
    @Binding var beConcise: Bool
    @Binding var explainLikeSmart: Bool

    let onSkip: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("i work better if i know a bit about you.\nnothing creepy, just basics. skip if you want.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("what should i call you?")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    TextField("name", text: $userName)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("what do you do?")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    TextField("e.g., iOS dev, student, entrepreneur", text: $userRole)
                        .textFieldStyle(.roundedBorder)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("any preferences for how i talk?")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.top, 8)

                    Toggle("keep it technical (code, details)", isOn: $keepItTechnical)
                    Toggle("be concise (no fluff)", isOn: $beConcise)
                    Toggle("explain like i'm smart (skip basics)", isOn: $explainLikeSmart)
                }
                .toggleStyle(SwitchToggleStyle(tint: .white))
                .foregroundColor(.white)
                .font(.system(size: 14))
            }
            .padding(.horizontal, 40)

            HStack(spacing: 16) {
                Button(action: onSkip) {
                    Text("skip this")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }

                Button(action: onSave) {
                    Text("save preferences")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }
}

// MARK: - Import Claude Step
struct ImportClaudeStep: View {
    @Binding var importResult: ImportResult?
    let onSkip: () -> Void
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Text("btw, if you've used claude before, i can import\nyour conversations and remember context.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Text("it's all local. nothing leaves your phone.")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.7))

            if let result = importResult {
                VStack(spacing: 12) {
                    Text("✅ import preview:")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.green)

                    Text(result.summary)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 40)
            }

            HStack(spacing: 16) {
                Button(action: onSkip) {
                    Text("no thanks")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.clear)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }

                Button(action: onImport) {
                    Text(importResult == nil ? "yeah, import" : "import another")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }
}

// MARK: - Ready Step
struct ReadyStep: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Text("that's it. you're all set up.")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 16) {
                TipRow(icon: "mic.fill", text: "tap mic → talk → done")
                TipRow(icon: "mic.fill", text: "long press mic → keep talking")
                TipRow(icon: "arrow.up", text: "swipe up → quick controls")
                TipRow(icon: "gear", text: "settings → everything else")
            }
            .padding(.horizontal, 40)

            Text("now go build something cool 🚀")
                .font(.system(size: 18))
                .foregroundColor(.gray)
                .padding(.top, 20)

            Button(action: onStart) {
                Text("start using OS One")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
            .padding(.top, 20)
        }
    }
}

struct TipRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 24)

            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}
