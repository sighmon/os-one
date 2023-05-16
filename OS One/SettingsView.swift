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
    @State private var elevenLabsUsage: Float = 0
    @State private var openAIApiKey: String = ""
    @State private var gpt4: Bool = true
    @State private var name: String = ""
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.9, green: 0.9, blue: 0.9).edgesIgnoringSafeArea(.all)
                VStack {
                    Text("OS One")
                        .font(.system(size: 50, weight: .light))
                    Text("settings")
                        .font(.system(size: 25, weight: .light))
                        .padding(.bottom, 10)
                    Text(appVersionAndBuild())
                        .font(.system(size: 15, weight: .light))
                        .padding(.bottom, 40)
                    SecureField("OpenAI API Key", text: $openAIApiKey)
                        .onChange(of: openAIApiKey) {
                            UserDefaults.standard.set($0, forKey: "openAIApiKey")
                        }
                    SecureField("Eleven Labs API Key", text: $elevenLabsApiKey)
                        .onChange(of: elevenLabsApiKey) {
                            UserDefaults.standard.set($0, forKey: "elevenLabsApiKey")
                        }
                    Toggle("GPT-4", isOn: $gpt4)
                        .onChange(of: gpt4) {
                            UserDefaults.standard.set($0, forKey: "gpt4")
                        }
                    Toggle("Eleven Labs voice", isOn: $elevenLabs)
                        .onChange(of: elevenLabs) {
                            UserDefaults.standard.set($0, forKey: "elevenLabs")
                        }
                    ProgressView(value: elevenLabsUsage)
                    Picker("Name of your voice assistant", selection: $name) {
                        Text("Samantha").tag("Samantha")
                        Text("KITT").tag("KITT")
                        Text("Mr.Robot").tag("Mr.Robot")
                        Text("Elliot").tag("Elliot")
                        Text("GLaDOS").tag("GLaDOS")
                        Text("Spock").tag("Spock")
                        Text("The Oracle").tag("The Oracle")
                    }
                        .pickerStyle(.wheel)
                        .onChange(of: name) {
                            UserDefaults.standard.set($0, forKey: "name")
                        }
                }
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding([.leading, .trailing], 40)
                .onAppear {
                    // Load OS One settings from user defaults
                    openAIApiKey = UserDefaults.standard.string(forKey: "openAIApiKey") ?? ""
                    gpt4 = UserDefaults.standard.bool(forKey: "gpt4")
                    elevenLabsApiKey = UserDefaults.standard.string(forKey: "elevenLabsApiKey") ?? ""
                    elevenLabs = UserDefaults.standard.bool(forKey: "elevenLabs")
                    name = UserDefaults.standard.string(forKey: "name") ?? ""
                    if (elevenLabs) {
                        elevenLabsGetUsage { result in
                            switch result {
                            case .success(let usage):
                                elevenLabsUsage = usage
                            case .failure(let error):
                                print("Eleven Labs API error: \(error.localizedDescription)")
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
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
