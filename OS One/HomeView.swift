//
//  HomeView.swift
//  OS One
//
//  Created by Simon Loffler on 2/4/2023.
//

import AVFoundation
import SwiftUI

var speechRecognizer = SpeechRecognizer()
var isRecording = false
var her = UserDefaults.standard.bool(forKey: "her")

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var navigate = false
    @State private var welcomeText = "Hello, how can I help?"
    @State private var showingSettingsSheet = false

    @StateObject private var speechSynthesizerManager = SpeechSynthesizerManager()
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var chatHistory = ChatHistory()

    var body: some View {
        NavigationStack {
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

                    Button("Conversations", action: {navigate = true})
                        .font(.system(
                            size: 20,
                            weight: .light
                        ))
                        .foregroundColor(.primary)
                        .buttonStyle(.bordered)
                        .navigationDestination(isPresented: $navigate) {
                            ContentView()
                        }

                    Button("Save", action: {
                        addConversation()
                    })
                        .font(.system(
                            size: 20,
                            weight: .light
                        ))
                        .foregroundColor(.secondary)
                        .buttonStyle(.bordered)

                    // TODO: silence detection instead of send button
                    Button("Send", action: {
                        speechRecognizer.stopTranscribing()
                        print("Message: \(speechRecognizer.transcript)")
                        chatHistory.addMessage(
                            speechRecognizer.transcript,
                            from: ChatMessage.Sender.user
                        )
                        chatCompletionAPI(her: her, messageHistory: chatHistory.messages) { result in
                            switch result {
                            case .success(let content):
                                chatHistory.addMessage(
                                    content,
                                    from: ChatMessage.Sender.openAI
                                )
                                sayText(text: content)
                            case .failure(let error):
                                print("OpenAI API error: \(error.localizedDescription)")
                            }
                        }
                    })
                        .font(.system(
                            size: 20,
                            weight: .light
                        ))
                        .foregroundColor(.primary)
                        .buttonStyle(.bordered)
                        .padding(.top, 40)

                    Image(systemName: "gear")
                        .font(.system(size: 20))
                        .frame(width: 40)
                        .padding(.top, 80)
                        .onTapGesture {
                            showingSettingsSheet.toggle()
                        }
                        .sheet(isPresented: $showingSettingsSheet) {
                            SettingsView()
                        }
                }
                .onAppear {
                    sayText(text: welcomeText)
                }
                .onDisappear {
                    speechRecognizer.stopTranscribing()
                    isRecording = false
                }
            }
        }
    }

    func sayText(text: String) {
        if her {
            elevenLabsTextToSpeech(text: text) { result in
                switch result {
                case .success(let data):
                    audioPlayer.playAudioFromData(data: data)
                case .failure(let error):
                    print("Eleven Labs API error: \(error.localizedDescription)")
                }
            }
        } else {
            let speechUtterance = AVSpeechUtterance(string: text)

            // Set the voice to the default system voice
            speechUtterance.voice = AVSpeechSynthesisVoice(language: nil)

            // Set the speech rate (default is AVSpeechUtteranceDefaultSpeechRate)
            speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate

            // Start the speech synthesizer
            speechSynthesizerManager.speechSynthesizer.speak(speechUtterance)
        }
        setAudioSession(active: true)
    }

    private func addConversation() {
        withAnimation {
            let newConversation = Conversation(context: viewContext)
            newConversation.timestamp = Date()

            var messages: [[String: String]] = []
            for item in chatHistory.messages {
                messages.append(
                    ["role": item.sender == ChatMessage.Sender.user ? "user" : "assistant", "content": item.message]
                )
            }
            do {
                let data = try JSONSerialization.data(withJSONObject: messages)
                newConversation.messages = String(data: data, encoding: String.Encoding.utf8)
            } catch {
                print("Failed to serialise chat history...")
            }

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
        setAudioSession(active: false)

        // Start recording
        isRecording = true
        speechRecognizer.reset()
        speechRecognizer.transcribe()
    }
}

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var audioPlayer: AVAudioPlayer?

    func playAudioFile(url: URL) {
        DispatchQueue.main.async {
            do {
                let audioData = try Data(contentsOf: url)
                self.audioPlayer = try AVAudioPlayer(data: audioData)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
            } catch {
                print("Error loading audio file: \(error.localizedDescription)")
            }
        }
    }

    func playAudioFromData(data: Data) {
        DispatchQueue.main.async {
            do {
                self.audioPlayer = try AVAudioPlayer(data: data)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.prepareToPlay()
                self.audioPlayer?.play()
            } catch {
                print("Error loading audio data: \(error.localizedDescription)")
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if !flag {
            print("Audio playback finished, but there was an issue")
        }

        // Start recording
        isRecording = true
        speechRecognizer.reset()
        speechRecognizer.transcribe()
   }
}

func setAudioSession(active: Bool) {
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(AVAudioSession.Category.playAndRecord, options: .duckOthers)
        try session.overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
        try session.setActive(active, options: .notifyOthersOnDeactivation)
    } catch {
        print("Error resetting audio session: \(error)")
    }
}
