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
var name = UserDefaults.standard.string(forKey: "name") ?? "Samantha"
var elevenLabs = UserDefaults.standard.bool(forKey: "elevenLabs")
var openAIVoice = UserDefaults.standard.bool(forKey: "openAIVoice")

struct HomeView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var camera = LiveCamera()
    @State private var assistantError: String?

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
    @State private var currentImage: UIImage?
    @State private var pendingTranscript: String = ""
    @State private var liveTranscript: String = ""
    @State private var liveWordIndex: Int = 0
    @State private var responseText: String = ""
    @State private var responseWordIndex: Int = 0
    @State private var responseWords: [Substring] = []
    @State private var responseWordTimings: [WordTiming] = []
    @State private var responsePlaybackTime: Double = 0
    @State private var useSystemSpeechHighlighting = false
    @State private var lastResponseAudioData: Data?
    @State private var lastResponseTimings: [WordTiming] = []
    @State private var lastResponseText: String = ""
    @State private var previousState: String = ""
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

                if visionEnabled && AssistantProvider.current.supportsCamera {
                    CameraPreview(session: camera.session).ignoresSafeArea()
                    Color.white.opacity(0.35).ignoresSafeArea().allowsHitTesting(false)
                }

                VStack {
                    Spacer()
                    HStack {
                        Text("OS")
                            .font(.system(
                                size: 80,
                                weight: .light
                            ))
                            .padding(.top, 20)
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

                    VStack(spacing: 24) {
                        Text(statusLabel)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primary.opacity(0.3))
                            .padding(.bottom, 4)

                        TranscriptCardView(
                            title: activeTranscriptTitle,
                            text: activeTranscriptText,
                            highlightedWordIndex: activeTranscriptHighlightIndex,
                            timings: activeTranscriptTimings,
                            currentTime: activeTranscriptTime
                        )
                        .frame(maxWidth: UIScreen.main.bounds.width * 0.8, maxHeight: .infinity)
                        .onTapGesture {
                            if isShowingResponse {
                                replayLastResponse()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 28)
                    .textSelection(.enabled)
                    .onTapGesture {
                        guard !isShowingResponse else { return }
                        currentState = "listening"
                        speechRecognizer.stopTranscribing()
                        speechRecognizer.reset()
                        speechRecognizer.transcribe()
                    }
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
                            .accessibilityIdentifier("settingsButton")
                            .accessibilityLabel("Settings")
                            .accessibilityAddTraits(.isButton)
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
                                liveTranscript = ""
                                responseText = ""
                                responseWords = []
                                responseWordIndex = 0
                                responseWordTimings = []
                                responsePlaybackTime = 0
                                lastResponseAudioData = nil
                                lastResponseTimings = []
                                lastResponseText = ""
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
                                guard AssistantProvider.current.supportsCamera else {
                                    assistantError = "Camera analysis requires OpenAI or xAI. Choose a provider in Models."
                                    return
                                }
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
                    updateCamera()
                    UIApplication.shared.isIdleTimerDisabled = true
                    saveButtonTapped = false
                    deleteButtonTapped = false
                    updatePulseAnimation()
                }
                .onDisappear {
                    camera.stop()
                    speechRecognizer.stopTranscribing()
                    speechSynthesizerManager.speechSynthesizer.stopSpeaking(at: .immediate)
                    setAudioSession(active: false)
                    UIApplication.shared.isIdleTimerDisabled = false
                    saveButtonTapped = false
                    deleteButtonTapped = false
                }
                .onChange(of: currentState) { newState in
                    updatePulseAnimation()
                    if newState == "listening", previousState != "listening" {
                        liveTranscript = ""
                        liveWordIndex = 0
                    }
                    previousState = newState
                }
                .onReceive(audioPlayer.$playbackFinished) { finished in
                    if finished {
                        if !AssistantProvider.current.isConfigured {
                            showingSettingsSheet = true
                            speechRecognizer.stopTranscribing()
                            setAudioSession(active: false)
                        } else {
                            resumeListening()
                        }
                    }
                }
                .onReceive(speechSynthesizerManager.$playbackFinished) { finished in
                    if finished { resumeListening() }
                }
                .onReceive(audioPlayer.$playbackProgress) { progress in
                    guard currentState == "vocalising" else { return }
                    guard !useSystemSpeechHighlighting else { return }
                    guard responseWordTimings.isEmpty else { return }
                    guard !responseWords.isEmpty else { return }
                    let clamped = max(0.0, min(1.0, progress))
                    let index = min(responseWords.count - 1, Int(clamped * Double(responseWords.count)))
                    responseWordIndex = max(0, index)
                }
                .onReceive(audioPlayer.$playbackTime) { time in
                    guard currentState == "vocalising" else { return }
                    responsePlaybackTime = time
                }
                .onReceive(speechSynthesizerManager.$currentWordIndex) { index in
                    guard currentState == "vocalising" else { return }
                    guard useSystemSpeechHighlighting else { return }
                    guard speechSynthesizerManager.currentSpeechText == responseText else { return }
                    responseWordIndex = index
                }
                .onChange(of: visionEnabled) { _ in updateCamera() }
                .onChange(of: scenePhase) { _ in updateCamera() }
                .onChange(of: showingSettingsSheet) { _ in updateCamera() }
                .onChange(of: showingHomeKitSheet) { _ in updateCamera() }
                .onChange(of: navigate) { _ in updateCamera() }
                .onReceive(camera.$errorMessage) { message in
                    if let message = message { assistantError = message; visionEnabled = false }
                }
                .alert("Assistant", isPresented: Binding(
                    get: { assistantError != nil }, set: { if !$0 { assistantError = nil } }
                )) { Button("OK", role: .cancel) {} } message: { Text(assistantError ?? "") }

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

    private var statusLabel: String {
        switch currentState {
        case "thinking":
            return "thinking..."
        case "listening":
            return "listening..."
        case "vocalising":
            return "speaking..."
        case "sleeping":
            return "sleeping"
        case "try again later":
            return "try again later"
        case "chatting":
            return "chatting"
        default:
            return currentState
        }
    }

    private var activeTranscriptTitle: String {
        switch currentState {
        case "vocalising", "chatting":
            return "Response"
        default:
            return "Live transcription"
        }
    }

    private var activeTranscriptText: String {
        switch currentState {
        case "vocalising", "chatting", "sleeping", "conversation saved", "conversation deleted":
            return responseText.isEmpty ? "" : responseText
        default:
            return liveTranscript.isEmpty ? "" : liveTranscript
        }
    }

    private var isShowingResponse: Bool {
        switch currentState {
        case "vocalising", "chatting", "sleeping", "conversation saved", "conversation deleted":
            return true
        default:
            return false
        }
    }

    private var activeTranscriptHighlightIndex: Int {
        switch currentState {
        case "vocalising", "chatting":
            return responseWordIndex
        default:
            return liveWordIndex
        }
    }

    private var activeTranscriptTimings: [WordTiming] {
        switch currentState {
        case "vocalising", "chatting":
            return responseWordTimings
        default:
            return []
        }
    }

    private var activeTranscriptTime: Double {
        switch currentState {
        case "vocalising", "chatting":
            return responsePlaybackTime
        default:
            return 0
        }
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

    private func updateCamera() {
        if visionEnabled && AssistantProvider.current.supportsCamera && scenePhase == .active
            && !showingSettingsSheet && !showingHomeKitSheet && !navigate {
            camera.start()
        } else { camera.stop() }
    }

    func startup() {
        visionEnabled = UserDefaults.standard.bool(forKey: "vision")
        searchEnabled = UserDefaults.standard.bool(forKey: "allowSearch")
        updateCamera()
        speechRecognizer.setUpdateStateHandler { newState in
            DispatchQueue.main.async {
                liveTranscript = newState
                liveWordIndex = max(0, newState.split(whereSeparator: { $0.isWhitespace }).count - 1)
                if currentState != "thinking" && currentState != "vocalising" {
                    currentState = "listening"
                }
            }
        }
        speechRecognizer.setOnTimeoutHandler { transcript in
            print("Silence detected...")
            sendToOpenAI(transcript: transcript)
        }
        if !AssistantProvider.current.isConfigured {
            if let fileURL = Bundle.main.url(forResource: "hello", withExtension: "mp3") {
                audioPlayer.playAudioFromFile(url: fileURL)
            }
        } else {
            name = UserDefaults.standard.string(forKey: "name") ?? "Samantha"
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
            }
        }
    }

    func sayText(text: String) {
        if elevenLabs {
            useSystemSpeechHighlighting = false
            elevenLabsTextToSpeech(name: name, text: text) { result in
                switch result {
                case .success(let response):
                    DispatchQueue.main.async {
                        responseWordTimings = response.timings
                        responsePlaybackTime = 0
                        if text == responseText {
                            lastResponseAudioData = response.audio
                            lastResponseTimings = response.timings
                            lastResponseText = text
                        }
                    }
                    audioPlayer.playAudioFromData(data: response.audio)
                case .failure(let error):
                    currentState = "try again later"
                    print("Eleven Labs API error: \(error.localizedDescription)")
                    if let fileURL = Bundle.main.url(forResource: "sorry", withExtension: "mp3") {
                        audioPlayer.playAudioFromFile(url: fileURL)
                    }
                }
            }
        } else if UserDefaults.standard.bool(forKey: "grokVoice") {
            useSystemSpeechHighlighting = false
            responseWordTimings = []
            responsePlaybackTime = 0
            let voiceID = UserDefaults.standard.string(forKey: "grokVoiceID") ?? "eve"
            let apiKey = UserDefaults.standard.string(forKey: "grokApiKey") ?? ""
            Task { @MainActor in
                do {
                    let data = try await GrokSpeechAPI.speech(text: text, voiceID: voiceID, apiKey: apiKey)
                    if text == responseText {
                        lastResponseAudioData = data
                        lastResponseTimings = []
                        lastResponseText = text
                    }
                    audioPlayer.playAudioFromData(data: data)
                } catch {
                    currentState = "try again later"
                    assistantError = error.localizedDescription
                    setAudioSession(active: false)
                }
            }
        } else if openAIVoice {
            useSystemSpeechHighlighting = false
            openAItextToSpeechAPI(name: UserDefaults.standard.string(forKey: "openAIVoiceID") ?? "nova", text: text) { result in
                switch result {
                case .success(let data):
                    DispatchQueue.main.async {
                        responseWordTimings = []
                        responsePlaybackTime = 0
                        if text == responseText {
                            lastResponseAudioData = data
                            lastResponseTimings = []
                            lastResponseText = text
                        }
                    }
                    audioPlayer.playAudioFromData(data: data)
                    openAITranscribeAudioForWordTimings(data: data) { timingResult in
                        switch timingResult {
                        case .success(let timings):
                            DispatchQueue.main.async {
                                responseWordTimings = timings
                                if text == responseText {
                                    lastResponseTimings = timings
                                }
                            }
                        case .failure(let error):
                            print("OpenAI transcription timing error: \(error.localizedDescription)")
                        }
                    }
                case .failure(let error):
                    currentState = "try again later"
                    print("OpenAI voice API error: \(error.localizedDescription)")
                    if let fileURL = Bundle.main.url(forResource: "sorry", withExtension: "mp3") {
                        audioPlayer.playAudioFromFile(url: fileURL)
                    }
                }
            }
        } else {
            useSystemSpeechHighlighting = true
            responseWordTimings = []
            responsePlaybackTime = 0
            if text == responseText {
                lastResponseAudioData = nil
                lastResponseTimings = []
                lastResponseText = text
            }
            speechSynthesizerManager.currentSpeechText = text
            let speechUtterance = AVSpeechUtterance(string: text)
            speechUtterance.voice = AVSpeechSynthesisVoice(language: nil)
            speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate

            speechSynthesizerManager.speechSynthesizer.speak(speechUtterance)
        }
        setAudioSession(active: true)
    }

    private func replayLastResponse() {
        guard !lastResponseText.isEmpty else { return }
        responseText = lastResponseText
        responseWords = lastResponseText.split(whereSeparator: { $0.isWhitespace })
        responseWordIndex = 0
        responsePlaybackTime = 0
        currentState = "vocalising"

        if let audioData = lastResponseAudioData {
            useSystemSpeechHighlighting = false
            responseWordTimings = lastResponseTimings
            audioPlayer.playAudioFromData(data: audioData)
            setAudioSession(active: true)
        } else {
            useSystemSpeechHighlighting = true
            responseWordTimings = []
            speechSynthesizerManager.currentSpeechText = lastResponseText
            let speechUtterance = AVSpeechUtterance(string: lastResponseText)
            speechUtterance.voice = AVSpeechSynthesisVoice(language: nil)
            speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
            speechSynthesizerManager.speechSynthesizer.speak(speechUtterance)
            setAudioSession(active: true)
        }
    }

    private var speechSubmissionBlockReason: String? {
        if !sendButtonEnabled { return "a response is already in progress" }
        if mute { return "microphone is muted" }
        if showingSettingsSheet { return "settings is open" }
        if showingHomeKitSheet { return "HomeKit is open" }
        if navigate { return "conversation archive is open" }
        // Stored speech callbacks outlive the View value that installed them. Read
        // application activity now, rather than that View's captured scenePhase.
        if UIApplication.shared.applicationState != .active { return "app is not active" }
        if !AssistantProvider.current.isConfigured { return "assistant provider is not configured" }
        return nil
    }

    private func resumeListening() {
        guard speechSubmissionBlockReason == nil else { return }
        currentState = "listening"
        speechRecognizer.transcribe()
    }

    func sendToOpenAI(transcript: String) {
        if let reason = speechSubmissionBlockReason {
            print("Speech turn skipped: \(reason)")
            return
        }
        let transcriptSnapshot = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !transcriptSnapshot.isEmpty else {
            print("Speech turn skipped: transcript is empty")
            resumeListening()
            return
        }
        speechRecognizer.stopTranscribing()
        sendButtonEnabled = false
        currentState = "thinking"
        speed = 20
        pendingTranscript = transcriptSnapshot
        liveTranscript = transcriptSnapshot
        liveWordIndex = max(0, transcriptSnapshot.split(whereSeparator: { $0.isWhitespace }).count - 1)
        print("Message: \(transcriptSnapshot)")

        currentImage = nil
        if visionEnabled && AssistantProvider.current.supportsCamera {
            guard let frame = camera.snapshot() else {
                assistantError = "The camera is not ready. Please wait for the live view, then speak again."
                currentState = "listening"
                sendButtonEnabled = true
                speechRecognizer.transcribe()
                return
            }
            currentImage = frame
        }

        continueSendingToOpenAI(transcript: transcriptSnapshot)
    }

    func continueSendingToOpenAI(transcript: String? = nil) {
        let messageText = transcript ?? speechRecognizer.transcript
        let base64String = currentImage.map { encodeToBase64(image: $0) } ?? ""
        chatHistory.addMessage(messageText, from: .user, with: base64String)
        let useGateway = AssistantProvider.current == .gateway
        let completionHandler: (Result<String, Error>) -> Void = { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let content):
                    responseText = content
                    lastResponseText = content
                    responseWords = content.split(whereSeparator: { $0.isWhitespace })
                    responseWordIndex = 0
                    responseWordTimings = []
                    responsePlaybackTime = 0
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
                            with: ""
                        )
                    }
                    currentImage = nil
                    pendingTranscript = ""
                    currentState = "vocalising"
                    sayText(text: content)
                    speed = 300
                    sendButtonEnabled = true
                    deleteButtonTapped = false
                case .failure(let error):
                    currentState = "try again later"
                    currentImage = nil
                    pendingTranscript = ""
                    assistantError = error.localizedDescription
                    print("Assistant API error: \(error.localizedDescription)")
                    if let fileURL = Bundle.main.url(forResource: "sorry", withExtension: "mp3") {
                        audioPlayer.playAudioFromFile(url: fileURL)
                    }
                    sendButtonEnabled = true
                }
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
        let scaleFactor = min(1, width / oldWidth)

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

struct TranscriptCardView: View {
    let title: String
    let text: String
    let highlightedWordIndex: Int
    var timings: [WordTiming] = []
    var currentTime: Double = 0

    var body: some View {
        VStack(spacing: 16) {
            TranscriptBlockView(
                text: text,
                highlightedWordIndex: highlightedWordIndex,
                timings: timings,
                currentTime: currentTime
            )
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
    }
}

struct TranscriptBlockView: View {
    let text: String
    let highlightedWordIndex: Int
    var timings: [WordTiming] = []
    var currentTime: Double = 0

    var body: some View {
        let payload = attributedTextPayload
        ScrollingAttributedTextView(
            attributedText: payload.text,
            scrollRange: scrollRange(in: payload.wordRanges)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 6)
    }

    private var attributedTextPayload: (text: NSAttributedString, wordRanges: [NSRange]) {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        guard !words.isEmpty else { return (NSAttributedString(string: text), []) }

        let attributed = NSMutableAttributedString()
        var ranges: [NSRange] = []
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineSpacing = 6

        for (index, word) in words.enumerated() {
            let start = attributed.length
            let wordString = String(word)
            let wordAttributes = attributesForWord(at: index)
            let part = NSAttributedString(string: wordString, attributes: wordAttributes)
            attributed.append(part)
            ranges.append(NSRange(location: start, length: part.length))
            if index < words.count - 1 {
                attributed.append(NSAttributedString(string: " "))
            }
        }

        attributed.addAttribute(
            .paragraphStyle,
            value: paragraphStyle,
            range: NSRange(location: 0, length: attributed.length)
        )

        return (attributed, ranges)
    }

    private func attributesForWord(at index: Int) -> [NSAttributedString.Key: Any] {
        let font = UIFont.systemFont(ofSize: 30, weight: .semibold)

        if !timings.isEmpty, index < timings.count {
            return attributesForTimedWord(at: index, font: font)
        }

        let color: UIColor = (index == highlightedWordIndex)
            ? UIColor.white
            : UIColor.white.withAlphaComponent(0.35)
        return [.font: font, .foregroundColor: color]
    }

    private func attributesForTimedWord(at index: Int, font: UIFont) -> [NSAttributedString.Key: Any] {
        let timing = timings[index]
        let start = timing.start
        let end = max(timing.end, start + 0.01)

        if currentTime < start {
            return [.font: font, .foregroundColor: UIColor.white.withAlphaComponent(0.25)]
        }

        if currentTime > end {
            return [.font: font, .foregroundColor: UIColor.white.withAlphaComponent(0.6)]
        }

        let progress = (currentTime - start) / (end - start)
        let eased = smoothstep(progress)
        let opacity = 0.6 + 0.4 * eased
        return [.font: font, .foregroundColor: UIColor.white.withAlphaComponent(opacity)]
    }

    private func scrollRange(in ranges: [NSRange]) -> NSRange? {
        guard !ranges.isEmpty else { return nil }
        if !timings.isEmpty {
            let index = activeTimedWordIndex()
            guard index >= 0, index < ranges.count else { return nil }
            return ranges[index]
        }
        guard highlightedWordIndex >= 0, highlightedWordIndex < ranges.count else { return nil }
        return ranges[highlightedWordIndex]
    }

    private func activeTimedWordIndex() -> Int {
        guard !timings.isEmpty else { return highlightedWordIndex }
        if let index = timings.lastIndex(where: { currentTime >= $0.start }) {
            return index
        }
        return 0
    }

    private func smoothstep(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }
}

struct ScrollingAttributedTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    let scrollRange: NSRange?

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = true
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.showsVerticalScrollIndicator = false
        textView.textContainer.widthTracksTextView = true
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        uiView.attributedText = attributedText
        guard let range = scrollRange else { return }
        guard range.location != NSNotFound else { return }
        guard range.location + range.length <= uiView.attributedText.length else { return }
        context.coordinator.scrollIfNeeded(to: range, in: uiView)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        private var lastRange: NSRange?
        private var lastTextLength: Int = 0

        func scrollIfNeeded(to range: NSRange, in textView: UITextView) {
            guard lastRange != range || lastTextLength != textView.attributedText.length else { return }
            lastRange = range
            lastTextLength = textView.attributedText.length
            DispatchQueue.main.async {
                textView.scrollRangeToVisible(range)
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}

class SpeechSynthesizerManager: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    @Published var playbackFinished = false
    @Published var currentSpeechText: String = ""
    @Published var currentWordIndex: Int = 0
    var speechSynthesizer: AVSpeechSynthesizer

    override init() {
        self.speechSynthesizer = AVSpeechSynthesizer()
        super.init()
        self.speechSynthesizer.delegate = self
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        currentSpeechText = utterance.speechString
        currentWordIndex = wordIndex(for: characterRange, in: utterance.speechString)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        playbackFinished = false
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        print("Finished speaking")
        setAudioSession(active: false)

        playbackFinished = true
    }

    private func wordIndex(for range: NSRange, in text: String) -> Int {
        guard let swiftRange = Range(range, in: text) else { return 0 }
        let prefix = text[..<swiftRange.lowerBound]
        let words = prefix.split(whereSeparator: { $0.isWhitespace })
        return max(0, words.count)
    }
}

class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var audioPlayer: AVAudioPlayer?
    @Published var playbackFinished = false
    @Published var playbackProgress: Double = 0
    @Published var playbackTime: Double = 0
    private var progressTimer: Timer?

    func playAudioFromData(data: Data) {
        DispatchQueue.main.async {
            do {
                self.audioPlayer = try AVAudioPlayer(data: data)
                self.audioPlayer?.delegate = self
                self.audioPlayer?.prepareToPlay()
                self.playbackFinished = false
                self.playbackProgress = 0
                self.playbackTime = 0
                self.audioPlayer?.play()
                self.startProgressTimer()
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
                self.playbackProgress = 0
                self.playbackTime = 0
                self.audioPlayer?.play()
                self.startProgressTimer()
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
        self.playbackProgress = 1.0
        self.playbackTime = player.duration
        progressTimer?.invalidate()
        progressTimer = nil


   }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self,
                  let player = self.audioPlayer,
                  player.duration > 0 else { return }
            self.playbackProgress = player.currentTime / player.duration
            self.playbackTime = player.currentTime
        }
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

// Capture work stays off the main thread; the lock protects only the latest frame.
final class LiveCamera: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    @Published var errorMessage: String?
    private let queue = DispatchQueue(label: "OSOne.camera")
    private let lock = NSLock()
    private var latestFrame: CVPixelBuffer?
    private var frameTime = Date.distantPast
    private var wantsRunning = false
    private let context = CIContext()
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        for event in [AVCaptureSession.runtimeErrorNotification, AVCaptureSession.wasInterruptedNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: event, object: session, queue: nil) { [weak self] _ in
                self?.stop()
                self?.fail("The camera was interrupted. Turn it on again when the camera is available.")
            })
        }
    }

    deinit { observers.forEach { NotificationCenter.default.removeObserver($0) } }

    func start() {
        queue.async {
            self.wantsRunning = true
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: self.configureAndStart()
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { allowed in
                    self.queue.async {
                        guard self.wantsRunning else { return }
                        if allowed { self.configureAndStart() }
                        else { self.fail("Camera access was denied. Enable it in the device Settings.") }
                    }
                }
            default: self.fail("Camera access is unavailable. Enable it in the device Settings.")
            }
        }
    }

    private func configureAndStart() {
        guard wantsRunning, !session.isRunning else { return }
        if session.inputs.isEmpty {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                fail("No camera is available on this device."); return
            }
            session.beginConfiguration()
            session.sessionPreset = .hd1280x720
            session.automaticallyConfiguresApplicationAudioSession = false
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            guard session.canAddInput(input), session.canAddOutput(output) else {
                session.commitConfiguration(); fail("Unable to start the camera."); return
            }
            session.addInput(input)
            session.addOutput(output)
            session.commitConfiguration()
        }
        DispatchQueue.main.async { self.errorMessage = nil }
        session.startRunning()
    }

    func stop() {
        queue.async {
            self.wantsRunning = false
            if self.session.isRunning { self.session.stopRunning() }
            self.lock.lock()
            self.latestFrame = nil
            self.frameTime = .distantPast
            self.lock.unlock()
        }
    }

    private func fail(_ message: String) {
        DispatchQueue.main.async { self.errorMessage = message }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.lock()
        latestFrame = buffer
        frameTime = Date()
        lock.unlock()
    }

    func snapshot() -> UIImage? {
        lock.lock()
        let buffer = latestFrame
        let fresh = Date().timeIntervalSince(frameTime) < 1
        lock.unlock()
        guard fresh, let buffer = buffer,
              let image = context.createCGImage(CIImage(cvPixelBuffer: buffer), from: CIImage(cvPixelBuffer: buffer).extent) else { return nil }
        let orientation = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first?.interfaceOrientation
        let imageOrientation: UIImage.Orientation
        switch orientation {
        case .landscapeLeft: imageOrientation = .down
        case .landscapeRight: imageOrientation = .up
        case .portraitUpsideDown: imageOrientation = .left
        default: imageOrientation = .right
        }
        return UIImage(cgImage: image, scale: 1, orientation: imageOrientation)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ uiView: CameraPreviewView, context: Context) { uiView.setNeedsLayout() }
}

final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard let connection = previewLayer.connection, connection.isVideoOrientationSupported else { return }
        switch window?.windowScene?.interfaceOrientation {
        case .landscapeLeft: connection.videoOrientation = .landscapeLeft
        case .landscapeRight: connection.videoOrientation = .landscapeRight
        case .portraitUpsideDown: connection.videoOrientation = .portraitUpsideDown
        default: connection.videoOrientation = .portrait
        }
    }
}
