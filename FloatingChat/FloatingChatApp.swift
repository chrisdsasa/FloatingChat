//
//  FloatingChatApp.swift
//  FloatingChat
//
//  Created by 赵嘉策 on 2025/3/21.
//

import SwiftUI
import Combine
import ServiceManagement
import KeyboardShortcuts

@main
struct FloatingChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    @StateObject private var windowController = FloatingWindowController()
    @StateObject private var keyboardShortcutManager = KeyboardShortcutManager()
    
    var body: some Scene {
        WindowGroup {
            EmptyView()
                .hidden()
                .frame(width: 0, height: 0)
                .onAppear {
                    // Set the window controller in the app delegate
                    appDelegate.windowController = windowController
                    
                    // Hide the main window since we're using our custom window
                    if let firstWindow = NSApplication.shared.windows.first {
                        firstWindow.close()
                    }
                    
                    // Show the window initially
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        windowController.showWindow()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            // Hide default menu items that don't apply
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .pasteboard) {}
            CommandGroup(replacing: .undoRedo) {}
            
            // Add custom commands
            CommandGroup(after: .appInfo) {
                Button("Settings...") {
                    NotificationCenter.default.post(name: Notification.Name("ShowSettingsNotification"), object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }
}

// Keyboard shortcut manager to handle global shortcuts
class KeyboardShortcutManager: ObservableObject {
    @Published var isListening = false
    private let shortcutHandler = KeyboardShortcutHandler.shared
    var windowController: FloatingWindowController?
    
    func registerGlobalShortcut() {
        // Register the shortcut handler callback
        shortcutHandler.registerCallback { [weak self] in
            self?.toggleVisibility()
        }
        
        // Start listening for keyboard events
        startListening()
    }
    
    func startListening() {
        if !isListening {
            shortcutHandler.startListening()
            isListening = true
        }
    }
    
    func stopListening() {
        if isListening {
            shortcutHandler.stopListening()
            isListening = false
        }
    }
    
    func toggleVisibility() {
        // Use the main thread to update UI
        DispatchQueue.main.async { [weak self] in
            self?.windowController?.toggleVisibility()
        }
    }
}
