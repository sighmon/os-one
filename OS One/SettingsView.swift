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
    @State private var gatewayEnabled: Bool = false
    @State private var gatewayURL: String = ""
    @State private var gatewayToken: String = ""
    @State private var gatewaySessionKey: String = "main"
    @State private var gatewayTestInProgress: Bool = false
    @State private var gatewayTestMessage: String = ""
    @State private var showGatewayTestAlert: Bool = false
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
                                Text("Moss").tag("Moss")
                            }
                            Group {
                                Text("Ava").tag("Ava")
                                Text("Darth Vader").tag("Darth Vader")
                                Text("Johnny Five").tag("Johnny Five")
                                Text("J.A.R.V.I.S.").tag("J.A.R.V.I.S.")
                                Text("Clawdbot").tag("Clawdbot")
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
                        Group {
                            Text("Clawdbot gateway")
                                .bold()
                            Toggle("Use Clawdbot Gateway", isOn: $gatewayEnabled)
                                .onChange(of: gatewayEnabled) {
                                    UserDefaults.standard.set($0, forKey: "gatewayEnabled")
                                }
                            TextField("Gateway URL (ws://host:18789)", text: $gatewayURL)
                                .onChange(of: gatewayURL) {
                                    UserDefaults.standard.set($0, forKey: "gatewayURL")
                                }
                            SecureField("Gateway token (optional)", text: $gatewayToken)
                                .onChange(of: gatewayToken) {
                                    UserDefaults.standard.set($0, forKey: "gatewayToken")
                                }
                            TextField("Gateway session key", text: $gatewaySessionKey)
                                .onChange(of: gatewaySessionKey) {
                                    UserDefaults.standard.set($0, forKey: "gatewaySessionKey")
                                }
                            Button(action: testGatewayConnection) {
                                if gatewayTestInProgress {
                                    HStack {
                                        ProgressView()
                                        Text("Testing...")
                                    }
                                } else {
                                    Text("Test Gateway Connection")
                                }
                            }
                            .disabled(gatewayTestInProgress || gatewayURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                        gatewayEnabled = UserDefaults.standard.bool(forKey: "gatewayEnabled")
                        gatewayURL = UserDefaults.standard.string(forKey: "gatewayURL") ?? ""
                        gatewayToken = UserDefaults.standard.string(forKey: "gatewayToken") ?? ""
                        gatewaySessionKey = UserDefaults.standard.string(forKey: "gatewaySessionKey") ?? "main"
                        if !overrideVoiceID.isEmpty || !overrideSystemPrompt.isEmpty {
                            name = "Custom"
                        }

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
            .alert("Gateway Test", isPresented: $showGatewayTestAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(gatewayTestMessage)
            }
        }
    }

    func testGatewayConnection() {
        gatewayTestInProgress = true
        let token = gatewayToken.isEmpty ? nil : gatewayToken
        let sessionKey = gatewaySessionKey.isEmpty ? "main" : gatewaySessionKey
        GatewayChatClient.shared.sendChatMessage(
            message: "ping",
            sessionKey: sessionKey,
            gatewayURL: gatewayURL,
            token: token
        ) { result in
            DispatchQueue.main.async {
                gatewayTestInProgress = false
                switch result {
                case .success(let content):
                    gatewayTestMessage = content.isEmpty ? "Gateway replied, but the message was empty." : content
                case .failure(let error):
                    gatewayTestMessage = "Gateway error: \(error.localizedDescription)"
                }
                showGatewayTestAlert = true
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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
