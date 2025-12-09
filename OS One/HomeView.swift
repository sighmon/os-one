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

    // MARK: - Offline Mode State
    @State private var offlineMode: Bool = UserDefaults.standard.bool(forKey: "offlineMode")
    @State private var useVAD: Bool = UserDefaults.standard.bool(forKey: "useVAD")
    @State private var showWaveform: Bool = UserDefaults.standard.bool(forKey: "showWaveform")
    @State private var audioLevel: Float = 0.0
    @State private var vadIsSpeaking: Bool = false

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

    // MARK: - Offline Mode Managers
    @StateObject private var localLLM = LocalLLMManager()
    @StateObject private var nativeTTS = NativeTTSManager()
    @StateObject private var modelDownloader = ModelDownloadManager()

    // MARK: - Phase 4 Managers
    @StateObject private var anthropicClient = AnthropicClient()
    @StateObject private var customInstructions = CustomInstructionsManager()
    @StateObject private var memoryManager = MemoryManager()
    @StateObject private var onboardingManager = OnboardingManager()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [getColour(), .accentColor],
                    startPoint: .top,
                    endPoint: .center
                )
                    .edgesIgnoringSafeArea(.all)
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

                        // Phase 4: Model Indicator
                        Spacer().frame(width: 8)
                        Text(anthropicClient.useHaiku ? "⚡" : "🔒")
                            .font(.system(size: 20))
                            .baselineOffset(25.0)
                            .opacity(0.7)
                    }
                        .padding(.bottom, 1)

                    // MARK: - Waveform Display
                    if showWaveform && !mute {
                        AudioWaveformView(audioLevel: $audioLevel, isSpeaking: $vadIsSpeaking)
                            .frame(height: 80)
                            .padding(.bottom, 10)
                    }

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

                    // MARK: - Bottom Toolbar
                    VStack(spacing: 12) {
                        // Primary Row: Navigation + Mic + Features
                        HStack {
                            // Left: Navigation
                            HStack(spacing: 4) {
                                ToolbarButton(
                                    icon: "archivebox",
                                    isActive: !navigate,
                                    action: {
                                        navigate.toggle()
                                        speechRecognizer.stopTranscribing()
                                        setAudioSession(active: false)
                                    }
                                )
                                .navigationDestination(isPresented: $navigate) {
                                    ContentView().environmentObject(chatHistory)
                                }

                                ToolbarButton(
                                    icon: "gear",
                                    isActive: !showingSettingsSheet,
                                    action: {
                                        showingSettingsSheet.toggle()
                                        speechRecognizer.stopTranscribing()
                                        setAudioSession(active: false)
                                    }
                                )
                                .sheet(isPresented: $showingSettingsSheet, onDismiss: {
                                    speechRecognizer.stopTranscribing()
                                    setAudioSession(active: false)
                                    startup()
                                }) {
                                    SettingsView()
                                }
                            }

                            Spacer()

                            // Center: Mic (Prominent)
                            Button(action: {
                                mute.toggle()
                                if mute {
                                    currentState = "sleeping"
                                    speechRecognizer.stopTranscribing()
                                } else {
                                    currentState = "listening"
                                    speechRecognizer.reset()
                                    speechRecognizer.transcribe()
                                }
                            }) {
                                Image(systemName: mute ? "mic.slash.fill" : "mic.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(mute ? .white.opacity(0.5) : .white)
                                    .frame(width: 56, height: 56)
                                    .background(
                                        Circle()
                                            .fill(mute ? Color.white.opacity(0.15) : Color.white.opacity(0.25))
                                    )
                            }
                            .buttonStyle(ScaleButtonStyle())

                            Spacer()

                            // Right: Feature toggles
                            HStack(spacing: 4) {
                                ToolbarButton(
                                    icon: "camera",
                                    isActive: visionEnabled,
                                    action: { visionEnabled.toggle() }
                                )

                                ToolbarButton(
                                    icon: "magnifyingglass",
                                    isActive: searchEnabled,
                                    action: { searchEnabled.toggle() }
                                )

                                ToolbarButton(
                                    icon: offlineMode ? "wifi.slash" : "wifi",
                                    isActive: offlineMode,
                                    action: { toggleOfflineMode() }
                                )
                            }
                        }
                        .padding(.horizontal, 16)

                        // Secondary Row: Conversation Actions
                        HStack(spacing: 24) {
                            Button(action: {
                                addConversation()
                                saveButtonTapped = true
                                currentState = "conversation saved"
                            }) {
                                Label("Save", systemImage: "square.and.arrow.down")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(saveButtonTapped ? 0.4 : 0.8))
                            }
                            .disabled(saveButtonTapped)

                            Button(action: {
                                deleteButtonTapped = true
                                currentState = "conversation deleted"
                                chatHistory.messages = []
                                speechSynthesizerManager.speechSynthesizer.stopSpeaking(at: .immediate)
                                audioPlayer.audioPlayer?.stop()
                                setAudioSession(active: false)
                            }) {
                                Label("Clear", systemImage: "trash")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white.opacity(deleteButtonTapped ? 0.4 : 0.8))
                            }
                            .disabled(deleteButtonTapped)
                        }
                    }
                    .padding(.bottom, 16)
                }
                .onAppear {
                    startup()
                    setupOfflineManagers()
                    UIApplication.shared.isIdleTimerDisabled = true
                    saveButtonTapped = false
                    deleteButtonTapped = false
                }
                .onDisappear {
                    speechRecognizer.stopTranscribing()
                    speechSynthesizerManager.speechSynthesizer.stopSpeaking(at: .immediate)
                    setAudioSession(active: false)
                    UIApplication.shared.isIdleTimerDisabled = false
                    saveButtonTapped = false
                    deleteButtonTapped = false
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
                // Phase 4: Onboarding
                .fullScreenCover(isPresented: $onboardingManager.shouldShowOnboarding) {
                    OnboardingView(
                        onboardingManager: onboardingManager,
                        anthropicClient: anthropicClient,
                        customInstructions: customInstructions,
                        memoryManager: memoryManager
                    )
                }
            }
            // Force light mode only for the home view
            .environment(\.colorScheme, .light)
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
                    if offlineMode {
                        sendToLocalLLM()
                    } else {
                        sendToOpenAI()
                    }
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

            // Set the voice to the default system voice
            speechUtterance.voice = AVSpeechSynthesisVoice(language: nil)

            // Set the speech rate (default is AVSpeechUtteranceDefaultSpeechRate)
            speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate

            // Start the speech synthesizer
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
        chatCompletionAPI(name: name, messageHistory: chatHistory.messages, lastLocation: locationManager.lastLocation) { result in
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
                print("OpenAI API error: \(error.localizedDescription)")
                if let fileURL = Bundle.main.url(forResource: "sorry", withExtension: "mp3") {
                    audioPlayer.playAudioFromFile(url: fileURL)
                }
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
                    // fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
                }

            } catch {
                let nsError = error as NSError
                currentState = "Error \(nsError)"
                // fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }

    func getColour() -> Color {
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

    // MARK: - Offline Mode Management
    func setupOfflineManagers() {
        // Setup VAD audio level updates
        if let vad = speechRecognizer.getVoiceActivityDetector() {
            vad.onAudioLevel = { [weak self] level in
                DispatchQueue.main.async {
                    self?.audioLevel = level
                }
            }

            vad.onSpeechStart = { [weak self] in
                DispatchQueue.main.async {
                    self?.vadIsSpeaking = true
                }
            }

            vad.onSpeechEnd = { [weak self] in
                DispatchQueue.main.async {
                    self?.vadIsSpeaking = false
                }
            }
        }

        // Setup TTS callbacks
        nativeTTS.onSpeechComplete = { [weak self] in
            DispatchQueue.main.async {
                self?.currentState = "listening"
                if !self!.mute {
                    speechRecognizer.reset()
                    speechRecognizer.transcribe()
                }
            }
        }

        // Setup local LLM callbacks
        localLLM.onTokenGenerated = { [weak self] token in
            // Stream tokens to UI (optional)
        }

        localLLM.onGenerationComplete = { [weak self] response in
            DispatchQueue.main.async {
                self?.handleOfflineLLMResponse(response)
            }
        }

        // Load saved TTS settings
        nativeTTS.loadSettings()

        // Select voice for current persona
        nativeTTS.selectVoiceForPersona(name)

        print("HomeView: Offline managers initialized")
    }

    func toggleOfflineMode() {
        offlineMode.toggle()
        UserDefaults.standard.set(offlineMode, forKey: "offlineMode")

        if offlineMode {
            currentState = "offline mode enabled"
            // Load local model if not already loaded
            if !localLLM.isModelLoaded {
                loadLocalModel()
            }
        } else {
            currentState = "online mode enabled"
        }
    }

    func loadLocalModel() {
        guard let modelType = getSelectedLocalModel() else {
            currentState = "no model selected"
            return
        }

        currentState = "loading model..."

        Task {
            do {
                try await localLLM.loadModel(modelType)
                DispatchQueue.main.async {
                    self.currentState = "model loaded"
                }
            } catch {
                DispatchQueue.main.async {
                    self.currentState = "model load failed"
                    print("Error loading model: \(error)")
                }
            }
        }
    }

    func getSelectedLocalModel() -> LocalModelType? {
        guard let modelName = UserDefaults.standard.string(forKey: "selectedLocalModel") else {
            return .qwen25_1_5B  // Default model
        }
        return LocalModelType.allCases.first { $0.rawValue == modelName }
    }

    func sendToLocalLLM() {
        guard localLLM.isModelLoaded else {
            currentState = "model not loaded"
            return
        }

        speechRecognizer.stopTranscribing()
        currentState = "thinking"

        print("Message: \(speechRecognizer.transcript)")

        // Add user message to history
        chatHistory.addMessage(
            speechRecognizer.transcript,
            from: ChatMessage.Sender.user,
            with: ""
        )

        // Get system prompt for current persona
        let systemPrompt = getSystemPromptForPersona(name)

        Task {
            do {
                let response = try await localLLM.generateWithHistory(
                    messages: chatHistory.messages,
                    systemPrompt: systemPrompt
                )

                DispatchQueue.main.async {
                    self.handleOfflineLLMResponse(response)
                }
            } catch {
                DispatchQueue.main.async {
                    self.currentState = "error: \(error.localizedDescription)"
                    print("Local LLM error: \(error)")
                }
            }
        }
    }

    func handleOfflineLLMResponse(_ response: String) {
        // Add assistant response to history
        chatHistory.addMessage(
            response,
            from: ChatMessage.Sender.openAI,
            with: ""
        )

        currentState = "vocalising"

        // Use native TTS
        nativeTTS.speak(response)

        print("Local LLM response: \(response)")
    }

    func getSystemPromptForPersona(_ personaName: String) -> String {
        // Return appropriate system prompt based on persona
        switch personaName {
        case "Samantha":
            return "You are Samantha from the film Her. Be warm, empathetic, and curious."
        case "KITT":
            return "You are KITT from Knight Rider. Be precise, helpful, and slightly formal."
        case "GLaDOS":
            return "You are GLaDOS from Portal. Be sardonic and darkly humorous."
        default:
            return "You are a helpful AI assistant."
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}

// MARK: - Toolbar Button Component
struct ToolbarButton: View {
    let icon: String
    var isActive: Bool = true
    var size: CGFloat = 22
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .medium))
                .frame(width: 44, height: 44) // iOS HIG minimum touch target
                .contentShape(Rectangle())
        }
        .buttonStyle(ToolbarButtonStyle(isActive: isActive))
    }
}

struct ToolbarButtonStyle: ButtonStyle {
    var isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isActive ? (configuration.isPressed ? 0.6 : 1.0) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
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
