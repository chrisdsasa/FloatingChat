//
//  KeyboardShortcutHandler.swift
//  FloatingChat
//
//  Created for FloatingChat on 2025/3/21.
//

import Foundation
import Cocoa
import Carbon

class KeyboardShortcutHandler {
    static let shared = KeyboardShortcutHandler()
    
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var callbacks: [() -> Void] = []
    
    // Register callback to be executed when the shortcut is triggered
    func registerCallback(_ callback: @escaping () -> Void) {
        callbacks.append(callback)
    }
    
    func startListening() {
        // Create an event tap to monitor key events
        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                if type == .keyDown {
                    let keycode = event.getIntegerValueField(.keyboardEventKeycode)
                    let flags = event.flags
                    
                    // Check for Option + Space (keycode 49 is space)
                    if keycode == 49 && flags.contains(.maskAlternate) && !flags.contains(.maskCommand) && !flags.contains(.maskControl) && !flags.contains(.maskShift) {
                        KeyboardShortcutHandler.shared.executeCallbacks()
                        return nil // Consume the event
                    }
                }
                return Unmanaged.passRetained(event)
            },
            userInfo: nil
        ) else {
            print("Failed to create event tap")
            return
        }
        
        self.eventTap = eventTap
        
        // Create a run loop source from the event tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        // Add the run loop source to the current run loop
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        
        // Enable the event tap
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        print("Keyboard shortcut listener started")
    }
    
    func stopListening() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
        }
        
        print("Keyboard shortcut listener stopped")
    }
    
    private func executeCallbacks() {
        for callback in callbacks {
            callback()
        }
    }
}