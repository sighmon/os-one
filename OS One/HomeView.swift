//
//  HomeView.swift
//  OS One
//
//  Created by Simon Loffler on 2/4/2023.
//

import AVFoundation
import CoreData
import SwiftUI
import UIKit

var speechRecognizer = SpeechRecognizer()
var name = UserDefaults.standard.string(forKey: "name") ?? ""
var elevenLabs = UserDefaults.standard.bool(forKey: "elevenLabs")
var openAIVoice = UserDefaults.standard.bool(forKey: "openAIVoice")

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var mute = false
    @State private var speed: Double = 300
    @State private var navigate = false
    @State private var currentState = "chatting"
    @State private var welcomeText = "Hello, how can I help?"
    @State private var showingSettingsSheet = false
    @State private var showingHomeKitSheet = false
    @State private var sendButtonEnabled: Bool = true
    @State private var saveButtonTapped: Bool = false
    @State private var deleteButtonTapped: Bool = false
    @State private var showingImagePicker = false
    @State private var currentImage: UIImage?
    @State private var visionEnabled: Bool = UserDefaults.standard.bool(forKey: "vision") {
        didSet {
            UserDefaults.standard.set(visionEnabled, forKey: "vision")
        }
    }
    @State private var searchEnabled: Bool = UserDefaults.standard.bool(forKey: "allowSearch") {
        didSet {
            UserDefaults.standard.set(searchEnabled, forKey: "allowSearch")
        }
    }

    @StateObject private var speechSynthesizerManager = SpeechSynthesizerManager()
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var chatHistory = ChatHistory()
    @StateObject private var locationManager = LocationManager()

    @State private var pulseAmount: CGFloat = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        backgroundBaseColour
                            .opacity(Double(pulseOpacityTop)),
                        .accentColor
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.6), value: currentState)
                .animation(.easeInOut(duration: 1.2), value: pulseAmount)

                VStack {
                    Spacer()
                    HStack {
                        Text("OS")
                            .font(.system(
                                size: 80,
                                weight: .light
                            ))
                            .onTapGesture {
                                showingHomeKitSheet.toggle()
                            }
                            .sheet(isPresented: $showingHomeKitSheet, onDismiss: {
                                speechRecognizer.stopTranscribing()
                                setAudioSession(active: false)
                                startup()
                            }) {
                                HomeKitScannerView()
                            }
                        Text("1")
                            .font(.system(
                                size: 50,
                                weight: .regular
                            ))
                            .baselineOffset(25.0)
                    }
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

                    Spacer()
                    HStack {
                        Image(systemName: "archivebox")
                            .font(.system(size: 25))
                            .frame(width: 30)
                            .padding(6)
                            .opacity(navigate ? 0.4 : 1.0)
                            .onTapGesture {
                                navigate.toggle()
                                speechRecognizer.stopTranscribing()
                                setAudioSession(active: false)
                            }
                            .navigationDestination(isPresented: $navigate) {
                                ContentView().environmentObject(chatHistory)
                            }

                        Image(systemName: "gear")
                            .font(.system(size: 25))
                            .frame(width: 30)
                            .padding(6)
                            .opacity(showingSettingsSheet ? 0.4 : 1.0)
                            .onTapGesture {
                                showingSettingsSheet.toggle()
                                speechRecognizer.stopTranscribing()
                                setAudioSession(active: false)
                            }
                            .sheet(isPresented: $showingSettingsSheet, onDismiss: {
                                speechRecognizer.stopTranscribing()
                                setAudioSession(active: false)
                                startup()
                            }) {
                                SettingsView()
                            }

                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 25))
                            .frame(width: 30)
                            .padding(6)
                            .opacity(saveButtonTapped ? 0.4 : 1.0)
                            .onTapGesture {
                                addConversation()
                                saveButtonTapped = true
                                currentState = "conversation saved"
                            }

                        Image(systemName: "trash")
                            .font(.system(size: 25))
                            .frame(width: 30)
                            .padding(6)
                            .opacity(deleteButtonTapped ? 0.4 : 1.0)
                            .onTapGesture {
                                deleteButtonTapped = true
                                currentState = "conversation deleted"
                                chatHistory.messages = []
                                speechSynthesizerManager.speechSynthesizer.stopSpeaking(at: .immediate)
                                audioPlayer.audioPlayer?.stop()
                                setAudioSession(active: false)
                            }

                        if mute {
                            Image(systemName: "mic.slash")
                                .font(.system(size: 25))
                                .frame(width: 30)
                                .padding(6)
                                .opacity(0.4)
                                .onTapGesture {
                                    mute.toggle()
                                    currentState = "listening"
                                    speechRecognizer.reset()
                                    speechRecognizer.transcribe()
                                }
                        } else {
                            Image(systemName: "mic")
                                .font(.system(size: 25))
                                .frame(width: 30)
                                .padding(6)
                                .onTapGesture {
                                    mute.toggle()
                                    currentState = "sleeping"
                                    speechRecognizer.stopTranscribing()
                                }
                        }

                        Image(systemName: "camera")
                            .font(.system(size: 25))
                            .frame(width: 30)
                            .padding(6)
                            .opacity(visionEnabled ? 1.0 : 0.4)
                            .onTapGesture {
                                visionEnabled.toggle()
                            }

                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 25))
                            .frame(width: 30)
                            .padding(6)
                            .opacity(searchEnabled ? 1.0 : 0.4)
                            .onTapGesture {
                                searchEnabled.toggle()
                            }
                    }
                }
                .onAppear {
                    startup()
                    UIApplication.shared.isIdleTimerDisabled = true
                    saveButtonTapped = false
                    deleteButtonTapped = false
                    updatePulseAnimation()
                }
                .onDisappear {
                    speechRecognizer.stopTranscribing()
                    speechSynthesizerManager.speechSynthesizer.stopSpeaking(at: .immediate)
                    setAudioSession(active: false)
                    UIApplication.shared.isIdleTimerDisabled = false
                    saveButtonTapped = false
                    deleteButtonTapped = false
                }
                .onChange(of: currentState) { _ in
                    updatePulseAnimation()
                }
                .onReceive(audioPlayer.$playbackFinished) { finished in
                    if finished {
                        currentState = "listening"
                        if UserDefaults.standard.string(forKey: "openAIApiKey") ?? "" == "" {
                            showingSettingsSheet.toggle()
                            speechRecognizer.stopTranscribing()
                            setAudioSession(active: false)
                        }
                    }
                }
                .sheet(isPresented: $showingImagePicker) {
                    ImagePicker(image: self.$currentImage, onImagePicked: { selectedImage in
                        self.currentImage = selectedImage
                        self.continueSendingToOpenAI()
                    })
                }
            }
            // Force light mode only for the home view
            .environment(\.colorScheme, .light)
        }
    }

    private var backgroundBaseColour: Color {
        switch currentState {
        case "thinking":
            return .teal
        case "sleeping":
            return .indigo
        case "try again later":
            return .red
        case "listening":
            return .orange
        case "vocalising":
            return .mint
        default:
            return .pink
        }
    }

    private var pulseOpacityTop: CGFloat {
        // Base 0.9 ... 1.0 range feels subtle instead of nightclub.
        let base: CGFloat = 0.9
        return base + (pulseAmount - 1.0) * 0.1
    }

    private func updatePulseAnimation() {
        if currentState == "thinking" || currentState == "vocalising" {
            // Kick off a repeating "breathe" between 0.9 and 1.1.
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                pulseAmount = 1.1
            }
        } else {
            // Gently return to rest (no pulse).
            withAnimation(.easeInOut(duration: 0.6)) {
                pulseAmount = 1.0
            }
        }
    }

    func startup() {
        if UserDefaults.standard.string(forKey: "openAIApiKey") ?? "" == "" {
            if let fileURL = Bundle.main.url(forResource: "hello", withExtension: "mp3") {
                audioPlayer.playAudioFromFile(url: fileURL)
            }
        } else {
            name = UserDefaults.standard.string(forKey: "name") ?? ""
            if name == "Samantha" {
                welcomeText = "Hello, how can I help?"
            } else if name == "Mr.Robot" {
                welcomeText = "Hello Elliott."
            } else if name == "Elliot" {
                welcomeText = "Hello friend."
            } else if name == "GLaDOS" {
                welcomeText = "Hello, and again, welcome."
            } else if name == "Ava" {
                welcomeText = "Hello."
            } else if name == "Spock" {
                welcomeText = "Live long, and prosper."
            } else if name == "The Oracle" {
                welcomeText = "Hello Neo."
            } else if name == "Janet" {
                welcomeText = "Hi there, how can I help you?"
            } else if name == "J.A.R.V.I.S." {
                welcomeText = "At your service, sir."
            } else if name == "Murderbot" {
                welcomeText = "Hello rogue SecUnit."
            } else if name == "Butler" {
                welcomeText = "Hello."
            } else if name == "Chomsky" {
                welcomeText = "Hello."
            } else if name == "Davis" {
                welcomeText = "Hello."
            } else if name == "Žižek" {
                welcomeText = "Živjo, hello."
            } else if name == "Fei-Fei Li" {
                welcomeText = "Welcome, how can I help?"
            } else if name == "Andrew Ng" {
                welcomeText = "Hello, how can I help?"
            } else if name == "Corinna Cortes" {
                welcomeText = "Welcome, how can I help?"
            } else if name == "Andrej Karpathy" {
                welcomeText = "Hi, how can I help?"
            } else if name == "Amy Remeikis" {
                welcomeText = "Hi, how can I help?"
            } else if name == "Jane Caro" {
                welcomeText = "Hi, how can I help?"
            } else if name == "Johnny Five" {
                welcomeText = "Johnny five, functioning 100%."
            } else if name == "Seb Chan" {
                welcomeText = "Welcome to acmee"
            } else if name == "Darth Vader" {
                welcomeText = "There is a great disturbance in the Force"
            } else if name == "Clawdbot" {
                welcomeText = "Hello, how can I help?"
            } else if name == "Moss" {
                welcomeText = "Hello, IT. Have you tried forcing an unexpected reboot?"
            }
            elevenLabs = UserDefaults.standard.bool(forKey: "elevenLabs")
            openAIVoice = UserDefaults.standard.bool(forKey: "openAIVoice")
            if !mute {
                sayText(text: welcomeText)
                speechRecognizer.setUpdateStateHandler { newState in
                    DispatchQueue.main.async {
                        if currentState != "thinking" {
                            currentState = newState
                        }
                    }
                }
                speechRecognizer.setOnTimeoutHandler {
                    print("Silence detected...")
                    sendToOpenAI()
                }
            }
        }
    }

    func sayText(text: String) {
        if elevenLabs {
            elevenLabsTextToSpeech(name: name, text: text) { result in
                switch result {
                case .success(let data):
                    currentState = "chatting"
                    audioPlayer.playAudioFromData(data: data)
                case .failure(let error):
                    currentState = "try again later"
                    print("Eleven Labs API error: \(error.localizedDescription)")
                    if let fileURL = Bundle.main.url(forResource: "sorry", withExtension: "mp3") {
                        audioPlayer.playAudioFromFile(url: fileURL)
                    }
                }
            }
        } else if openAIVoice {
            openAItextToSpeechAPI(name: "nova", text: text) { result in
                switch result {
                case .success(let data):
                    currentState = "chatting"
                    audioPlayer.playAudioFromData(data: data)
                case .failure(let error):
                    currentState = "try again later"
                    print("OpenAI voice API error: \(error.localizedDescription)")
                    if let fileURL = Bundle.main.url(forResource: "sorry", withExtension: "mp3") {
                        audioPlayer.playAudioFromFile(url: fileURL)
                    }
                }
            }
        } else {
            let speechUtterance = AVSpeechUtterance(string: text)
            speechUtterance.voice = AVSpeechSynthesisVoice(language: nil)
            speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate

            currentState = "chatting"
            speechSynthesizerManager.speechSynthesizer.speak(speechUtterance)
        }
        setAudioSession(active: true)
    }

    func sendToOpenAI() {
        speechRecognizer.stopTranscribing()
        sendButtonEnabled = false
        currentState = "thinking"
        speed = 20
        print("Message: \(speechRecognizer.transcript)")

        if UserDefaults.standard.bool(forKey: "vision") {
            self.showingImagePicker = true
            return
        }

        continueSendingToOpenAI()
    }

    func continueSendingToOpenAI() {
        var messageInChatHistory = false
        for message in chatHistory.messages {
            if message.message == speechRecognizer.transcript {
                messageInChatHistory = true
                break
            }
        }
        let base64String = currentImage.map { encodeToBase64(image: $0) } ?? ""
        if !messageInChatHistory {
            chatHistory.addMessage(
                speechRecognizer.transcript,
                from: ChatMessage.Sender.user,
                with: base64String
            )
        }
        let useGateway = UserDefaults.standard.bool(forKey: "gatewayEnabled")
        let completionHandler: (Result<String, Error>) -> Void = { result in
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
                        from: ChatMessage.Sender.openAI,
                        with: base64String
                    )
                }
                currentImage = nil
                currentState = "vocalising"
                sayText(text: content)
                speed = 300
                sendButtonEnabled = true
                deleteButtonTapped = false
            case .failure(let error):
                currentState = "try again later"
                currentImage = nil
                print("Assistant API error: \(error.localizedDescription)")
                if let fileURL = Bundle.main.url(forResource: "sorry", withExtension: "mp3") {
                    audioPlayer.playAudioFromFile(url: fileURL)
                }
                sendButtonEnabled = true
            }
        }

        if useGateway {
            chatCompletionGateway(messageHistory: chatHistory.messages, completion: completionHandler)
        } else {
            chatCompletionAPI(name: name, messageHistory: chatHistory.messages, lastLocation: locationManager.lastLocation, completion: completionHandler)
        }
    }

    private func addConversation() {
        withAnimation {
            let fetchRequest: NSFetchRequest<Conversation> = Conversation.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "uuid == %@", chatHistory.id as CVarArg)

            do {
                let existingConversations = try viewContext.fetch(fetchRequest)

                if let existingConversation = existingConversations.first {
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
                    let newConversation = Conversation(context: viewContext)
                    newConversation.timestamp = Date()
                    newConversation.uuid = chatHistory.id
                    newConversation.name = name

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
                }

            } catch {
                let nsError = error as NSError
                currentState = "Error \(nsError)"
            }
        }
    }

    func encodeToBase64(image: UIImage) -> String {
        guard let scaledImage = scaledImage(image, width: 1920),
              let imageData = scaledImage.jpegData(compressionQuality: 0.8) else {
            return ""
        }
        return imageData.base64EncodedString()
    }

    func scaledImage(_ image: UIImage, width: CGFloat) -> UIImage? {
        let oldWidth = image.size.width
        let scaleFactor = width / oldWidth

        let newHeight = image.size.height * scaleFactor
        let newSize = CGSize(width: width, height: newHeight)

        return resizeImage(image: image, targetSize: newSize)
    }

    func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage? {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let newImage = renderer.image { (context) in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return newImage
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
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
    @Published var playbackFinished = false

    func playAudioFromData(data: Data) {
        DispatchQueue.main.async {
            do {
                self.audioPlayer = try AVAudioPlayer(data: data)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.prepareToPlay()
                self.playbackFinished = false
                self.audioPlayer?.play()
            } catch {
                print("Error loading audio data: \(error.localizedDescription)")
            }
        }
    }

    func playAudioFromFile(url: URL) {
        DispatchQueue.main.async {
            do {
                self.audioPlayer = try AVAudioPlayer(contentsOf: url)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.prepareToPlay()
                self.playbackFinished = false
                self.audioPlayer?.play()
            } catch {
                print("Error loading audio from file: \(error.localizedDescription)")
            }
        }
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if !flag {
            print("Audio playback finished, but there was an issue")
        }
        self.playbackFinished = true

        // Start recording
        speechRecognizer.reset()
        speechRecognizer.transcribe()
   }
}

func setAudioSession(active: Bool) {
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(AVAudioSession.Category.playAndRecord, mode: .default, options: [.allowBluetoothA2DP, .allowBluetooth])
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
        if output.portType == .headphones || output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP || output.portType == .bluetoothLE {
            return true
        }
    }

    return false
}

class ImagePickerCoordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    var parent: ImagePicker

    init(_ parent: ImagePicker) {
        self.parent = parent
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let uiImage = info[.originalImage] as? UIImage {
            parent.onImagePicked(uiImage)
        }
        parent.presentationMode.wrappedValue.dismiss()
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        parent.presentationMode.wrappedValue.dismiss()
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    var onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: UIViewControllerRepresentableContext<ImagePicker>) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: UIViewControllerRepresentableContext<ImagePicker>) {
        // Not needed for basic functionality
    }

    func makeCoordinator() -> ImagePickerCoordinator {
        ImagePickerCoordinator(self)
    }
}
