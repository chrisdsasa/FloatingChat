# FloatingChat

A macOS floating AI assistant application similar to OpenAI's Trajectory, featuring a clean, minimalist interface that stays on top of all applications.

## Features

- **Floating Interface**: Always stays on top of other applications
- **Global Keyboard Shortcut**: Quickly summon with Option + Space
- **Multiple AI Providers**: Works with OpenAI, Anthropic, and Google Gemini
- **Context Management**: Intelligently manages conversation context within token limits
- **Menu Bar Integration**: Access from the menu bar icon
- **Modern SwiftUI Interface**: Clean, minimal design with subtle animations

## Requirements

- macOS 13.0+
- Xcode 15.0+
- Swift 5.9+

## Installation

1. Clone the repository
2. Open FloatingChat.xcodeproj in Xcode
3. Configure your signing certificate
4. Build and run the application

## Setting Up API Keys

1. Open the application
2. Click the gear icon in the toolbar
3. Enter your API keys for the services you want to use
4. Click Save

## Usage

- Press Option + Space to toggle the floating window
- Type your message and press Return or click the send button
- The window will expand to show the conversation

## Permissions

This application requires the following permissions:
- Accessibility permissions (for global keyboard shortcuts)
- Network access (for API calls)

## Architecture

FloatingChat follows a clean architecture pattern:

- **UI Layer**: SwiftUI views and view models
- **Service Layer**: AI providers, conversation management
- **Data Layer**: Core Data persistence

Key components:
- `AIService`: Handles communication with AI providers
- `ConversationManager`: Manages conversation history and context
- `KeyboardShortcutHandler`: Captures global keyboard shortcuts
- `WindowController`: Controls window behavior and appearance

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- [Combine](https://developer.apple.com/documentation/combine)
- [Core Data](https://developer.apple.com/documentation/coredata)