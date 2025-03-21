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
    @EnvironmentObject private var windowController: WindowController
    
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
                        .padding()
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
            }
            
            // Input area
            InputFieldView(
                text: $inputText,
                isProcessing: $isProcessing,
                selectedModel: $selectedModel,
                onSubmit: sendMessage,
                isExpanded: windowController.isExpanded,
                shouldFocus: isInputFocused,
                onSettingsTapped: { isPresentingSettings = true }
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(NSColor.windowBackgroundColor))
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 0)
            )
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .cornerRadius(16)
        .onAppear {
            // Focus the input field when the view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isInputFocused = true
            }
            setupKeyboardShortcuts()
        }
        .sheet(isPresented: $isPresentingSettings) {
            SettingsView()
        }
        .preferredColorScheme(.dark)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environmentObject(conversationManager)
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
        KeyboardShortcuts.onKeyUp(for: .toggleFloatingChat) { [self] in
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
        KeyboardShortcuts.onKeyUp(for: .showFloatingChat) { [self] in
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
    
    @FocusState private var isFocused: Bool
    @State private var isToolbarExpanded = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Text input field
            HStack(alignment: .center) {
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
            
            // Toolbar
            if isToolbarExpanded || isExpanded {
                HStack(spacing: 12) {
                    // Add button (for expanding options)
                    Button(action: { isToolbarExpanded.toggle() }) {
                        Image(systemName: "plus")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    
                    // Web search button
                    Button(action: {}) {
                        Image(systemName: "globe")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    
                    // Reference button
                    Button(action: {}) {
                        Image(systemName: "doc.text")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    
                    // Settings button
                    Button(action: onSettingsTapped) {
                        Image(systemName: "gear")
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Model selector
                    Menu {
                        Picker("Model", selection: $selectedModel) {
                            ForEach(AIModel.allCases, id: \.self) { model in
                                Text(model.rawValue).tag(model)
                            }
                        }
                    } label: {
                        Text(selectedModel.rawValue)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
                .transition(.opacity)
            }
        }
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
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(message.sender == .user ? "You" : "AI")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(message.text)
                .textSelection(.enabled)
                .padding(10)
                .background(message.sender == .user ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                .cornerRadius(12)
        }
        .padding(.vertical, 4)
    }
}

// Settings view for API keys and preferences
struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var openAIKey: String = ""
    @State private var anthropicKey: String = ""
    @State private var geminiKey: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("API Settings")
                .font(.title)
                .padding(.bottom, 10)
            
            VStack(alignment: .leading) {
                Text("OpenAI API Key")
                    .font(.headline)
                SecureField("Enter OpenAI API Key", text: $openAIKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading) {
                Text("Anthropic API Key")
                    .font(.headline)
                SecureField("Enter Anthropic API Key", text: $anthropicKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading) {
                Text("Google Gemini API Key")
                    .font(.headline)
                SecureField("Enter Google Gemini API Key", text: $geminiKey)
                    .textFieldStyle(.roundedBorder)
            }
            
            Spacer()
            
            HStack {
                Spacer()
                Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
                Button("Save") {
                    saveAPIKeys()
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
        .onAppear {
            loadAPIKeys()
        }
    }
    
    private func saveAPIKeys() {
        if !openAIKey.isEmpty {
            AIService.shared.setAPIKey(openAIKey, for: "openai")
        }
        
        if !anthropicKey.isEmpty {
            AIService.shared.setAPIKey(anthropicKey, for: "anthropic")
        }
        
        if !geminiKey.isEmpty {
            AIService.shared.setAPIKey(geminiKey, for: "gemini")
        }
    }
    
    private func loadAPIKeys() {
        // In a real app, you would load these from secure storage
        // For this demo, we'll leave them empty
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

// AI model options
enum AIModel: String, CaseIterable {
    case gpt4o = "GPT-4o"
    case gpt4 = "GPT-4"
    case claude3 = "Claude 3"
    case gemini = "Gemini"
}

// Helper class to store cancellables
class CancellableContainer {
    var cancellables = Set<AnyCancellable>()
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(WindowController())
}
