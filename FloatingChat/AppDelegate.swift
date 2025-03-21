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
            // Store the window controller for easy access
            if let windowController = NSApp.windows.first?.windowController as? WindowController {
                self.windowController = windowController
            } else if let scene = NSApp.connectedScenes.first as? NSWindowScene,
                     let windowController = scene.windows.first?.windowController as? WindowController {
                self.windowController = windowController
            } else {
                // For SwiftUI apps, get the WindowController from the environment
                if let windowController = NSApp.delegate?.value(forKey: "windowController") as? WindowController {
                    self.windowController = windowController
                } else {
                    print("Could not find WindowController")
                }
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