//
//  SettingsView.swift
//  OS One
//
//  Created by Simon Loffler on 3/4/2023.
//

import SwiftUI

struct SettingsView: View {
    @State private var elevenLabsApiKey: String = ""
    @State private var elevenLabs: Bool = true
    @State private var openAIVoice: Bool = false
    @State private var elevenLabsUsage: Float = 0
    @State private var openAIApiKey: String = ""
    @State private var openAISessionKey: String = ""
    @State private var openAIUsage: Float = 0
    @State private var gpt4: Bool = true
    @State private var vision: Bool = false
    @State private var allowLocation: Bool = false
    @State private var allowSearch: Bool = false
    @State private var name: String = ""
    @State private var overrideOpenAIModel: String = ""
    @State private var overrideVoiceID: String = ""
    @State private var overrideSystemPrompt: String = ""

    // MARK: - Offline Mode Settings
    @State private var offlineMode: Bool = false
    @State private var useVAD: Bool = false
    @State private var vadSensitivity: Float = 0.5
    @State private var showWaveform: Bool = true
    @State private var onDeviceRecognition: Bool = true
    @State private var selectedLocalModel: String = "Qwen/Qwen2.5-3B-Instruct"
    @State private var ttsRate: Float = 0.5
    @State private var ttsPitch: Float = 1.0
    @State private var selectedVoiceId: String = ""

    // MARK: - Phase 4: Model Provider
    enum ModelProvider: String, CaseIterable {
        case local = "local"
        case haiku = "haiku"
        #if os(macOS)
        case ollama = "ollama"
        #endif
    }

    @State private var modelProvider: ModelProvider = .local
    @State private var haikuAPIKey: String = ""
    @State private var showingAPIKeyTest: Bool = false
    @State private var apiKeyTestResult: String?

    // MARK: - Ollama Settings (macOS only)
    #if os(macOS)
    @State private var ollamaBaseURL: String = "http://localhost:11434"
    @State private var ollamaSelectedModel: String = "qwen2.5:3b"
    @State private var ollamaConnected: Bool = false
    #endif

    // MARK: - Phase 4: Custom Instructions
    @State private var customInstructions: String = ""
    @State private var userName: String = ""
    @State private var userRole: String = ""

    // MARK: - Phase 4: Memory
    @State private var showingMemoryView: Bool = false
    @State private var memoryCount: Int = 0

    // MARK: - Phase 4: Claude Import
    @State private var showingClaudeImport: Bool = false

    // MARK: - Parakeet STT Settings (macOS only)
    #if os(macOS)
    @State private var useParakeetSTT: Bool = false
    @State private var parakeetModel: String = "parakeet-ctc-0.6-v3"
    @State private var parakeetEndpoint: String = "http://localhost:8000"
    @State private var parakeetConnected: Bool = false
    #endif

    // MARK: - Global Hotkey Settings (macOS only)
    #if os(macOS)
    @State private var globalHotkeyEnabled: Bool = false
    @State private var selectedHotkey: String = "left_fn"
    @State private var hasAccessibilityPermissions: Bool = false
    #endif

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                // MARK: - Header Section
                Section {
                    VStack(spacing: 4) {
                        HStack(spacing: 2) {
                            Text("OS")
                                .font(.system(size: 44, weight: .light))
                            Text("1")
                                .font(.system(size: 28, weight: .regular))
                                .baselineOffset(14)
                        }
                        Text("settings")
                            .font(.system(size: 18, weight: .light))
                            .foregroundColor(.secondary)
                        Text(appVersionAndBuild())
                            .font(.system(size: 13, weight: .light))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .listRowBackground(Color.clear)

                // MARK: - Voice Persona Section
                Section {
                    Picker("Voice Persona", selection: $name) {
                        Group {
                            Text("Samantha").tag("Samantha")
                            Text("KITT").tag("KITT")
                            Text("Mr.Robot").tag("Mr.Robot")
                            Text("Elliot").tag("Elliot")
                            Text("GLaDOS").tag("GLaDOS")
                            Text("Spock").tag("Spock")
                            Text("The Oracle").tag("The Oracle")
                            Text("Janet").tag("Janet")
                        }
                        Group {
                            Text("Ava").tag("Ava")
                            Text("Darth Vader").tag("Darth Vader")
                            Text("Johnny Five").tag("Johnny Five")
                            Text("J.A.R.V.I.S.").tag("J.A.R.V.I.S.")
                        }
                        Group {
                            Text("Amy Remeikis").tag("Amy Remeikis")
                            Text("Jane Caro").tag("Jane Caro")
                        }
                        Group {
                            Text("Martha Wells").tag("Murderbot")
                        }
                        Group {
                            Text("Fei-Fei Li").tag("Fei-Fei Li")
                            Text("Andrew Ng").tag("Andrew Ng")
                            Text("Corinna Cortes").tag("Corinna Cortes")
                            Text("Andrej Karpathy").tag("Andrej Karpathy")
                        }
                        Group {
                            Text("Judith Butler").tag("Butler")
                            Text("Noam Chomsky").tag("Chomsky")
                            Text("Angela Davis").tag("Davis")
                            Text("Slavoj Žižek").tag("Žižek")
                        }
                        Group {
                            Text("Seb Chan").tag("Seb Chan")
                        }
                    }
                    .onChange(of: name) {
                        UserDefaults.standard.set($0, forKey: "name")
                    }
                } header: {
                    Label("Voice Persona", systemImage: "person.wave.2")
                }

                // MARK: - Features Section
                Section {
                    Toggle("Allow Location", isOn: $allowLocation)
                        .onChange(of: allowLocation) {
                            UserDefaults.standard.set($0, forKey: "allowLocation")
                        }
                    Toggle("Allow Search", isOn: $allowSearch)
                        .onChange(of: allowSearch) {
                            UserDefaults.standard.set($0, forKey: "allowSearch")
                        }
                } header: {
                    Label("Features", systemImage: "slider.horizontal.3")
                }

                // MARK: - AI Model Section
                Section {
                    Toggle("GPT 4.1 nano", isOn: $gpt4)
                        .onChange(of: gpt4) {
                            UserDefaults.standard.set($0, forKey: "gpt4")
                        }

                    Picker("AI Provider", selection: $modelProvider) {
                        Text("🔒 Local (MLX)").tag(ModelProvider.local)
                        Text("⚡ Haiku 4.5").tag(ModelProvider.haiku)
                        #if os(macOS)
                        Text("🦙 Ollama").tag(ModelProvider.ollama)
                        #endif
                    }
                    #if os(macOS)
                    .pickerStyle(.menu)
                    #else
                    .pickerStyle(.segmented)
                    #endif
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 4)
                    .onChange(of: modelProvider) { newValue in
                        UserDefaults.standard.set(newValue.rawValue, forKey: "modelProvider")
                    }

                    // Haiku settings
                    if modelProvider == .haiku {
                        VStack(alignment: .leading, spacing: 10) {
                            SecureField("sk-ant-api03-...", text: $haikuAPIKey)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: haikuAPIKey) {
                                    UserDefaults.standard.set($0, forKey: "haikuAPIKey")
                                }

                            if let result = apiKeyTestResult {
                                Text(result)
                                    .font(.caption)
                                    .foregroundColor(result.contains("nice") ? .green : .red)
                            }

                            HStack {
                                Button(action: testHaikuAPIKey) {
                                    HStack(spacing: 6) {
                                        if showingAPIKeyTest {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle())
                                                .scaleEffect(0.8)
                                        }
                                        Text(showingAPIKeyTest ? "Testing..." : "Test Key")
                                            .font(.subheadline)
                                    }
                                }
                                .buttonStyle(.bordered)
                                .disabled(haikuAPIKey.isEmpty || showingAPIKeyTest)

                                Spacer()

                                Text("console.anthropic.com")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }

                    // Ollama settings (macOS only)
                    #if os(macOS)
                    if modelProvider == .ollama {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("http://localhost:11434", text: $ollamaBaseURL)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: ollamaBaseURL) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: "ollamaBaseURL")
                                }

                            HStack {
                                Image(systemName: ollamaConnected ? "circle.fill" : "circle")
                                    .foregroundColor(ollamaConnected ? .green : .red)
                                    .font(.caption)
                                Text(ollamaConnected ? "Connected" : "Not running")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Divider()

                            TextField("qwen2.5:3b", text: $ollamaSelectedModel)
                                .font(.system(.body, design: .monospaced))
                                .autocapitalization(.none)
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: ollamaSelectedModel) { newValue in
                                    UserDefaults.standard.set(newValue, forKey: "ollamaSelectedModel")
                                }

                            Text("Popular: qwen2.5:3b, llama3.2:3b, mistral:7b")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    #endif
                } header: {
                    Label("AI Model", systemImage: "cpu")
                } footer: {
                    if modelProvider == .haiku {
                        Text("Fast cloud AI powered by Anthropic Claude Haiku 4.5")
                    } else if modelProvider == .local {
                        Text("Private local processing with on-device AI models")
                    }
                    #if os(macOS)
                    else if modelProvider == .ollama {
                        Text("Local Ollama models (100+ options in GGUF format)")
                    }
                    #endif
                }

                // MARK: - Voice Output Section
                Section {
                    Toggle("OpenAI Voice", isOn: $openAIVoice)
                        .onChange(of: openAIVoice) {
                            UserDefaults.standard.set($0, forKey: "openAIVoice")
                        }

                    if openAISessionKey != "" {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("OpenAI Usage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ProgressView(value: openAIUsage / 1000)
                            Text("$\((openAIUsage / 100), specifier: "%.2f")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Toggle("Eleven Labs Voice", isOn: $elevenLabs)
                        .onChange(of: elevenLabs) {
                            UserDefaults.standard.set($0, forKey: "elevenLabs")
                        }

                    if elevenLabs {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Eleven Labs Usage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ProgressView(value: elevenLabsUsage)
                            Text(floatToPercent(float: elevenLabsUsage))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Voice Output", systemImage: "speaker.wave.2")
                }

                // MARK: - Custom Instructions Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Your Name", text: $userName)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: userName) {
                                UserDefaults.standard.set($0, forKey: "customInstructionsName")
                            }

                        TextField("Role (e.g., iOS dev, student)", text: $userRole)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: userRole) {
                                UserDefaults.standard.set($0, forKey: "customInstructionsRole")
                            }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        TextEditor(text: $customInstructions)
                            .frame(minHeight: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: customInstructions) { newValue in
                                let truncated = String(newValue.prefix(500))
                                customInstructions = truncated
                                UserDefaults.standard.set(truncated, forKey: "customInstructions")
                            }

                        Text("\(customInstructions.count)/500 characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Label("About You", systemImage: "person.text.rectangle")
                } footer: {
                    Text("Help the AI understand who you are and how you prefer to interact.")
                }

                // MARK: - Memory Section
                Section {
                    Button(action: { showingMemoryView = true }) {
                        HStack {
                            Label("Memories", systemImage: "brain.head.profile")
                            Spacer()
                            Text("\(memoryCount)")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)

                    Button(action: { showingClaudeImport = true }) {
                        HStack {
                            Label("Import Claude Chats", systemImage: "square.and.arrow.down")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.primary)
                } header: {
                    Label("Memory & Context", systemImage: "memorychip")
                }

                // MARK: - API Keys Section
                Section {
                    SecureField("OpenAI API Key", text: $openAIApiKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: openAIApiKey) {
                            UserDefaults.standard.set($0, forKey: "openAIApiKey")
                        }

                    SecureField("OpenAI Session Key (optional)", text: $openAISessionKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: openAISessionKey) {
                            UserDefaults.standard.set($0, forKey: "openAISessionKey")
                        }

                    SecureField("Eleven Labs API Key", text: $elevenLabsApiKey)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: elevenLabsApiKey) {
                            UserDefaults.standard.set($0, forKey: "elevenLabsApiKey")
                        }
                } header: {
                    Label("API Keys", systemImage: "key")
                } footer: {
                    Text("Your API keys are stored securely on your device.")
                }

                // MARK: - Offline Mode Section
                Section {
                    Toggle("Enable Offline Mode", isOn: $offlineMode)
                        .onChange(of: offlineMode) {
                            UserDefaults.standard.set($0, forKey: "offlineMode")
                        }

                    if offlineMode {
                        Picker("Local Model", selection: $selectedLocalModel) {
                            Text("Qwen 3 4B (default)").tag("Qwen/Qwen3-4B-Instruct")
                            Text("Qwen 2.5 3B (speed)").tag("Qwen/Qwen2.5-3B-Instruct")
                            Text("Qwen 2.5 1.5B").tag("Qwen/Qwen2.5-1.5B-Instruct")
                            Text("Gemma 2 2B").tag("google/gemma-2-2b-it")
                            Text("Llama 3.2 3B").tag("meta-llama/Llama-3.2-3B-Instruct")
                            Text("Llama 3.2 1B").tag("meta-llama/Llama-3.2-1B-Instruct")
                        }
                        .onChange(of: selectedLocalModel) {
                            UserDefaults.standard.set($0, forKey: "selectedLocalModel")
                        }

                        Toggle("Voice Activity Detection", isOn: $useVAD)
                            .onChange(of: useVAD) {
                                UserDefaults.standard.set($0, forKey: "useVAD")
                            }

                        if useVAD {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("VAD Sensitivity: \(Int(vadSensitivity * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Slider(value: $vadSensitivity, in: 0...1, step: 0.1)
                                    .onChange(of: vadSensitivity) {
                                        UserDefaults.standard.set($0, forKey: "vadSensitivity")
                                    }
                            }
                        }

                        Toggle("Show Waveform", isOn: $showWaveform)
                            .onChange(of: showWaveform) {
                                UserDefaults.standard.set($0, forKey: "showWaveform")
                            }

                        Toggle("On-device Recognition", isOn: $onDeviceRecognition)
                            .onChange(of: onDeviceRecognition) {
                                UserDefaults.standard.set($0, forKey: "onDeviceRecognition")
                            }
                    }
                } header: {
                    Label("Offline Mode", systemImage: "wifi.slash")
                } footer: {
                    if offlineMode {
                        Text("Running fully offline with local AI models.")
                    } else {
                        Text("Enable for fully private, offline voice AI.")
                    }
                }

                // MARK: - Speech Settings Section (shown when offline)
                if offlineMode {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Speech Rate")
                                Spacer()
                                Text("\(Int(ttsRate * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                            Slider(value: $ttsRate, in: 0...1, step: 0.1)
                                .onChange(of: ttsRate) {
                                    UserDefaults.standard.set($0, forKey: "ttsRate")
                                }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Speech Pitch")
                                Spacer()
                                Text("\(String(format: "%.1f", ttsPitch))x")
                                    .foregroundColor(.secondary)
                            }
                            .font(.subheadline)
                            Slider(value: $ttsPitch, in: 0.5...2.0, step: 0.1)
                                .onChange(of: ttsPitch) {
                                    UserDefaults.standard.set($0, forKey: "ttsPitch")
                                }
                        }
                    } header: {
                        Label("Speech Settings", systemImage: "waveform")
                    }
                }

                // MARK: - Parakeet STT Section (macOS only)
                #if os(macOS)
                Section {
                    Toggle("Use Parakeet STT", isOn: $useParakeetSTT)
                        .onChange(of: useParakeetSTT) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "useParakeetSTT")
                        }

                    if useParakeetSTT {
                        Picker("Model", selection: $parakeetModel) {
                            Text("CTC 0.6 v3 (Latest)").tag("parakeet-ctc-0.6-v3")
                            Text("CTC 0.6 v2 (Stable)").tag("parakeet-ctc-0.6-v2")
                        }
                        .onChange(of: parakeetModel) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "parakeetModel")
                        }

                        TextField("http://localhost:8000", text: $parakeetEndpoint)
                            .font(.system(.body, design: .monospaced))
                            .autocapitalization(.none)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: parakeetEndpoint) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "parakeetEndpoint")
                            }

                        HStack {
                            Image(systemName: parakeetConnected ? "circle.fill" : "circle")
                                .foregroundColor(parakeetConnected ? .green : .red)
                            Text(parakeetConnected ? "Connected" : "Not running")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Label("Parakeet STT (macOS)", systemImage: "waveform.circle")
                } footer: {
                    if useParakeetSTT {
                        Text("NVIDIA Parakeet CTC 0.6 - High-quality offline speech recognition")
                    } else {
                        Text("Enable for advanced speech-to-text with Parakeet models")
                    }
                }
                #endif

                // MARK: - Global Dictation Section (macOS only)
                #if os(macOS)
                Section {
                    Toggle("Enable Global Dictation", isOn: $globalHotkeyEnabled)
                        .onChange(of: globalHotkeyEnabled) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "globalHotkeyEnabled")
                        }

                    if globalHotkeyEnabled {
                        if !hasAccessibilityPermissions {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Accessibility permissions required")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }

                            Button("Grant Permissions") {
                                requestAccessibilityPermissions()
                            }
                            .buttonStyle(.bordered)
                        } else {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Permissions granted")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Picker("Activation Hotkey", selection: $selectedHotkey) {
                            Text("Left Fn Key (Hold)").tag("left_fn")
                            Text("Right Fn Key (Hold)").tag("right_fn")
                            Text("Double Fn Tap (Toggle)").tag("double_fn")
                        }
                        .onChange(of: selectedHotkey) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "selectedHotkey")
                        }
                    }
                } header: {
                    Label("Global Dictation (macOS)", systemImage: "keyboard")
                } footer: {
                    if globalHotkeyEnabled {
                        Text("Press hotkey to record, release to transcribe and insert text in any app")
                    } else {
                        Text("Enable system-wide voice input like Whisper Flow")
                    }
                }
                #endif

                // MARK: - Advanced Section
                Section {
                    TextField("Override OpenAI Model", text: $overrideOpenAIModel)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: overrideOpenAIModel) {
                            UserDefaults.standard.set($0, forKey: "overrideOpenAIModel")
                        }

                    TextField("Override ElevenLabs Voice ID", text: $overrideVoiceID)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: overrideVoiceID) {
                            UserDefaults.standard.set($0, forKey: "overrideVoiceID")
                            if !overrideVoiceID.isEmpty || !overrideSystemPrompt.isEmpty {
                                UserDefaults.standard.set("Custom", forKey: "name")
                            }
                        }

                    TextField("Override System Prompt", text: $overrideSystemPrompt)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onChange(of: overrideSystemPrompt) {
                            UserDefaults.standard.set($0, forKey: "overrideSystemPrompt")
                            if !overrideVoiceID.isEmpty || !overrideSystemPrompt.isEmpty {
                                UserDefaults.standard.set("Custom", forKey: "name")
                            }
                        }
                } header: {
                    Label("Advanced", systemImage: "gearshape.2")
                } footer: {
                    Text("Override default settings with custom values.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                loadSettings()
            }
        }
    }

    // MARK: - Load Settings
    private func loadSettings() {
        // Load OS One settings from user defaults
        openAIApiKey = UserDefaults.standard.string(forKey: "openAIApiKey") ?? ""
        openAISessionKey = UserDefaults.standard.string(forKey: "openAISessionKey") ?? ""
        gpt4 = UserDefaults.standard.bool(forKey: "gpt4")
        vision = UserDefaults.standard.bool(forKey: "vision")
        openAIVoice = UserDefaults.standard.bool(forKey: "openAIVoice")
        allowLocation = UserDefaults.standard.bool(forKey: "allowLocation")
        allowSearch = UserDefaults.standard.bool(forKey: "allowSearch")
        elevenLabsApiKey = UserDefaults.standard.string(forKey: "elevenLabsApiKey") ?? ""
        elevenLabs = UserDefaults.standard.bool(forKey: "elevenLabs")
        name = UserDefaults.standard.string(forKey: "name") ?? ""
        overrideOpenAIModel = UserDefaults.standard.string(forKey: "overrideOpenAIModel") ?? ""
        overrideVoiceID = UserDefaults.standard.string(forKey: "overrideVoiceID") ?? ""
        overrideSystemPrompt = UserDefaults.standard.string(forKey: "overrideSystemPrompt") ?? ""
        if !overrideVoiceID.isEmpty || !overrideSystemPrompt.isEmpty {
            name = "Custom"
        }

        // Load offline mode settings
        offlineMode = UserDefaults.standard.bool(forKey: "offlineMode")
        useVAD = UserDefaults.standard.bool(forKey: "useVAD")
        vadSensitivity = UserDefaults.standard.float(forKey: "vadSensitivity") == 0 ? 0.5 : UserDefaults.standard.float(forKey: "vadSensitivity")
        showWaveform = UserDefaults.standard.object(forKey: "showWaveform") == nil ? true : UserDefaults.standard.bool(forKey: "showWaveform")
        onDeviceRecognition = UserDefaults.standard.object(forKey: "onDeviceRecognition") == nil ? true : UserDefaults.standard.bool(forKey: "onDeviceRecognition")
        selectedLocalModel = UserDefaults.standard.string(forKey: "selectedLocalModel") ?? "Qwen/Qwen2.5-3B-Instruct"
        ttsRate = UserDefaults.standard.float(forKey: "ttsRate") == 0 ? 0.5 : UserDefaults.standard.float(forKey: "ttsRate")
        ttsPitch = UserDefaults.standard.float(forKey: "ttsPitch") == 0 ? 1.0 : UserDefaults.standard.float(forKey: "ttsPitch")

        // Load Phase 4 settings
        let providerString = UserDefaults.standard.string(forKey: "modelProvider") ?? "local"
        modelProvider = ModelProvider(rawValue: providerString) ?? .local
        haikuAPIKey = UserDefaults.standard.string(forKey: "haikuAPIKey") ?? ""
        customInstructions = UserDefaults.standard.string(forKey: "customInstructions") ?? ""
        userName = UserDefaults.standard.string(forKey: "customInstructionsName") ?? ""
        userRole = UserDefaults.standard.string(forKey: "customInstructionsRole") ?? ""

        // Load Ollama settings (macOS only)
        #if os(macOS)
        ollamaBaseURL = UserDefaults.standard.string(forKey: "ollamaBaseURL") ?? "http://localhost:11434"
        ollamaSelectedModel = UserDefaults.standard.string(forKey: "ollamaSelectedModel") ?? "qwen2.5:3b"

        // Check Ollama connection if selected
        if modelProvider == .ollama {
            Task {
                let client = OllamaClient()
                ollamaConnected = await client.checkConnection()
            }
        }

        // Load Parakeet STT settings
        useParakeetSTT = UserDefaults.standard.bool(forKey: "useParakeetSTT")
        parakeetModel = UserDefaults.standard.string(forKey: "parakeetModel") ?? "parakeet-ctc-0.6-v3"
        parakeetEndpoint = UserDefaults.standard.string(forKey: "parakeetEndpoint") ?? "http://localhost:8000"

        // Load Global Hotkey settings
        globalHotkeyEnabled = UserDefaults.standard.bool(forKey: "globalHotkeyEnabled")
        selectedHotkey = UserDefaults.standard.string(forKey: "selectedHotkey") ?? "left_fn"
        checkAccessibilityPermissions()
        #endif

        // Fetch API usage
        if elevenLabsApiKey != "" && elevenLabs {
            elevenLabsGetUsage { result in
                switch result {
                case .success(let usage):
                    elevenLabsUsage = usage
                case .failure(let error):
                    print("Eleven Labs API error: \(error.localizedDescription)")
                }
            }
        }

        if openAISessionKey != "" {
            getOpenAIUsage { result in
                switch result {
                case .success(let usage):
                    openAIUsage = usage
                case .failure(let error):
                    print("OpenAI API error: \(error.localizedDescription)")
                }
            }
        }
    }

    func appVersionAndBuild() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"

        return "\(version) (\(build))"
    }

    func floatToPercent(float: Float) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        return formatter.string(from: float as NSNumber) ?? "0%"
    }

    // MARK: - Phase 4: API Key Testing
    func testHaikuAPIKey() {
        showingAPIKeyTest = true
        apiKeyTestResult = nil

        Task {
            let client = AnthropicClient()
            client.saveAPIKey(haikuAPIKey)

            let success = await client.testConnection()

            await MainActor.run {
                showingAPIKeyTest = false
                apiKeyTestResult = success ? "nice! you're set up" : "key doesn't work - check it?"
            }
        }
    }

    // MARK: - Global Hotkey Helpers (macOS only)
    #if os(macOS)
    func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let _ = AXIsProcessTrustedWithOptions(options)

        // Check permissions after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            hasAccessibilityPermissions = AXIsProcessTrusted()
        }
    }

    func checkAccessibilityPermissions() {
        hasAccessibilityPermissions = AXIsProcessTrusted()
    }
    #endif
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
