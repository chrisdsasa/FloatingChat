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
}

/// Main service class that coordinates AI providers
class AIService {
    static let shared = AIService()
    
    // Available service providers
    private var providers: [AIModel: AIServiceProvider] = [:]
    
    // Configuration
    private var apiKeys: [String: String] = [:]
    private var requestCache = RequestCache()
    
    private init() {
        // Register providers
        providers[.gpt4] = OpenAIProvider()
        providers[.gpt4o] = OpenAIProvider()
        providers[.claude3] = AnthropicProvider()
        providers[.gemini] = GeminiProvider()
        
        // Load API keys from secure storage (implement this)
        loadAPIKeys()
    }
    
    private func loadAPIKeys() {
        // In a real app, load these from Keychain
        #if DEBUG
        // For development only
        apiKeys["openai"] = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
        apiKeys["anthropic"] = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"] ?? ""
        apiKeys["gemini"] = ProcessInfo.processInfo.environment["GEMINI_API_KEY"] ?? ""
        #endif
    }
    
    /// Set API key for a specific provider
    /// - Parameters:
    ///   - key: The API key
    ///   - provider: The provider name
    func setAPIKey(_ key: String, for provider: String) {
        apiKeys[provider] = key
        
        // Update the key in the corresponding provider
        for (model, provider) in providers {
            if let openAIProvider = provider as? OpenAIProvider, 
               provider == "openai" {
                openAIProvider.apiKey = key
            } else if let anthropicProvider = provider as? AnthropicProvider,
                      provider == "anthropic" {
                anthropicProvider.apiKey = key
            } else if let geminiProvider = provider as? GeminiProvider,
                      provider == "gemini" {
                geminiProvider.apiKey = key
            }
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
        guard let provider = providers[model] else {
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
        guard let provider = providers[model] else {
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
                    text: "This is a simulated response from OpenAI's \(model.rawValue) model.",
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
        // This is a placeholder that simulates a streaming response
        let responseChunks = [
            "This ", "is ", "a ", "simulated ", "streaming ", "response ", 
            "from ", "OpenAI's ", model.rawValue, " model."
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
                    text: "This is a simulated response from Anthropic's Claude 3 model.",
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
            "from ", "Anthropic's ", "Claude 3", " model."
        ]
        
        return Publishers.Sequence(sequence: responseChunks)
            .delay(for: .seconds(0.1), scheduler: DispatchQueue.global())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
}

/// Gemini Service Provider implementation
class GeminiProvider: AIServiceProvider {
    var apiKey: String = ""
    
    func sendChatRequest(
        messages: [ChatMessage],
        model: AIModel,
        temperature: Double,
        maxTokens: Int?
    ) -> AnyPublisher<ChatMessage, Error> {
        // Implement actual Gemini API call
        // This is a placeholder that simulates a response
        return Future<ChatMessage, Error> { promise in
            // Simulate network delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                let response = ChatMessage(
                    id: UUID().uuidString,
                    text: "This is a simulated response from Google's Gemini model.",
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
        // Implement actual Gemini streaming API call
        // This is a placeholder that simulates a streaming response
        let responseChunks = [
            "This ", "is ", "a ", "simulated ", "streaming ", "response ", 
            "from ", "Google's ", "Gemini", " model."
        ]
        
        return Publishers.Sequence(sequence: responseChunks)
            .delay(for: .seconds(0.1), scheduler: DispatchQueue.global())
            .setFailureType(to: Error.self)
            .eraseToAnyPublisher()
    }
} 