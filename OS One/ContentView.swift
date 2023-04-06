//
//  ContentView.swift
//  OS One
//
//  Created by Simon Loffler on 2/4/2023.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Conversation.timestamp, ascending: false)],
        animation: .default)
    private var conversations: FetchedResults<Conversation>

    var body: some View {
        List {
            ForEach(conversations) { conversation in
                NavigationLink(destination: ConversationView(conversation: conversation)) {
                    Text(conversation.timestamp!, formatter: conversationFormatter)
                }
            }
            .onDelete(perform: deleteConversations)
        }
        .navigationTitle("Conversations")
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
