//
//  ContentView.swift
//  OS One
//
//  Created by Simon Loffler on 2/4/2023.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @EnvironmentObject var chatHistory: ChatHistory
    @Environment(\.managedObjectContext) private var viewContext
    @State private var searchText = ""

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.timestamp, ascending: false)],
        animation: .default)
    private var conversations: FetchedResults<Conversation>

    var body: some View {
        List {
            ForEach(conversations.filter(
                { searchText.isEmpty ? true : messagesContainSearchQuery(
                    messages: $0.messages!,
                    query: searchText
                )})) { conversation in
                NavigationLink(destination: ConversationView(conversation: conversation).environmentObject(chatHistory)) {
                    Text(messagePreview(messages:conversation.messages!))
                        .lineLimit(1)
                }
            }
            .onDelete(perform: deleteConversations)
        }
        .navigationTitle("Conversations")
        .searchable(text: $searchText)
    }

    private func messagePreview(messages: String) -> String {
        var preview = "Sorry, this conversation is broken"
        if messages.isEmpty {
            preview = "Empty chat"
        }
        preview = deserialiseMessages(messages: messages).first?.message ?? "Empty chat"
        return preview
    }

    private func messagesContainSearchQuery(messages: String, query: String) -> Bool {
        var containsQuery = false
        if messages.isEmpty {
            return false
        }
        for chat in deserialiseMessages(messages: messages) {
            if chat.message.lowercased().contains(query.lowercased()) {
                containsQuery = true
            }
        }
        return containsQuery
    }

    private func deleteConversations(offsets: IndexSet) {
        withAnimation {
            offsets.map { conversations[$0] }.forEach(viewContext.delete)

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

private let conversationFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
