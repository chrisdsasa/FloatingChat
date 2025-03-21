//
//  FloatingChatApp.swift
//  FloatingChat
//
//  Created by 赵嘉策 on 2025/3/21.
//

import SwiftUI

@main
struct FloatingChatApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
