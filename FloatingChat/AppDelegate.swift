//
//  AppDelegate.swift
//  FloatingChat
//
//  Created for FloatingChat on 2025/3/21.
//

import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: WindowController?
    var statusItem: NSStatusItem?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarItem()
        
        // Give the window controller time to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // In SwiftUI apps, the WindowController is injected through the FloatingChatApp
            // The windowController will be set by FloatingChatApp.onAppear
            if self.windowController == nil {
                print("Warning: WindowController has not been set yet.")
            }
        }
        
        // Make sure the app doesn't show in the dock
        NSApp.setActivationPolicy(.accessory)
    }
    
    func setupMenuBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let statusButton = statusItem?.button {
            statusButton.image = NSImage(systemSymbolName: "bubble.left.fill", accessibilityDescription: "Chat Assistant")
            statusButton.action = #selector(toggleMenu)
            statusButton.target = self
        }
        
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show/Hide Window", action: #selector(toggleWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(showPreferences), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc func toggleMenu() {
        if let menu = statusItem?.menu {
            statusItem?.button?.performClick(nil)
        }
    }
    
    @objc func toggleWindow() {
        windowController?.toggleVisibility()
    }
    
    @objc func showPreferences() {
        // Will implement preferences window
    }
    
    @objc func quitApp() {
        NSApp.terminate(nil)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}