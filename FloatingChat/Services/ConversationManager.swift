//
//  ConversationManager.swift
//  FloatingChat
//
//  Created for FloatingChat on 2025/3/21.
//

import Foundation
import Combine
import CoreData

/// Class responsible for managing conversations and context
class ConversationManager: ObservableObject {
    static let shared = ConversationManager()
    
    @Published var currentConversation: Conversation
    @Published var recentConversations: [Conversation] = []
    
    private let aiService = AIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let maxContextWindowTokens: [AIModel: Int] = [
        .gpt4: 8192,
        .gpt4o: 16384,
    ]
    
    // Rough approximation of tokens per word (actual tokenization is more complex)
    private let estimatedTokensPerWord = 1.3
    
    private init() {
        // Start with a new conversation
        currentConversation = Conversation(id: UUID().uuidString, title: "New Chat", messages: [], createdAt: Date())
        
        // Load recent conversations from storage
        loadRecentConversations()
    }
    
    /// Load recent conversations from persistent storage
    private func loadRecentConversations() {
        // In a real app, load these from Core Data
        // This is a placeholder
        recentConversations = []
    }
    
    /// Create a new conversation
    func createNewConversation() {
        // Save current conversation if it has messages
        if !currentConversation.messages.isEmpty {
            saveCurrentConversation()
        }
        
        // Create a new conversation
        currentConversation = Conversation(
            id: UUID().uuidString,
            title: "New Chat",
            messages: [],
            createdAt: Date()
        )
    }
    
    /// Add a message to the current conversation
    /// - Parameter message: The message to add
    func addMessage(_ message: ChatMessage) {
        currentConversation.messages.append(message)
        
        // If this is the first user message, generate a title
        if currentConversation.messages.count == 1 && message.sender == .user {
            generateConversationTitle(from: message.text)
        }
    }
    
    /// Generate a title for the conversation based on the first user message
    /// - Parameter text: The text of the first message
    private func generateConversationTitle(from text: String) {
        // For simplicity, just take the first few words
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        let titleWords = words.prefix(4)
        var title = titleWords.joined(separator: " ")
        
        if title.count < text.count {
            title += "..."
        }
        
        currentConversation.title = title
    }
    
    /// Save the current conversation to persistent storage
    func saveCurrentConversation() {
        // In a real app, save to Core Data
        // Add to recent conversations
        if let index = recentConversations.firstIndex(where: { $0.id == currentConversation.id }) {
            recentConversations[index] = currentConversation
        } else {
            recentConversations.insert(currentConversation, at: 0)
        }
    }
    
    /// Load a specific conversation
    /// - Parameter conversationId: The ID of the conversation to load
    func loadConversation(id conversationId: String) {
        // Save current conversation first
        saveCurrentConversation()
        
        // Find and load the requested conversation
        if let conversation = recentConversations.first(where: { $0.id == conversationId }) {
            currentConversation = conversation
        }
    }
    
    /// Delete a conversation
    /// - Parameter conversationId: The ID of the conversation to delete
    func deleteConversation(id conversationId: String) {
        recentConversations.removeAll { $0.id == conversationId }
        
        // If we deleted the current conversation, create a new one
        if currentConversation.id == conversationId {
            createNewConversation()
        }
    }
    
    /// Send a message to the AI and get a response
    /// - Parameters:
    ///   - text: The message text to send
    ///   - model: The AI model to use
    /// - Returns: A publisher that emits the AI response message
    func sendMessageToAI(text: String, model: AIModel) -> AnyPublisher<ChatMessage, Error> {
        // Create user message
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            text: text,
            sender: .user,
            timestamp: Date()
        )
        
        // Add to conversation
        addMessage(userMessage)
        
        // Prepare context (previous messages)
        let context = prepareContextForModel(model: model)
        
        // Send to AI service
        return aiService.sendChatRequest(
            messages: context,
            model: model
        )
        .handleEvents(receiveOutput: { [weak self] message in
            // Add AI response to conversation
            self?.addMessage(message)
            
            // Save the conversation
            self?.saveCurrentConversation()
        })
        .eraseToAnyPublisher()
    }
    
    /// Stream a message to the AI and get a streaming response
    /// - Parameters:
    ///   - text: The message text to send
    ///   - model: The AI model to use
    /// - Returns: A publisher that emits chunks of the AI response
    func streamMessageToAI(text: String, model: AIModel) -> AnyPublisher<String, Error> {
        // Create user message
        let userMessage = ChatMessage(
            id: UUID().uuidString,
            text: text,
            sender: .user,
            timestamp: Date()
        )
        
        // Add to conversation
        addMessage(userMessage)
        
        // Prepare context (previous messages)
        let context = prepareContextForModel(model: model)
        
        // Create a placeholder for the AI response
        let aiMessage = ChatMessage(
            id: UUID().uuidString,
            text: "",
            sender: .assistant,
            timestamp: Date()
        )
        addMessage(aiMessage)
        
        // Stream from AI service
        var responseText = ""
        
        return aiService.streamChatRequest(
            messages: context,
            model: model
        )
        .handleEvents(receiveOutput: { [weak self] chunk in
            responseText += chunk
            
            // Update the placeholder message with accumulated text
            if let index = self?.currentConversation.messages.lastIndex(where: { $0.id == aiMessage.id }) {
                self?.currentConversation.messages[index] = ChatMessage(
                    id: aiMessage.id,
                    text: responseText,
                    sender: .assistant,
                    timestamp: aiMessage.timestamp
                )
            }
        }, receiveCompletion: { [weak self] completion in
            // Save the conversation when streaming completes
            if case .finished = completion {
                self?.saveCurrentConversation()
            }
        })
        .eraseToAnyPublisher()
    }
    
    /// Prepare the context window for a specific AI model, pruning if necessary
    /// - Parameter model: The AI model to prepare context for
    /// - Returns: Array of messages to send as context
    private func prepareContextForModel(model: AIModel) -> [ChatMessage] {
        // Get max tokens for this model
        let maxTokens = maxContextWindowTokens[model] ?? 8192
        
        // Get all messages in the current conversation
        var context = currentConversation.messages
        
        // Calculate approximate token count
        var tokenCount = estimateTokenCount(for: context)
        
        // If we're over the limit, prune the context
        if tokenCount > maxTokens {
            context = pruneContext(context, maxTokens: maxTokens)
        }
        
        return context
    }
    
    /// Estimate the token count for a list of messages
    /// - Parameter messages: The messages to estimate tokens for
    /// - Returns: Estimated token count
    private func estimateTokenCount(for messages: [ChatMessage]) -> Int {
        // Simple estimation based on word count
        let wordCount = messages.reduce(0) { count, message in
            count + message.text.components(separatedBy: .whitespacesAndNewlines).count
        }
        
        // Add overhead for message metadata
        let metadataTokens = messages.count * 10
        
        return Int(Double(wordCount) * estimatedTokensPerWord) + metadataTokens
    }
    
    /// Prune the context to fit within token limits
    /// - Parameters:
    ///   - messages: The messages to prune
    ///   - maxTokens: The maximum number of tokens allowed
    /// - Returns: Pruned list of messages
    private func pruneContext(_ messages: [ChatMessage], maxTokens: Int) -> [ChatMessage] {
        // Always keep the most recent messages
        var prunedMessages: [ChatMessage] = []
        var currentTokenCount = 0
        
        // Start from the most recent messages and work backwards
        for message in messages.reversed() {
            let messageTokens = estimateTokenCount(for: [message])
            
            // If adding this message would exceed the limit, stop
            if currentTokenCount + messageTokens > maxTokens {
                break
            }
            
            // Add this message to our pruned list
            prunedMessages.insert(message, at: 0)
            currentTokenCount += messageTokens
        }
        
        return prunedMessages
    }
}

/// Representation of a conversation
struct Conversation: Identifiable, Equatable {
    let id: String
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    
    static func == (lhs: Conversation, rhs: Conversation) -> Bool {
        return lhs.id == rhs.id
    }
} 
