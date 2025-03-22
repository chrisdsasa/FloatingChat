//
//  AIModel.swift
//  FloatingChat
//
//  Created for FloatingChat on 2025/3/23.
//

import Foundation

// AI model options
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