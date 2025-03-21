//
//  AppDelegate.swift
//  FloatingChat
//
//  Created for FloatingChat on 2025/3/21.
//

import Cocoa
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    var windowController: FloatingWindowController?
    private var statusItem: NSStatusItem?
    private var splashWindow: NSWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        showSplashScreen()
        
        // Register for reopen events
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func showSplashScreen() {
        // Create a splash window
        let splashView = SplashView {
            self.dismissSplashScreen()
        }
        
        let splashWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        splashWindow.backgroundColor = .clear
        splashWindow.isOpaque = false
        splashWindow.hasShadow = true
        splashWindow.level = .floating
        splashWindow.center()
        
        let hostingView = NSHostingView(rootView: splashView)
        splashWindow.contentView = hostingView
        
        self.splashWindow = splashWindow
        splashWindow.makeKeyAndOrderFront(nil)
    }
    
    private func dismissSplashScreen() {
        splashWindow?.orderOut(nil)
        splashWindow = nil
        
        // After splash screen is dismissed, show the main window
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.windowController?.showWindow()
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            windowController?.showWindow()
        }
        return true
    }
    
    // Set up status bar icon
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "bubble.left.and.text.bubble.right.fill", accessibilityDescription: "FloatingChat")
            button.action = #selector(toggleWindow)
            button.target = self
        }
        
        // Set up menu
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Show/Hide", action: #selector(toggleWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit FloatingChat", action: #selector(quitApp), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleWindow() {
        windowController?.toggleVisibility()
    }
    
    @objc private func openSettings() {
        // This would typically post a notification that the settings should be shown
        // For now, we'll just show the window
        windowController?.showWindow()
        
        // Post a notification to show settings
        NotificationCenter.default.post(name: Notification.Name("ShowSettingsNotification"), object: nil)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}