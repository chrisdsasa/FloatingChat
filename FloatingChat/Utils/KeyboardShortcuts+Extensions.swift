import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    // Show/hide the floating window
    static let toggleFloatingChat = Self("toggleFloatingChat", default: .init(.space, modifiers: .option))
    
    // Show the floating window
    static let showFloatingChat = Self("showFloatingChat", default: .init(.space, modifiers: [.option, .shift]))
} 