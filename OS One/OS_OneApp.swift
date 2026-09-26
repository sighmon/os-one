//
//  OS_OneApp.swift
//  OS One
//
//  Created by Simon Loffler on 2/4/2023.
//

import SwiftUI

@main
struct OS_OneApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--settings-preview") {
                SettingsView()
            } else {
                HomeView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
            #else
            HomeView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
            #endif
        }
    }
}
