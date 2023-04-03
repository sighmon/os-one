//
//  HomeView.swift
//  ChatGPT Voice
//
//  Created by Simon Loffler on 2/4/2023.
//

import AVFoundation
import SwiftUI

var speechRecognizer = SpeechRecognizer()
var isRecording = false

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var navigate = false
    @State private var her = true
    @State private var text = "Hello, how can I help?"
    @State private var showingSettingsSheet = false

    @StateObject private var speechSynthesizerManager = SpeechSynthesizerManager()
    @StateObject private var audioPlayer = AudioPlayer()

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
                    sayText(text: text)
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
                    print("Error: \(error.localizedDescription)")
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
        isRecording = true
        speechRecognizer.reset()
        speechRecognizer.transcribe()
    }
}

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var audioPlayer: AVAudioPlayer?

    func playAudioFile(url: URL) {
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

    func playAudioFromData(data: Data) {
        do {
            self.audioPlayer = try AVAudioPlayer(data: data)
            self.audioPlayer?.delegate = self
            self.audioPlayer?.prepareToPlay()
            self.audioPlayer?.play()
        } catch {
            print("Error loading audio data: \(error.localizedDescription)")
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            print("Audio playback finished successfully")
        } else {
            print("Audio playback finished, but there was an issue")
        }

        // Start recording
        isRecording = true
        speechRecognizer.reset()
        speechRecognizer.transcribe()
   }
}
