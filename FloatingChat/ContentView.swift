//
//  ContentView.swift
//  FloatingChat
//
//  Created by 赵嘉策 on 2025/3/21.
//

import SwiftUI
import CoreData
import Combine
import KeyboardShortcuts

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var windowController: FloatingWindowController
    
    @StateObject private var conversationManager = ConversationManager.shared
    
    @State private var inputText: String = ""
    @State private var isProcessing: Bool = false
    @State private var selectedModel: AIModel = .gpt4o
    @State private var isPresentingSettings = false
    
    // Create a class property that can be modified from within a closure
    private let cancellableContainer = CancellableContainer()
    
    // Focus state for the text field
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            if windowController.isExpanded {
                // Chat message list
                ScrollViewReader { scrollView in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(conversationManager.currentConversation.messages, id: \.id) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .onChange(of: conversationManager.currentConversation.messages.count) { _ in
                        if let lastMessage = conversationManager.currentConversation.messages.last {
                            withAnimation {
                                scrollView.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                Divider()
                    .padding(.horizontal, 8)
            }
            
            // Input area with drag handle
            VStack(spacing: 4) {
                // Drag handle (only visible in collapsed mode)
                if !windowController.isExpanded {
                    Rectangle()
                        .frame(width: 36, height: 4)
                        .cornerRadius(2)
                        .foregroundColor(Color.gray.opacity(0.3))
                        .padding(.top, 4)
                }
                
                // Input field and controls
                InputFieldView(
                    text: $inputText,
                    isProcessing: $isProcessing,
                    selectedModel: $selectedModel,
                    onSubmit: sendMessage,
                    isExpanded: windowController.isExpanded,
                    shouldFocus: isInputFocused,
                    onSettingsTapped: { isPresentingSettings = true }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .padding(.top, windowController.isExpanded ? 12 : 4)
            }
        }
        .background(
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.1, green: 0.1, blue: 0.15),
                        Color(red: 0.15, green: 0.15, blue: 0.2)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                // Subtle pattern overlay
                Color.white.opacity(0.03)
                    .blendMode(.plusLighter)
            }
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.gray.opacity(0.1), lineWidth: 0.5)
        )
        .onAppear {
            // Focus the input field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isInputFocused = true
            }
            setupKeyboardShortcuts()
            
            // Listen for settings notification
            NotificationCenter.default.addObserver(forName: Notification.Name("ShowSettingsNotification"), object: nil, queue: .main) { _ in
                isPresentingSettings = true
            }
        }
        .sheet(isPresented: $isPresentingSettings) {
            SettingsView()
        }
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environmentObject(conversationManager)
        .onTapGesture(count: 2) {
            windowController.toggleExpansion()
        }
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        // Clear the input text and capture it
        let messageText = inputText
        inputText = ""
        
        // Expand the window if it's not already expanded
        if !windowController.isExpanded {
            windowController.toggleExpansion()
        }
        
        // Show processing state
        isProcessing = true
        
        // Use streaming for a more responsive experience
        conversationManager.streamMessageToAI(text: messageText, model: selectedModel)
            .sink(
                receiveCompletion: { completion in
                    isProcessing = false
                    
                    if case .failure(let error) = completion {
                        handleError(error)
                    }
                },
                receiveValue: { _ in
                    // Each chunk is handled by the ConversationManager
                }
            )
            .store(in: &cancellableContainer.cancellables)
    }
    
    private func handleError(_ error: Error) {
        // In a real app, you would handle different error types differently
        // and display appropriate UI feedback
        print("Error: \(error.localizedDescription)")
    }
    
    // Keyboard shortcut effects
    private func setupKeyboardShortcuts() {
        // Show/hide with keyboard shortcut in any app
        KeyboardShortcuts.onKeyUp(for: .toggleFloatingChat) {
            if windowController.isVisible {
                windowController.hideWindow()
                // Don't need to modify focus state here as the window is hidden
            } else {
                windowController.showWindow()
                // Request focus when window appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
        }
        
        // Show with keyboard shortcut in any app
        KeyboardShortcuts.onKeyUp(for: .showFloatingChat) {
            windowController.showWindow()
            // Request focus when window appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
    }
}

// Input field view with toolbar buttons
struct InputFieldView: View {
    @Binding var text: String
    @Binding var isProcessing: Bool
    @Binding var selectedModel: AIModel
    var onSubmit: () -> Void
    var isExpanded: Bool
    var shouldFocus: Bool
    var onSettingsTapped: () -> Void
    
    @State private var showFilePicker = false
    @State private var searchText = ""
    @State private var isSearching = false
    @FocusState private var isFocused: Bool
    @State private var isToolbarExpanded = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Search bar (when searching)
            if isSearching {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search conversations...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    Button(action: { isSearching = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.textBackgroundColor).opacity(0.3))
                )
            } else {
                // Text input field
                HStack(alignment: .center, spacing: 12) {
                    // File attachment button
                    Button(action: { showFilePicker = true }) {
                        Image(systemName: "paperclip")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showFilePicker) {
                        Text("File picker placeholder")
                            .frame(width: 300, height: 400)
                    }
                    
                    TextField("Message AI", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .lineLimit(1...5)
                        .frame(maxWidth: .infinity)
                        .onSubmit {
                            onSubmit()
                        }
                    
                    // Send button
                    Button(action: onSubmit) {
                        Image(systemName: isProcessing ? "ellipsis" : "arrow.up.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(isProcessing)
                }
            }
            
            // Toolbar
            if isToolbarExpanded || isExpanded {
                HStack(spacing: 14) {
                    // Model selector
                    Menu {
                        ForEach(AIModelGroup.allCases, id: \.self) { group in
                            Section(header: Text(group.displayName)) {
                                ForEach(group.models, id: \.self) { model in
                                    Button(model.displayName) {
                                        selectedModel = model
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedModel.displayName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    Spacer()
                    
                    // Tools
                    HStack(spacing: 14) {
                        // Add button (for expanding options)
                        Button(action: { isToolbarExpanded.toggle() }) {
                            Image(systemName: isToolbarExpanded ? "minus" : "plus")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        // Search button
                        Button(action: { isSearching = true }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        // Clear context button
                        Button(action: {}) {
                            Image(systemName: "eraser")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        
                        // Settings button
                        Button(action: onSettingsTapped) {
                            Image(systemName: "gear")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.controlBackgroundColor).opacity(0.4))
        )
        .onChange(of: shouldFocus) { newValue in
            isFocused = newValue
        }
        .onAppear {
            // Initially set focus state based on shouldFocus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = shouldFocus
            }
        }
    }
}

// Visual effect view for translucent background
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// Chat message view
struct MessageView: View {
    let message: ChatMessage
    @State private var copySuccess = false
    
    var body: some View {
        HStack {
            if message.sender == .assistant {
                // AI message (left-aligned)
                VStack(alignment: .leading, spacing: 4) {
                    // Message header
                    HStack {
                        // AI icon
                        Image(systemName: "brain.head.profile")
                            .font(.caption)
                            .foregroundColor(.purple.opacity(0.8))
                        
                        Text("AI")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    // Message content with markdown support
                    MarkdownView(text: message.text)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.windowBackgroundColor).opacity(0.5))
                        )
                        .contextMenu {
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.text, forType: .string)
                                copySuccess = true
                                
                                // Reset the copy success after a delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    copySuccess = false
                                }
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                        .overlay(
                            copySuccess ? 
                                HStack {
                                    Spacer()
                                    Text("Copied!")
                                        .font(.caption)
                                        .padding(6)
                                        .background(Color.accentColor.opacity(0.8))
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                        .transition(.opacity)
                                        .padding(8)
                                } : nil
                        )
                }
                .padding(.trailing, 40)
                
                Spacer()
            } else {
                // User message (right-aligned)
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    // Message header
                    HStack {
                        Spacer()
                        
                        Text(message.timestamp, style: .time)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("You")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        // User icon
                        Image(systemName: "person.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue.opacity(0.8))
                    }
                    
                    // Message content
                    Text(message.text)
                        .textSelection(.enabled)
                        .multilineTextAlignment(.trailing)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.blue.opacity(0.15))
                        )
                        .contextMenu {
                            Button(action: {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(message.text, forType: .string)
                            }) {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                }
                .padding(.leading, 40)
            }
        }
        .padding(.vertical, 4)
    }
}

// Markdown rendering view
struct MarkdownView: View {
    let text: String
    
    var body: some View {
        Text(.init(self.processMarkdown(text)))
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    // Process code blocks and other markdown elements
    private func processMarkdown(_ text: String) -> String {
        // Process code blocks and other markdown
        // This is a simple implementation, in a real app you'd use a proper markdown parser
        // or a library like MarkdownUI
        var processed = text
            .replacingOccurrences(of: "```([^`]*)```", with: "```\n$1\n```", options: .regularExpression)
        
        return processed
    }
}

// Settings view for API keys and preferences
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTab = 0
    
    // API Keys
    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var xAIKey: String = ""
    
    // Appearance settings
    @State private var isDarkMode: Bool = true
    @State private var alwaysOnTop: Bool = true
    @State private var enableSound: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            // Tabs
            HStack(spacing: 0) {
                TabButton(title: "API Keys", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                TabButton(title: "Appearance", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                
                TabButton(title: "About", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
            }
            .padding(.horizontal)
            
            Divider()
            
            // Tab content
            TabView(selection: $selectedTab) {
                // API Keys Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // OpenAI
                        ProviderSettingsView(
                            logoName: "openai-logo",
                            title: "OpenAI",
                            description: "Enter your OpenAI API key for accessing GPT models.",
                            apiKey: $openAIKey,
                            placeholder: "sk-..."
                        )
                        
                        // Anthropic
                        ProviderSettingsView(
                            logoName: "anthropic-logo",
                            title: "Anthropic",
                            description: "Enter your Anthropic API key for accessing Claude models.",
                            apiKey: $anthropicKey,
                            placeholder: "sk-ant-..."
                        )
                        
                        // X.AI
                        ProviderSettingsView(
                            logoName: "xai-logo",
                            title: "X.AI",
                            description: "Enter your X.AI API key for accessing Grok models.",
                            apiKey: $xAIKey,
                            placeholder: "sk-..."
                        )
                    }
                    .padding()
                }
                .tag(0)
                
                // Appearance Tab
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Display")
                            .font(.headline)
                            .padding(.top, 8)
                        
                        Toggle("Dark Mode", isOn: $isDarkMode)
                        Toggle("Always on Top", isOn: $alwaysOnTop)
                        Toggle("Enable Sound Effects", isOn: $enableSound)
                        
                        Text("Keyboard Shortcuts")
                            .font(.headline)
                            .padding(.top, 16)
                        
                        KeyboardShortcutRow(name: "Toggle window", shortcut: "⌥ Space")
                        KeyboardShortcutRow(name: "Show window", shortcut: "⌥⇧ Space")
                    }
                    .padding()
                }
                .tag(1)
                
                // About Tab
                VStack(spacing: 20) {
                    Image(systemName: "bubble.left.and.text.bubble.right.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.accentColor)
                    
                    Text("FloatingChat")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Version 1.0.0")
                        .foregroundColor(.secondary)
                    
                    Text("A floating AI chat assistant for macOS")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 32)
                    
                    Spacer()
                }
                .padding()
                .tag(2)
            }
            .tabViewStyle(.automatic)
            .animation(.easeInOut, value: selectedTab)
            
            // Action buttons
            HStack {
                Spacer()
                
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Save") {
                    saveSettings()
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func saveSettings() {
        // API Keys
        if !openAIKey.isEmpty {
            AIService.shared.setAPIKey(openAIKey, for: "openai")
        }
        
        if !anthropicKey.isEmpty {
            AIService.shared.setAPIKey(anthropicKey, for: "anthropic")
        }
        
        if !xAIKey.isEmpty {
            AIService.shared.setAPIKey(xAIKey, for: "xai")
        }
        
        // TODO: Save appearance settings
    }
    
    private func loadSettings() {
        // In a real app, you would load these from secure storage
        // For this demo, we'll leave them empty
    }
}

// Tab button
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .padding(.vertical, 8)
                
                Rectangle()
                    .frame(height: 2)
                    .foregroundColor(isSelected ? .accentColor : .clear)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }
}

// Provider settings view
struct ProviderSettingsView: View {
    let logoName: String
    let title: String
    let description: String
    @Binding var apiKey: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Use a placeholder for the logo
                // In a real app, you would use actual logos
                Image(systemName: "building.2")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                
                Text(title)
                    .font(.headline)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            SecureField(placeholder, text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .padding(.top, 4)
        }
    }
}

// Keyboard shortcut row
struct KeyboardShortcutRow: View {
    let name: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(name)
            
            Spacer()
            
            Text(shortcut)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.textBackgroundColor).opacity(0.4))
                )
                .font(.system(.caption, design: .monospaced))
        }
    }
}

// Chat message model
struct ChatMessage: Identifiable {
    let id: String
    let text: String
    let sender: MessageSender
    let timestamp: Date
}

enum MessageSender {
    case user
    case assistant
}

// AI model options with DisplayName support
enum AIModel: String, CaseIterable {
    // OpenAI models
    case gpt4o = "gpt-4o"
    case gpt4oMini = "gpt-4o-mini"
    case gpt4 = "gpt-4"
    case gpt4Turbo = "gpt-4-turbo"
    case gpt35Turbo = "gpt-3.5-turbo"
    
    // Anthropic models
    case claudeHaiku = "claude-haiku"
    case claudeSonnet = "claude-3-sonnet"
    case claudeOpus = "claude-3-opus"
    
    
    // x.ai models
    case grok1 = "grok-1"
    
    // google models
    var displayName: String {
        switch self {
        case .gpt4o: return "GPT-4o"
        case .gpt4oMini: return "GPT-4o Mini"
        case .gpt4: return "GPT-4"
        case .gpt4Turbo: return "GPT-4 Turbo"
        case .gpt35Turbo: return "GPT-3.5 Turbo"
        case .claudeHaiku: return "Claude Haiku"
        case .claudeSonnet: return "Claude 3 Sonnet"
        case .claudeOpus: return "Claude 3 Opus"
        case .grok1: return "Grok-1"
        }
    }
    
    var provider: AIProvider {
        switch self {
        case .gpt4o, .gpt4oMini, .gpt4, .gpt4Turbo, .gpt35Turbo:
            return .openAI
        case .claudeHaiku, .claudeSonnet, .claudeOpus:
            return .anthropic
        case .grok1:
            return .xAI
        }
    }
}

// AI providers
enum AIProvider: String, CaseIterable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case xAI = "X.AI"
}

// Model grouping for UI
enum AIModelGroup: String, CaseIterable {
    case openAI = "OpenAI"
    case anthropic = "Anthropic"
    case xAI = "X.AI"
    
    var displayName: String {
        return self.rawValue
    }
    
    var models: [AIModel] {
        switch self {
        case .openAI:
            return [.gpt4o, .gpt4oMini, .gpt4Turbo, .gpt4, .gpt35Turbo]
        case .anthropic:
            return [.claudeOpus, .claudeSonnet, .claudeHaiku]
        case .xAI:
            return [.grok1]
        }
    }
}

// Helper class to store cancellables
class CancellableContainer {
    var cancellables = Set<AnyCancellable>()
}

// File attachment view for the input field
struct FileAttachmentView: View {
    let fileURL: URL
    let onRemove: () -> Void
    
    @State private var icon: String = "doc"
    @State private var color: Color = .blue
    
    var body: some View {
        HStack(spacing: 4) {
            // File icon
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)
            
            // File name (truncated)
            Text(fileURL.lastPathComponent)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.textBackgroundColor).opacity(0.2))
        )
        .onAppear {
            // Set appropriate icon and color based on file type
            let fileExtension = fileURL.pathExtension.lowercased()
            
            if ["jpg", "jpeg", "png", "gif", "heic"].contains(fileExtension) {
                icon = "photo"
                color = .green
            } else if ["pdf", "doc", "docx", "txt", "rtf"].contains(fileExtension) {
                icon = "doc.text"
                color = .blue
            } else if ["xls", "xlsx", "csv"].contains(fileExtension) {
                icon = "chart.bar.doc.horizontal"
                color = .green
            } else if ["mp3", "wav", "aac", "m4a"].contains(fileExtension) {
                icon = "music.note"
                color = .purple
            } else if ["mp4", "mov", "avi", "mkv"].contains(fileExtension) {
                icon = "film"
                color = .indigo
            } else if ["zip", "rar", "tar", "gz"].contains(fileExtension) {
                icon = "archivebox"
                color = .orange
            } else {
                icon = "doc"
                color = .blue
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(FloatingWindowController())
}
