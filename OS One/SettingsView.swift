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
    @State private var useHaiku: Bool = false
    @State private var haikuAPIKey: String = ""
    @State private var showingAPIKeyTest: Bool = false
    @State private var apiKeyTestResult: String?

    // MARK: - Phase 4: Custom Instructions
    @State private var customInstructions: String = ""
    @State private var userName: String = ""
    @State private var userRole: String = ""

    // MARK: - Phase 4: Memory
    @State private var showingMemoryView: Bool = false
    @State private var memoryCount: Int = 0

    // MARK: - Phase 4: Claude Import
    @State private var showingClaudeImport: Bool = false

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.5, green: 0.5, blue: 0.5).edgesIgnoringSafeArea(.all).opacity(0.1)
                ScrollView {
                    VStack {
                        HStack {
                            Text("OS")
                                .font(.system(
                                    size: 50,
                                    weight: .light
                                ))
                            Text("1")
                                .font(.system(
                                    size: 30,
                                    weight: .regular
                                ))
                                .baselineOffset(20.0)
                        }
                        Text("settings")
                            .font(.system(size: 25, weight: .light))
                            .padding(.bottom, 5)
                        Text(appVersionAndBuild())
                            .font(.system(size: 15, weight: .light))
                        Picker("Name of your voice assistant", selection: $name) {
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
                            .pickerStyle(.wheel)
                            .onChange(of: name) {
                                UserDefaults.standard.set($0, forKey: "name")
                            }
                        Text("Settings", comment: "Choose which features to use.")
                            .bold()
                        Toggle("Allow location", isOn: $allowLocation)
                            .onChange(of: allowLocation) {
                                UserDefaults.standard.set($0, forKey: "allowLocation")
                            }
                        Toggle("Allow search", isOn: $allowSearch)
                            .onChange(of: allowSearch) {
                                UserDefaults.standard.set($0, forKey: "allowSearch")
                            }
                        Toggle("GPT 4.1 nano", isOn: $gpt4)
                            .onChange(of: gpt4) {
                                UserDefaults.standard.set($0, forKey: "gpt4")
                            }
                        Toggle("OpenAI voice", isOn: $openAIVoice)
                            .onChange(of: openAIVoice) {
                                UserDefaults.standard.set($0, forKey: "openAIVoice")
                            }
                        if openAISessionKey != "" {
                            ProgressView(value: openAIUsage / 1000) {
                                Text("$\((openAIUsage / 100), specifier: "%.2f")")
                            }
                            .padding(.bottom, 10)
                        }
                        Toggle("Eleven Labs voice", isOn: $elevenLabs)
                            .onChange(of: elevenLabs) {
                                UserDefaults.standard.set($0, forKey: "elevenLabs")
                            }
                        ProgressView(value: elevenLabsUsage) {
                            Text("\(floatToPercent(float:elevenLabsUsage))")
                                .opacity(elevenLabs ? 1.0 : 0.5)
                        }
                        .padding(.bottom, 10)

                        // MARK: - Phase 4: Model Provider Selection
                        Group {
                            Text("model provider", comment: "Choose AI model")
                                .bold()
                                .padding(.top, 10)

                            Picker("AI Model", selection: $useHaiku) {
                                Text("🔒 Local (Private)").tag(false)
                                Text("⚡ Haiku 4.5 (Fast)").tag(true)
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: useHaiku) {
                                UserDefaults.standard.set($0, forKey: "useHaiku")
                            }

                            if useHaiku {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("anthropic api key")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    SecureField("sk-ant-api03-...", text: $haikuAPIKey)
                                        .font(.system(.body, design: .monospaced))
                                        .autocapitalization(.none)
                                        .onChange(of: haikuAPIKey) {
                                            UserDefaults.standard.set($0, forKey: "haikuAPIKey")
                                        }

                                    if let result = apiKeyTestResult {
                                        Text(result)
                                            .font(.caption)
                                            .foregroundColor(result.contains("✅") ? .green : .red)
                                    }

                                    Button(action: testHaikuAPIKey) {
                                        HStack {
                                            if showingAPIKeyTest {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle())
                                                    .scaleEffect(0.8)
                                            }
                                            Text(showingAPIKeyTest ? "testing..." : "test key")
                                                .font(.caption)
                                        }
                                    }
                                    .disabled(haikuAPIKey.isEmpty || showingAPIKeyTest)

                                    Text("get key at console.anthropic.com")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .padding(.bottom, 10)

                        // MARK: - Phase 4: Custom Instructions
                        Group {
                            Text("custom instructions", comment: "Tell AI about yourself")
                                .bold()
                                .padding(.top, 10)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("who are you?")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                TextField("name", text: $userName)
                                    .onChange(of: userName) {
                                        UserDefaults.standard.set($0, forKey: "customInstructionsName")
                                    }

                                TextField("role (e.g., iOS dev, student)", text: $userRole)
                                    .onChange(of: userRole) {
                                        UserDefaults.standard.set($0, forKey: "customInstructionsRole")
                                    }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("custom instructions (500 char max)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                TextEditor(text: $customInstructions)
                                    .frame(height: 100)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .onChange(of: customInstructions) { newValue in
                                        let truncated = String(newValue.prefix(500))
                                        customInstructions = truncated
                                        UserDefaults.standard.set(truncated, forKey: "customInstructions")
                                    }

                                Text("\(customInstructions.count)/500")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.bottom, 10)

                        // MARK: - Phase 4: Memory & Claude Import
                        Group {
                            Text("memory & context", comment: "What AI remembers")
                                .bold()
                                .padding(.top, 10)

                            Button(action: { showingMemoryView = true }) {
                                HStack {
                                    Text("🧠 memories (\(memoryCount))")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                            }

                            Button(action: { showingClaudeImport = true }) {
                                HStack {
                                    Text("📥 import claude chats")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding(.bottom, 10)

                        Group {
                            SecureField("OpenAI API Key", text: $openAIApiKey)
                                .onChange(of: openAIApiKey) {
                                    UserDefaults.standard.set($0, forKey: "openAIApiKey")
                                }
                            SecureField("OpenAI Session Key (optional)", text: $openAISessionKey)
                                .onChange(of: openAISessionKey) {
                                    UserDefaults.standard.set($0, forKey: "openAISessionKey")
                                }
                            SecureField("Eleven Labs API Key", text: $elevenLabsApiKey)
                                .onChange(of: elevenLabsApiKey) {
                                    UserDefaults.standard.set($0, forKey: "elevenLabsApiKey")
                                }
                                .padding(.bottom, 10)
                        }

                        // MARK: - Offline Mode Settings
                        Group {
                            Text("Offline mode", comment: "Fully offline voice AI settings")
                                .bold()
                                .padding(.top, 10)

                            Toggle("Enable offline mode", isOn: $offlineMode)
                                .onChange(of: offlineMode) {
                                    UserDefaults.standard.set($0, forKey: "offlineMode")
                                }

                            if offlineMode {
                                // Model selection
                                Picker("Local Model", selection: $selectedLocalModel) {
                                    Text("Qwen 3 4B (default)").tag("Qwen/Qwen3-4B-Instruct")
                                    Text("Qwen 2.5 3B (speed)").tag("Qwen/Qwen2.5-3B-Instruct")
                                    Text("Qwen 2.5 1.5B").tag("Qwen/Qwen2.5-1.5B-Instruct")
                                    Text("Gemma 2 2B").tag("google/gemma-2-2b-it")
                                    Text("Llama 3.2 3B").tag("meta-llama/Llama-3.2-3B-Instruct")
                                    Text("Llama 3.2 1B").tag("meta-llama/Llama-3.2-1B-Instruct")
                                }
                                .pickerStyle(.menu)
                                .onChange(of: selectedLocalModel) {
                                    UserDefaults.standard.set($0, forKey: "selectedLocalModel")
                                }

                                // VAD settings
                                Toggle("Voice Activity Detection", isOn: $useVAD)
                                    .onChange(of: useVAD) {
                                        UserDefaults.standard.set($0, forKey: "useVAD")
                                    }

                                if useVAD {
                                    VStack(alignment: .leading) {
                                        Text("VAD Sensitivity: \(Int(vadSensitivity * 100))%")
                                            .font(.caption)
                                        Slider(value: $vadSensitivity, in: 0...1, step: 0.1)
                                            .onChange(of: vadSensitivity) {
                                                UserDefaults.standard.set($0, forKey: "vadSensitivity")
                                            }
                                    }
                                }

                                // Waveform display
                                Toggle("Show waveform", isOn: $showWaveform)
                                    .onChange(of: showWaveform) {
                                        UserDefaults.standard.set($0, forKey: "showWaveform")
                                    }

                                // On-device recognition
                                Toggle("On-device speech recognition", isOn: $onDeviceRecognition)
                                    .onChange(of: onDeviceRecognition) {
                                        UserDefaults.standard.set($0, forKey: "onDeviceRecognition")
                                    }

                                // TTS settings
                                VStack(alignment: .leading) {
                                    Text("Speech Rate: \(Int(ttsRate * 100))%")
                                        .font(.caption)
                                    Slider(value: $ttsRate, in: 0...1, step: 0.1)
                                        .onChange(of: ttsRate) {
                                            UserDefaults.standard.set($0, forKey: "ttsRate")
                                        }
                                }

                                VStack(alignment: .leading) {
                                    Text("Speech Pitch: \(String(format: "%.1f", ttsPitch))x")
                                        .font(.caption)
                                    Slider(value: $ttsPitch, in: 0.5...2.0, step: 0.1)
                                        .onChange(of: ttsPitch) {
                                            UserDefaults.standard.set($0, forKey: "ttsPitch")
                                        }
                                }
                            }
                        }
                        .padding(.bottom, 10)

                        Group {
                            Text("Custom settings", comment: "Set your own custom model, voice, and prompt.")
                                .bold()
                            TextField("Override OpenAI model", text: $overrideOpenAIModel)
                                .onChange(of: overrideOpenAIModel) {
                                    UserDefaults.standard.set($0, forKey: "overrideOpenAIModel")
                                }
                            TextField("Override ElevenLabs voice ID", text: $overrideVoiceID)
                                .onChange(of: overrideVoiceID) {
                                    UserDefaults.standard.set($0, forKey: "overrideVoiceID")
                                    if !overrideVoiceID.isEmpty || !overrideSystemPrompt.isEmpty {
                                        UserDefaults.standard.set("Custom", forKey: "name")
                                    }
                                }
                            TextField("Override system prompt", text: $overrideSystemPrompt)
                                .onChange(of: overrideSystemPrompt) {
                                    UserDefaults.standard.set($0, forKey: "overrideSystemPrompt")
                                    if !overrideVoiceID.isEmpty || !overrideSystemPrompt.isEmpty {
                                        UserDefaults.standard.set("Custom", forKey: "name")
                                    }
                                }
                        }
                    }
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .padding([.leading, .trailing], 40)
                    .onAppear {
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
                        useHaiku = UserDefaults.standard.bool(forKey: "useHaiku")
                        haikuAPIKey = UserDefaults.standard.string(forKey: "haikuAPIKey") ?? ""
                        customInstructions = UserDefaults.standard.string(forKey: "customInstructions") ?? ""
                        userName = UserDefaults.standard.string(forKey: "customInstructionsName") ?? ""
                        userRole = UserDefaults.standard.string(forKey: "customInstructionsRole") ?? ""

                        if (elevenLabsApiKey != "" && elevenLabs) {
                            elevenLabsGetUsage { result in
                                switch result {
                                case .success(let usage):
                                    elevenLabsUsage = usage
                                case .failure(let error):
                                    print("Eleven Labs API error: \(error.localizedDescription)")
                                }
                            }
                        }

                        if (openAISessionKey != "") {
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
                }
            }
            .toolbar {
                Button("Done") {
                    dismiss()
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
                apiKeyTestResult = success ? "✅ nice! you're set up" : "❌ key doesn't work - check it?"
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
