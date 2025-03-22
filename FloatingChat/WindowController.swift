import SwiftUI
import Cocoa
import Combine

class FloatingWindowController: ObservableObject {
    private var window: NSWindow?
    @Published var isVisible = false
    @Published var isExpanded = false
    @Published var isFloating = true
    
    init() {
        setupWindow()
        setFloating(true)
    }
    
    private func setupWindow() {
        let contentView = ContentView()
            .environmentObject(ConversationManager.shared)
            .environmentObject(AIService.shared)
            .environmentObject(self)
        
        // Create the window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 600),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        // Configure window appearance
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.center()
        window.setFrameAutosaveName("FloatingChatWindow")
        window.contentView = NSHostingView(rootView: contentView)
        window.level = .floating
        window.backgroundColor = NSColor.windowBackgroundColor
        
        // Add rounded corners to the window
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 15
        window.contentView?.layer?.masksToBounds = true
        
        // Apply vibrancy if available
        window.appearance = NSAppearance(named: .vibrantDark)
        
        // Add a shadow
        window.hasShadow = true
        
        // Create a visual effect to make the window semi-transparent
        if let contentView = window.contentView {
            let visualEffectView = NSVisualEffectView(frame: contentView.bounds)
            visualEffectView.material = .hudWindow
            visualEffectView.state = .active
            visualEffectView.blendingMode = .behindWindow
            visualEffectView.autoresizingMask = [.width, .height]
            contentView.addSubview(visualEffectView, positioned: .below, relativeTo: nil)
        }
        
        self.window = window
    }
    
    func toggleExpansion() {
        isExpanded.toggle()
        updateWindowSize()
    }
    
    private func updateWindowSize() {
        if let window = self.window {
            let newHeight: CGFloat = isExpanded ? 500 : 70
            let frame = NSRect(
                x: window.frame.origin.x,
                y: window.frame.origin.y,
                width: window.frame.width,
                height: newHeight
            )
            window.setFrame(frame, display: true, animate: true)
        }
    }
    
    func setFloating(_ floating: Bool) {
        isFloating = floating
        
        // We need to apply these settings after a slight delay to ensure the window is created
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            
            if let window = self.window {
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
    
    func showWindow() {
        if window == nil {
            setupWindow()
        }
        
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        isVisible = true
    }
    
    func hideWindow() {
        window?.orderOut(nil)
        isVisible = false
    }
    
    func toggleVisibility() {
        if isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }
    
    func isWindowVisible() -> Bool {
        return isVisible
    }
} 