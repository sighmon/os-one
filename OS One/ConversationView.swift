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
            VStack {
                Text(conversation.name ?? "Conversation")
                    .font(.system(size: 30, weight: .medium))
                    .padding(.bottom, 1)
                    .padding(.top, 10)
                Text("\(conversation.timestamp ?? Date(), formatter: dateFormatter)")
                    .font(.system(size: 20, weight: .light))
                    .padding(.bottom, 20)
                    .textSelection(.enabled)
                ForEach(messages) { message in
                    SpeechBubble(
                        text: message.message,
                        human: message.sender == ChatMessage.Sender.user
                    )
                        .padding(.horizontal)
                        .padding(
                            EdgeInsets(
                                top: 0, leading: 0, bottom: 10, trailing: 0
                            )
                        )
                        .opacity(message.message == speechBubbleTapped ? 0.5 : 1.0)
                        .onTapGesture {
                            if message.sender != ChatMessage.Sender.user {
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

                }
                Image(systemName: addButtonTapped ? "checkmark.circle.fill" : "plus.circle.fill")
                    .font(.system(size: 45, weight: .light))
                    .frame(width: 40)
                    .padding(.top, 20)
                    .onTapGesture {
                        addButtonTapped = true
                        chatHistory.messages = messages
                    }
                    .font(.system(
                        size: 20,
                        weight: .light
                    ))
                    .foregroundColor(.blue)
                    .opacity(addButtonTapped ? 0.3 : 0.7)
            }
            .onDisappear() {
                setAudioSession(active: false)
            }
        }
    }
}

struct SpeechBubble: View {
    let text: String
    let human: Bool

    var body: some View {
        HStack {
            if human {
                Spacer()
            }
            Text(text)
                .foregroundColor(human ? .white : Color(red: 0.1, green: 0.1, blue: 0.1))
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .foregroundColor(human ? .blue : Color(red: 0.9, green: 0.9, blue: 0.9))
                        .opacity(0.7)

                )
                .textSelection(.enabled)
            if !human {
                Spacer()
                Spacer()
                Spacer()
                Spacer()
            }
        }
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
