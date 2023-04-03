//
//  HomeView.swift
//  ChatGPT Voice
//
//  Created by Simon Loffler on 2/4/2023.
//

import AVFoundation
import SwiftUI

var speechRecognizer = SpeechRecognizer()

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var navigate = false
    @State private var isRecording = false
    @StateObject private var speechSynthesizerManager = SpeechSynthesizerManager()

    var body: some View {
        NavigationView {
            ZStack {
                Color(
                    red: 240/255,
                    green: 88/255,
                    blue: 56/255
                ).edgesIgnoringSafeArea(.all)
                VStack {
                    Text("OS One")
                        .font(.system(
                            size: 60,
                            weight: .light
                        ))
                        .padding(.bottom, 100)
                    NavigationLink(destination: ContentView(), isActive: $navigate) {
                        Button("Conversations", action: {navigate = true})
                            .font(.system(
                                size: 20,
                                weight: .light
                            ))
                            .foregroundColor(.primary)
                            .buttonStyle(.bordered)
                    }
                    Button("Stop", action: {
                        speechRecognizer.stopTranscribing()
                        addConversation()
                    })
                        .font(.system(
                            size: 20,
                            weight: .light
                        ))
                        .foregroundColor(.primary)
                        .buttonStyle(.bordered)
                }
                .onAppear {
                    playTextWithSiri(
                        text: "Hello, how can I help?"
                    )
                    isRecording = true
                }
                .onDisappear {
                    speechRecognizer.stopTranscribing()
                    isRecording = false
                }
            }
        }
    }

    func playTextWithSiri(text: String) {
        let speechUtterance = AVSpeechUtterance(string: text)

        // Set the voice to the default system voice
        speechUtterance.voice = AVSpeechSynthesisVoice(language: nil)

        // Set the speech rate (default is AVSpeechUtteranceDefaultSpeechRate)
        speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate

        // Start the speech synthesizer
        speechSynthesizerManager.speechSynthesizer.speak(speechUtterance)
    }

    private func addConversation() {
        withAnimation {
            let newConversation = Conversation(context: viewContext)
            newConversation.timestamp = Date()
            newConversation.messages = speechRecognizer.transcript

            do {
                try viewContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

class SpeechSynthesizerManager: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    var speechSynthesizer: AVSpeechSynthesizer

    override init() {
        self.speechSynthesizer = AVSpeechSynthesizer()
        super.init()
        self.speechSynthesizer.delegate = self
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Finished speaking")

        // Start recording
        speechRecognizer.reset()
        speechRecognizer.transcribe()
    }
}
