//
//  ChatGPT_VoiceApp.swift
//  ChatGPT Voice
//
//  Created by Simon Loffler on 2/4/2023.
//

import SwiftUI

@main
struct ChatGPT_VoiceApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
