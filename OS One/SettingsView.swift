//
//  SettingsView.swift
//  OS One
//
//  Created by Simon Loffler on 3/4/2023.
//

import SwiftUI

struct SettingsView: View {
    @State private var elevenLabsApiKey: String = ""
    @State private var openAIApiKey: String = ""
    @State private var her: Bool = true
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.9, green: 0.9, blue: 0.9).edgesIgnoringSafeArea(.all)
                VStack {
                    Text("OS One settings")
                        .font(.system(size: 30, weight: .medium))
                    SecureField("OpenAI API Key", text: $openAIApiKey)
                        .onChange(of: openAIApiKey) {
                            UserDefaults.standard.set($0, forKey: "openAIApiKey")
                        }
                    SecureField("Eleven Labs API Key", text: $elevenLabsApiKey)
                        .onChange(of: elevenLabsApiKey) {
                            UserDefaults.standard.set($0, forKey: "elevenLabsApiKey")
                        }
                    Toggle("Her", isOn: $her)
                        .onChange(of: her) {
                            UserDefaults.standard.set($0, forKey: "her")
                        }
                }
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding([.leading, .trailing], 40)
                .onAppear {
                    // Load OS One settings from user defaults
                    openAIApiKey = UserDefaults.standard.string(forKey: "openAIApiKey") ?? ""
                    elevenLabsApiKey = UserDefaults.standard.string(forKey: "elevenLabsApiKey") ?? ""
                    her = UserDefaults.standard.bool(forKey: "her")
                }
            }
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
