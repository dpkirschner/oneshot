import SwiftUI
import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [DisplayMessage] = []
    @Published var isGenerating = false
    @Published var error: String?
    
    private var sessionManager: SessionManager?
    private var contextManager: ContextManager?
    private var currentGenerationTask: Task<Void, Never>?
    
    func setup(sessionManager: SessionManager, contextManager: ContextManager) {
        self.sessionManager = sessionManager
        self.contextManager = contextManager
        
        // Load existing messages if there's a current session
        loadSessionMessages()
    }
    
    func sendMessage(_ content: String) async {
        guard let sessionManager = sessionManager,
              let contextManager = contextManager else { return }
        
        // Stop any existing generation
        stopGeneration()
        
        // Create user message
        let userMessage = DisplayMessage(
            content: content,
            role: .user,
            contextItems: contextManager.activeContextItems
        )
        
        messages.append(userMessage)
        isGenerating = true
        error = nil
        
        // Create assistant message placeholder
        let assistantMessage = DisplayMessage.empty(role: .assistant)
        messages.append(assistantMessage)
        
        currentGenerationTask = Task {
            do {
                // This is a placeholder - actual LLM integration will be implemented later
                await simulateResponse(for: content)
                
                // Save messages to session
                await saveMessagesToSession(userMessage: userMessage)
                
            } catch {
                await handleError(error)
            }
            
            await MainActor.run {
                isGenerating = false
                currentGenerationTask = nil
            }
        }
    }
    
    func stopGeneration() {
        currentGenerationTask?.cancel()
        currentGenerationTask = nil
        isGenerating = false
    }
    
    func clearMessages() {
        messages.removeAll()
        error = nil
    }
    
    func retryLastMessage() {
        guard let lastUserMessage = messages.last(where: { $0.role == .user }) else { return }
        
        // Remove any assistant messages after the last user message
        if let lastUserIndex = messages.lastIndex(where: { $0.role == .user }) {
            messages = Array(messages.prefix(through: lastUserIndex))
        }
        
        Task {
            await sendMessage(lastUserMessage.content)
        }
    }
    
    private func loadSessionMessages() {
        guard let session = sessionManager?.currentSession else { return }
        
        messages = session.messages.map { DisplayMessage(from: $0) }
    }
    
    private func simulateResponse(for input: String) async {
        // Simulate streaming response
        let responses = [
            "I understand you're asking about: \"\(input)\"",
            "\n\nLet me help you with that. ",
            "Based on the context you've provided, ",
            "I can see you're working with some interesting code. ",
            "\n\nHere's what I recommend:\n\n",
            "1. First, consider the architecture patterns\n",
            "2. Think about error handling\n", 
            "3. Don't forget about testing\n\n",
            "Would you like me to elaborate on any of these points?"
        ]
        
        for (index, chunk) in responses.enumerated() {
            // Check if task was cancelled
            if Task.isCancelled { return }
            
            await MainActor.run {
                if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                    messages[lastIndex].content += chunk
                }
            }
            
            // Simulate network delay
            try? await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...300_000_000))
        }
        
        await MainActor.run {
            if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                messages[lastIndex] = DisplayMessage(
                    id: messages[lastIndex].id,
                    content: messages[lastIndex].content,
                    role: .assistant,
                    timestamp: messages[lastIndex].timestamp,
                    contextItems: [],
                    isStreaming: false
                )
            }
        }
    }
    
    private func saveMessagesToSession(userMessage: DisplayMessage) async {
        guard let sessionManager = sessionManager,
              let session = sessionManager.currentSession,
              let assistantMessage = messages.last(where: { $0.role == .assistant }) else { return }
        
        do {
            // Convert display messages to domain messages
            let userDomainMessage = Message(
                id: userMessage.id,
                content: userMessage.content,
                role: userMessage.role,
                timestamp: userMessage.timestamp,
                contextItems: userMessage.contextItems
            )
            
            let assistantDomainMessage = Message(
                id: assistantMessage.id,
                content: assistantMessage.content,
                role: assistantMessage.role,
                timestamp: assistantMessage.timestamp,
                tokens: TokenUsage(input: estimateTokens(userMessage.content), output: estimateTokens(assistantMessage.content))
            )
            
            try sessionManager.saveMessage(userDomainMessage, to: session.id)
            try sessionManager.saveMessage(assistantDomainMessage, to: session.id)
            
        } catch {
            await MainActor.run {
                self.error = "Failed to save message: \(error.localizedDescription)"
            }
        }
    }
    
    private func handleError(_ error: Error) async {
        await MainActor.run {
            self.error = error.localizedDescription
            
            // Replace the last assistant message with an error message
            if let lastIndex = messages.lastIndex(where: { $0.role == .assistant }) {
                messages[lastIndex] = DisplayMessage.error(error.localizedDescription)
            }
        }
    }
    
    private func estimateTokens(_ text: String) -> Int {
        // Rough estimation: ~4 characters per token for English text
        return max(1, text.count / 4)
    }
}

// MARK: - Message Processing

extension ChatViewModel {
    func exportMessage(_ message: DisplayMessage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.content, forType: .string)
    }
    
    func saveMessageAsFile(_ message: DisplayMessage) {
        let savePanel = NSSavePanel()
        savePanel.title = "Save Message"
        savePanel.nameFieldStringValue = "message.txt"
        savePanel.allowedContentTypes = [.plainText]
        
        if savePanel.runModal() == .OK,
           let url = savePanel.url {
            do {
                try message.content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                self.error = "Failed to save file: \(error.localizedDescription)"
            }
        }
    }
    
    func regenerateMessage(at index: Int) {
        guard index < messages.count,
              messages[index].role == .assistant,
              index > 0 else { return }
        
        // Find the user message that prompted this response
        var userMessageIndex = index - 1
        while userMessageIndex >= 0 && messages[userMessageIndex].role != .user {
            userMessageIndex -= 1
        }
        
        guard userMessageIndex >= 0 else { return }
        
        let userMessage = messages[userMessageIndex]
        
        // Remove all messages after the user message
        messages = Array(messages.prefix(through: userMessageIndex))
        
        // Regenerate response
        Task {
            await sendMessage(userMessage.content)
        }
    }
}

// MARK: - Context Integration

extension ChatViewModel {
    func addContextReference(_ reference: String) async {
        guard let contextManager = contextManager else { return }
        
        do {
            let contextItem = try await contextManager.resolveReference(reference)
            contextManager.addContextItem(contextItem)
        } catch {
            await MainActor.run {
                self.error = "Failed to add context: \(error.localizedDescription)"
            }
        }
    }
    
    func processMessageWithContext(_ content: String) -> String {
        guard let contextManager = contextManager else { return content }
        
        var processedContent = content
        
        // Process @file and @folder references
        let regex = /@(file|folder):([^\s]+)/
        let matches = processedContent.matches(for: regex)
        
        for match in matches {
            // This would resolve the reference and add to context
            // For now, just mark it as a reference
            processedContent = processedContent.replacingOccurrences(
                of: match,
                with: "[\(match)]"
            )
        }
        
        return processedContent
    }
}

// MARK: - String Extension for Regex

extension String {
    func matches(for regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self, range: NSRange(self.startIndex..., in: self))
            return results.map {
                String(self[Range($0.range, in: self)!])
            }
        } catch {
            return []
        }
    }
}