//
//  AIService.swift
//  FloatingChat
//
//  Created for FloatingChat on 2025/3/21.
//

import Foundation
import Combine

// MARK: - Public API

/// Protocol defining the interface for all AI service providers
protocol AIServiceProvider {
    /// Send a chat message to the AI service
    /// - Parameters:
    ///   - messages: Array of previous messages for context
    ///   - model: The AI model to use
    ///   - temperature: Sampling temperature (0.0 to 1.0)
    ///   - maxTokens: Maximum number of tokens to generate
    /// - Returns: A publisher that emits the AI response or an error
    func sendChatRequest(
        messages: [ChatMessage],
        model: AIModel,
        temperature: Double,
        maxTokens: Int?
    ) -> AnyPublisher<ChatMessage, Error>
    
    /// Stream a chat response from the AI service
    /// - Parameters:
    ///   - messages: Array of previous messages for context
    ///   - model: The AI model to use
    ///   - temperature: Sampling temperature (0.0 to 1.0)
    ///   - maxTokens: Maximum number of tokens to generate
    /// - Returns: A publisher that emits chunks of the AI response or an error
    func streamChatRequest(
        messages: [ChatMessage],
        model: AIModel,
        temperature: Double,
        maxTokens: Int?
    ) -> AnyPublisher<String, Error>
    
    /// Set the API key for this provider
    func setApiKey(_ key: String)
    
    /// Get the name of the provider
    var providerName: String { get }
    
    /// Get supported models
    var supportedModels: [AIModel] { get }
}

/// Enumeration of supported AI providers
enum AIProvider: String {
    case openAI
    case anthropic
    case xAI
}

/// Main service class that coordinates AI providers
class AIService: ObservableObject {
    static let shared = AIService()
    
    // Available service providers mapped by provider type
    private var providersByType: [AIProvider: AIServiceProvider] = [:]
    
    // Configuration
    private var apiKeys: [String: String] = [:]
    private var requestCache = RequestCache()
    
    private init() {
        // Register providers
        let openAIProvider = OpenAIProvider()
        let anthropicProvider = AnthropicProvider()
        let xAIProvider = XAIProvider()
        
        providersByType[.openAI] = openAIProvider
        providersByType[.anthropic] = anthropicProvider
        providersByType[.xAI] = xAIProvider
        
        // Load API keys from secure storage (implement this)
        loadAPIKeys()
    }
    
    private func loadAPIKeys() {
        // In a real app, load these from Keychain
        #if DEBUG
        // For development only
        apiKeys["openai"] = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        apiKeys["anthropic"] = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        apiKeys["xai"] = ProcessInfo.processInfo.environment["XAI_API_KEY"] ?? ""
        #endif
    }
    
    func setAPIKey(_ key: String, for provider: String) {
        apiKeys[provider] = key
        
        // Find the provider instance and update the key
        switch provider.lowercased() {
        case "openai":
            providersByType[.openAI]?.setApiKey(key)
        case "anthropic":
            providersByType[.anthropic]?.setApiKey(key)
        case "xai":
            providersByType[.xAI]?.setApiKey(key)
        default:
            break
        }
    }
    
    /// Send a chat request to the appropriate service provider
    /// - Parameters:
    ///   - messages: Array of previous messages for context
    ///   - model: The AI model to use
    ///   - temperature: Sampling temperature (0.0 to 1.0)
    ///   - maxTokens: Maximum number of tokens to generate
    /// - Returns: A publisher that emits the AI response or an error
    func sendChatRequest(
        messages: [ChatMessage],
        model: AIModel,
        temperature: Double = 0.7,
        maxTokens: Int? = nil
    ) -> AnyPublisher<ChatMessage, Error> {
        // Check if we have a cached response
        if let cachedResponse = requestCache.getCachedResponse(for: messages, model: model) {
            return Just(cachedResponse)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
        
        // Get the appropriate provider for the selected model
        guard let provider = providersByType[model.provider] else {
            return Fail(error: AIServiceError.unsupportedModel)
                .eraseToAnyPublisher()
        }
        
        // Send the request to the provider
        return provider.sendChatRequest(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens
        )
        .handleEvents(receiveOutput: { [weak self] response in
            // Cache the response
            self?.requestCache.cacheResponse(response, for: messages, model: model)
        })
        .eraseToAnyPublisher()
    }
    
    /// Stream a chat response from the appropriate service provider
    /// - Parameters:
    ///   - messages: Array of previous messages for context
    ///   - model: The AI model to use
    ///   - temperature: Sampling temperature (0.0 to 1.0)
    ///   - maxTokens: Maximum number of tokens to generate
    /// - Returns: A publisher that emits chunks of the AI response or an error
    func streamChatRequest(
        messages: [ChatMessage],
        model: AIModel,
        temperature: Double = 0.7,
        maxTokens: Int? = nil
    ) -> AnyPublisher<String, Error> {
        // Get the appropriate provider for the selected model
        guard let provider = providersByType[model.provider] else {
            return Fail(error: AIServiceError.unsupportedModel)
                .eraseToAnyPublisher()
        }
        
        // Stream the request from the provider
        return provider.streamChatRequest(
            messages: messages,
            model: model,
            temperature: temperature,
            maxTokens: maxTokens
        )
        .eraseToAnyPublisher()
    }
}

// MARK: - Implementation Details

/// Error types for AI service
enum AIServiceError: Error {
    case invalidAPIKey
    case unsupportedModel
    case rateLimitExceeded
    case networkError(Error)
    case unexpectedResponse
    case contextTooLarge
}

/// Simple in-memory cache for AI requests
class RequestCache {
    private var cache: [String: ChatMessage] = [:]
    private let maxCacheSize = 100
    
    func getCachedResponse(for messages: [ChatMessage], model: AIModel) -> ChatMessage? {
        let key = cacheKey(for: messages, model: model)
        return cache[key]
    }
    
    func cacheResponse(_ response: ChatMessage, for messages: [ChatMessage], model: AIModel) {
        let key = cacheKey(for: messages, model: model)
        
        // Limit cache size with simple LRU approach
        if cache.count >= maxCacheSize {
            cache.removeValue(forKey: cache.keys.first ?? "")
        }
        
        cache[key] = response
    }
    
    private func cacheKey(for messages: [ChatMessage], model: AIModel) -> String {
        // Create a unique key based on messages and model
        let messagesHash = messages.map { $0.text }.joined().hashValue
        return "\(model.rawValue)_\(messagesHash)"
    }
}

/// OpenAI Service Provider implementation
class OpenAIProvider: AIServiceProvider {
    var apiKey: String = ""
    
    var providerName: String { return "OpenAI" }
    
    var supportedModels: [AIModel] {
        return [.gpt4o, .gpt4oMini, .gpt4, .gpt4Turbo, .gpt35Turbo]
    }
    
    func setApiKey(_ key: String) {
        apiKey = key
    }
    
    func sendChatRequest(
        messages: [ChatMessage],
        model: AIModel,
        temperature: Double,
        maxTokens: Int?
    ) -> AnyPublisher<ChatMessage, Error> {
        // Implement actual OpenAI API call
        // This is a placeholder that simulates a response
        return Future<ChatMessage, Error> { promise in
            // Simulate network delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                let response = ChatMessage(
                    id: UUID().uuidString,
                    text: "This is a simulated response from OpenAI's \(model.displayName) model.\n\n**Features:**\n- Markdown support\n- Code highlighting\n- Bullet points",
                    sender: .assistant,
                    timestamp: Date()
                )
                promise(.success(response))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func streamChatRequest(
        messages: [ChatMessage],
        model: AIModel,
        temperature: Double,
        maxTokens: Int?
    ) -> AnyPublisher<String, Error> {
        // Implement actual OpenAI streaming API call
        // This is a placeholder that simulates a streaming response with markdown
        let responseChunks = [
            "This ", "is ", "a ", "simulated ", "streaming ", "response ", 
            "from ", "OpenAI's ", model.displayName, " model.\n\n",
            "**Key ", "features:**\n\n",
            "- Markdown ", "support\n",
            "- Code ", "highlighting\n",
            "```swift\n",
            "func ", "hello", "() ", "{\n",
            "    ", "print", "(\"", "Hello", ", ", "world", "!\")\n",
            "}\n```\n",
            "- Bullet ", "points"
        ]
        
        return Publishers.Sequence(sequence: responseChunks)
            .delay(for: .seconds(0.1), scheduler: DispatchQueue.global())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

/// Anthropic Service Provider implementation
class AnthropicProvider: AIServiceProvider {
    var apiKey: String = ""
    
    var providerName: String { return "Anthropic" }
    
    var supportedModels: [AIModel] {
        return [.claudeOpus, .claudeSonnet, .claudeHaiku]
    }
    
    func setApiKey(_ key: String) {
        apiKey = key
    }
    
    func sendChatRequest(
        messages: [ChatMessage],
        model: AIModel,
        temperature: Double,
        maxTokens: Int?
    ) -> AnyPublisher<ChatMessage, Error> {
        // Implement actual Anthropic API call
        // This is a placeholder that simulates a response
        return Future<ChatMessage, Error> { promise in
            // Simulate network delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.2) {
                let response = ChatMessage(
                    id: UUID().uuidString,
                    text: "This is a simulated response from Anthropic's \(model.displayName) model.\n\n**Markdown** is supported as well as `code blocks` and other formatting.",
                    sender: .assistant,
                    timestamp: Date()
                )
                promise(.success(response))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func streamChatRequest(
        messages: [ChatMessage],
        model: AIModel,
        temperature: Double,
        maxTokens: Int?
    ) -> AnyPublisher<String, Error> {
        // Implement actual Anthropic streaming API call
        // This is a placeholder that simulates a streaming response
        let responseChunks = [
            "This ", "is ", "a ", "simulated ", "streaming ", "response ", 
            "from ", "Anthropic's ", model.displayName, " model.\n\n",
            "**Markdown** ", "is ", "supported ", "as ", "well ", 
            "as ", "`code ", "blocks` ", "and ", "other ", "formatting."
        ]
        
        return Publishers.Sequence(sequence: responseChunks)
            .delay(for: .seconds(0.1), scheduler: DispatchQueue.global())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

/// X.AI Service Provider implementation
class XAIProvider: AIServiceProvider {
    var apiKey: String = ""
    
    var providerName: String { return "X.AI" }
    
    var supportedModels: [AIModel] {
        return [.grok1]
    }
    
    func setApiKey(_ key: String) {
        apiKey = key
    }
    
    func sendChatRequest(
        messages: [ChatMessage],
        model: AIModel,
        temperature: Double,
        maxTokens: Int?
    ) -> AnyPublisher<ChatMessage, Error> {
        // Implement actual X.AI API call
        // This is a placeholder that simulates a response
        return Future<ChatMessage, Error> { promise in
            // Simulate network delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                let response = ChatMessage(
                    id: UUID().uuidString,
                    text: "This is a simulated response from X.AI's \(model.displayName) model.\n\nI can format responses with *italics* or **bold** text.",
                    sender: .assistant,
                    timestamp: Date()
                )
                promise(.success(response))
            }
        }
        .eraseToAnyPublisher()
    }
    
    func streamChatRequest(
        messages: [ChatMessage],
        model: AIModel,
        temperature: Double,
        maxTokens: Int?
    ) -> AnyPublisher<String, Error> {
        // Implement actual X.AI streaming API call
        // This is a placeholder that simulates a streaming response
        let responseChunks = [
            "This ", "is ", "a ", "simulated ", "streaming ", "response ", 
            "from ", "X.AI's ", model.displayName, " model.\n\n",
            "I ", "can ", "format ", "responses ", "with ", 
            "*italics* ", "or ", "**bold** ", "text."
        ]
        
        return Publishers.Sequence(sequence: responseChunks)
            .delay(for: .seconds(0.1), scheduler: DispatchQueue.global())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
} 
