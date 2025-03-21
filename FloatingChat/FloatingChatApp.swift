//
//  FloatingChatApp.swift
//  FloatingChat
//
//  Created by 赵嘉策 on 2025/3/21.
//

import SwiftUI
import Combine
import ServiceManagement

@main
struct FloatingChatApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    let persistenceController = PersistenceController.shared
    @StateObject private var windowController = WindowController()
    @StateObject private var keyboardShortcutManager = KeyboardShortcutManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(windowController)
                .environmentObject(keyboardShortcutManager)
                .onAppear {
                    appDelegate.windowController = windowController
                    keyboardShortcutManager.windowController = windowController
                    
                    // Register the global shortcut
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        keyboardShortcutManager.registerGlobalShortcut()
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
        .defaultSize(width: 600, height: 70)
        .onChange(of: windowController.isExpanded) { newValue in
            NSApp.mainWindow?.setFrame(
                NSRect(
                    x: NSApp.mainWindow?.frame.origin.x ?? 0,
                    y: NSApp.mainWindow?.frame.origin.y ?? 0,
                    width: 600,
                    height: newValue ? 500 : 70
                ),
                display: true,
                animate: true
            )
        }
    }
}

// Window controller to manage the floating behavior
class WindowController: ObservableObject {
    @Published var isExpanded = false
    @Published var isFloating = true
    
    init() {
        setFloating(true)
    }
    
    func toggleExpansion() {
        isExpanded.toggle()
    }
    
    func setFloating(_ floating: Bool) {
        isFloating = floating
        
        // We need to apply these settings after a slight delay to ensure the window is created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            if let window = NSApp.mainWindow {
                window.level = floating ? .floating : .normal
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                window.isMovableByWindowBackground = true
                window.styleMask.insert(.fullSizeContentView)
                window.titlebarAppearsTransparent = true
                window.titleVisibility = .hidden
                
                // Set the window's background to be partially transparent
                window.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.95)
                window.hasShadow = true
                
                // Make window corners rounded
                window.contentView?.wantsLayer = true
                window.contentView?.layer?.cornerRadius = 16
                window.contentView?.layer?.masksToBounds = true
            }
        }
    }
    
    func toggleVisibility() {
        if let window = NSApp.mainWindow {
            if window.isVisible {
                window.orderOut(nil)
            } else {
                window.makeKeyAndOrderFront(nil)
                window.center()
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

// Keyboard shortcut manager to handle global shortcuts
class KeyboardShortcutManager: ObservableObject {
    @Published var isListening = false
    private let shortcutHandler = KeyboardShortcutHandler.shared
    var windowController: WindowController?
    
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
