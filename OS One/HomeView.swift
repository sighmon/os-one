//
//  HomeView.swift
//  OS One
//
//  Created by Simon Loffler on 2/4/2023.
//

import AVFoundation
import CoreData
import SwiftUI

var speechRecognizer = SpeechRecognizer()
var name = UserDefaults.standard.string(forKey: "name") ?? ""
var elevenLabs = UserDefaults.standard.bool(forKey: "elevenLabs")

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var mute = false
    @State private var navigate = false
    @State private var currentState = "chatting"
    @State private var welcomeText = "Hello, how can I help?"
    @State private var showingSettingsSheet = false
    @State private var sendButtonEnabled: Bool = true

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
                            size: 80,
                            weight: .light
                        ))
                        .padding(.bottom, 1)
                    ScrollView {
                        Text(currentState)
                            .font(.system(
                                size: 20,
                                weight: .light
                            ))
                            .padding([.leading, .trailing], 60)
                            .textSelection(.enabled)
                            .onTapGesture {
                                currentState = "listening"
                                speechRecognizer.stopTranscribing()
                                speechRecognizer.reset()
                                speechRecognizer.transcribe()
                            }
                    }
                        .frame(height: 100)
                        .padding(.bottom, 20)

                    HStack {
                        Image(systemName: "archivebox")
                            .font(.system(size: 30))
                            .frame(width: 40)
                            .padding(10)
                            .onTapGesture {
                                navigate.toggle()
                            }
                            .navigationDestination(isPresented: $navigate) {
                                ContentView()
                            }

                        Image(systemName: "gear")
                            .font(.system(size: 30))
                            .frame(width: 40)
                            .padding(10)
                            .onTapGesture {
                                showingSettingsSheet.toggle()
                            }
                            .sheet(isPresented: $showingSettingsSheet, onDismiss: {
                                speechRecognizer.stopTranscribing()
                                setAudioSession(active: false)
                                startup()
                            }) {
                                SettingsView()
                            }

                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 30))
                            .frame(width: 40)
                            .padding(10)
                            .onTapGesture {
                                addConversation()
                                currentState = "conversation saved"
                            }

                        if mute {
                            Image(systemName: "mic.slash")
                                .font(.system(size: 30))
                                .frame(width: 40)
                                .padding(10)
                                .onTapGesture {
                                    mute.toggle()
                                    currentState = "listening"
                                    speechRecognizer.reset()
                                    speechRecognizer.transcribe()
                                }
                        } else {
                            Image(systemName: "mic")
                                .font(.system(size: 30))
                                .frame(width: 40)
                                .padding(10)
                                .onTapGesture {
                                    mute.toggle()
                                    currentState = "sleeping"
                                    speechRecognizer.stopTranscribing()
                                }
                        }
                    }

                    Image(systemName: "arrow.up.circle")
                        .font(.system(size: 80, weight: .light))
                        .frame(width: 40)
                        .padding(.top, 60)
                        .onTapGesture {
                            sendToOpenAI()
                        }
                        .font(.system(
                            size: 20,
                            weight: .light
                        ))
                        .foregroundColor(.primary)
                        .buttonStyle(.bordered)
                        .padding(.top, 40)
                        .disabled(!sendButtonEnabled)
                        .opacity(sendButtonEnabled ? 1.0 : 0.2)
                }
                .onAppear {
                    startup()
                    UIApplication.shared.isIdleTimerDisabled = true
                }
                .onDisappear {
                    speechRecognizer.stopTranscribing()
                    setAudioSession(active: false)
                    UIApplication.shared.isIdleTimerDisabled = false
                }
            }
        }
    }

    func startup() {
        name = UserDefaults.standard.string(forKey: "name") ?? ""
        if name == "mrrobot" {
            welcomeText = "Hello Elliott."
        } else if name == "elliot" {
            welcomeText = "Hello friend."
        } else if name == "glados" {
            welcomeText = "Hello, and again, welcome."
        } else if name == "spock" {
            welcomeText = "Live long, and prosper."
        } else if name == "oracle" {
            welcomeText = "Hello Neo."
        }
        elevenLabs = UserDefaults.standard.bool(forKey: "elevenLabs")
        if !mute {
            sayText(text: welcomeText)
            speechRecognizer.setUpdateStateHandler { newState in
                DispatchQueue.main.async {
                    currentState = newState
                }
            }
            speechRecognizer.setOnTimeoutHandler {
                print("Silence detected...")
                sendToOpenAI()
            }
        }
    }

    func sayText(text: String) {
        if elevenLabs {
            elevenLabsTextToSpeech(name: name, text: text) { result in
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

    func sendToOpenAI() {
        speechRecognizer.stopTranscribing()
        sendButtonEnabled = false
        currentState = "thinking"
        print("Message: \(speechRecognizer.transcript)")
        var messageInChatHistory = false
        for message in chatHistory.messages {
            if message.message == speechRecognizer.transcript {
                messageInChatHistory = true
                break
            }
        }
        if !messageInChatHistory {
            chatHistory.addMessage(
                speechRecognizer.transcript,
                from: ChatMessage.Sender.user
            )
        }
        chatCompletionAPI(name: name, messageHistory: chatHistory.messages) { result in
            switch result {
            case .success(let content):
                var messageInChatHistory = false
                for message in chatHistory.messages {
                    if message.message == content {
                        messageInChatHistory = true
                        break
                    }
                }
                if !messageInChatHistory {
                    chatHistory.addMessage(
                        content,
                        from: ChatMessage.Sender.openAI
                    )
                }
                sayText(text: content)
                currentState = "chatting"
                sendButtonEnabled = true
            case .failure(let error):
                currentState = "try again later"
                print("OpenAI API error: \(error.localizedDescription)")
                sendButtonEnabled = true
            }
        }
    }

    private func addConversation() {
        withAnimation {
            // Check if the record exists in Core Data
            let fetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "uuid == %@", chatHistory.id as CVarArg)

            do {
                let existingConversations = try viewContext.fetch(fetchRequest)

                if let existingConversation = existingConversations.first {
                    // Update the existing conversation
                    existingConversation.timestamp = Date()
                    
                    var messages: [String] = []
                    for message in chatHistory.messages {
                        messages.append(
                            serialize(chatMessage: message) ?? "I failed, sorry."
                        )
                    }
                    do {
                        let data = try JSONSerialization.data(withJSONObject: messages)
                        existingConversation.messages = String(data: data, encoding: String.Encoding.utf8)
                    } catch {
                        print("Failed to serialise chat history...")
                    }
                } else {
                    // Create a new conversation
                    let newConversation = Conversation(context: viewContext)
                    newConversation.timestamp = Date()
                    newConversation.uuid = chatHistory.id

                    var messages: [String] = []
                    for message in chatHistory.messages {
                        messages.append(
                            serialize(chatMessage: message) ?? "I failed, sorry."
                        )
                    }
                    do {
                        let data = try JSONSerialization.data(withJSONObject: messages)
                        newConversation.messages = String(data: data, encoding: String.Encoding.utf8)
                    } catch {
                        print("Failed to serialise chat history...")
                    }
                }

                do {
                    try viewContext.save()
                } catch {
                    let nsError = error as NSError
                    currentState = "Error \(nsError)"
                    // fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                }

            } catch {
                let nsError = error as NSError
                currentState = "Error \(nsError)"
                // fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
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
        speechRecognizer.reset()
        speechRecognizer.transcribe()
    }
}

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var audioPlayer: AVAudioPlayer?

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
        speechRecognizer.reset()
        speechRecognizer.transcribe()
   }
}

func setAudioSession(active: Bool) {
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(AVAudioSession.Category.playAndRecord, mode: .default, options: .allowBluetooth)
        if isDeviceAniPhone() && !areHeadphonesConnected() {
            try session.overrideOutputAudioPort(.speaker)
        } else {
            try session.overrideOutputAudioPort(.none)
        }
        try session.setActive(active, options: .notifyOthersOnDeactivation)
    } catch {
        print("Error resetting audio session: \(error)")
    }
}

func isDeviceAniPhone() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .phone
}

func areHeadphonesConnected() -> Bool {
    let audioSession = AVAudioSession.sharedInstance()
    let outputs = audioSession.currentRoute.outputs

    for output in outputs {
        if output.portType == .headphones || output.portType == .bluetoothA2DP {
            return true
        }
    }

    return false
}
