//
//  ConversationView.swift
//  OS One
//
//  Created by Simon Loffler on 6/4/2023.
//

import AVFoundation
import SwiftUI

struct ConversationView: View {
    var conversation: Conversation
    var messages: [ChatMessage]

    @EnvironmentObject var chatHistory: ChatHistory
    @StateObject private var audioPlayer = SmallAudioPlayer()
    @State private var speechBubbleTapped: String = ""
    @State private var addButtonTapped: Bool = false

    init(conversation: Conversation) {
        self.conversation = conversation
        self.messages = deserialiseMessages(messages: conversation.messages ?? "[\"{\\\"id\\\":\\\"5E2D5C50-DA37-4288-A1D5-7053A42BB68F\\\",\\\"message\\\":\\\"Sorry\\\",\\\"sender\\\":\\\"user\\\"}\",\"{\\\"id\\\":\\\"71C72D78-99C8-4655-BCFE-D190D04CB83F\\\",\\\"message\\\":\\\"This message is broken.\\\",\\\"sender\\\":\\\"openAI\\\"}\"]")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header Section
                VStack(spacing: 8) {
                    Text(conversation.name ?? "Conversation")
                        .font(.system(size: 28, weight: .semibold))

                    Text("\(conversation.timestamp ?? Date(), formatter: dateFormatter)")
                        .font(.system(size: 16, weight: .light))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .padding(.top, 16)
                .padding(.bottom, 24)

                // Messages Section
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(
                            text: message.message,
                            isUser: message.sender == ChatMessage.Sender.user,
                            isLoading: message.message == speechBubbleTapped
                        )
                        .onTapGesture {
                            handleMessageTap(message: message)
                        }
                    }
                }
                .padding(.horizontal, 16)

                // Add to Current Chat Button
                Button(action: {
                    addButtonTapped = true
                    chatHistory.messages = messages
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: addButtonTapped ? "checkmark.circle.fill" : "plus.circle.fill")
                            .font(.system(size: 20))
                        Text(addButtonTapped ? "Added" : "Add to Current Chat")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .foregroundColor(addButtonTapped ? .green : .blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(addButtonTapped ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    )
                }
                .disabled(addButtonTapped)
                .padding(.top, 32)
                .padding(.bottom, 24)
            }
        }
        .onDisappear {
            setAudioSession(active: false)
        }
    }

    private func handleMessageTap(message: ChatMessage) {
        guard message.sender != ChatMessage.Sender.user else { return }

        speechBubbleTapped = message.message
        elevenLabsGetAudioId(text: message.message) { result in
            switch result {
            case .success(let audioId):
                print("Audio ID found: \(audioId)")
                elevenLabsGetHistoricAudio(audioId: audioId) { result in
                    switch result {
                    case .success(let data):
                        speechBubbleTapped = ""
                        setAudioSession(active: true)
                        audioPlayer.playAudioFromData(data: data)
                    case .failure(let error):
                        speechBubbleTapped = ""
                        print("Eleven Labs API error: \(error.localizedDescription)")
                    }
                }
            case .failure(let error):
                speechBubbleTapped = ""
                print("ElevenLabs API error: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Message Bubble Component
struct MessageBubble: View {
    let text: String
    let isUser: Bool
    var isLoading: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundColor(isUser ? .white : Color(UIColor.darkText))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isUser ? Color.blue : Color(UIColor.systemGray5))
                    )
                    .textSelection(.enabled)

                if isLoading {
                    HStack(spacing: 4) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("Loading audio...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !isUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// Legacy SpeechBubble for backward compatibility
struct SpeechBubble: View {
    let text: String
    let human: Bool

    var body: some View {
        MessageBubble(text: text, isUser: human)
    }
}

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter
}()

func deserialiseMessages(messages: String) -> [ChatMessage] {
    var chatMessages = [ChatMessage]()
    if let messagesArray = deserializeJSONStringToArray(messages) {
        for message in messagesArray {
            chatMessages.append(deserialize(jsonString: message)!)
        }
    }
    return chatMessages
}

func deserializeJSONStringToArray(_ jsonString: String) -> [String]? {
    guard let data = jsonString.data(using: .utf8) else {
        print("Failed to convert jsonString to Data")
        return []
    }

    do {
        let jsonArray = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String]
        return jsonArray
    } catch {
        print("Failed to deserialize JSON string to an array: \(error.localizedDescription)")
        return []
    }
}

class SmallAudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
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
        setAudioSession(active: false)
   }
}

struct ConversationView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationView(
            conversation: Conversation(
                context: PersistenceController.preview.container.viewContext
            )
        ).environment(
            \.managedObjectContext,
            PersistenceController.preview.container.viewContext
        )
    }
}
