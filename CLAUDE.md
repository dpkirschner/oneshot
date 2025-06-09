# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

OneShot is a native macOS chatbot application designed for developers who need deep project context integration with Large Language Models while maintaining complete privacy. Unlike cloud-based solutions, OneShot keeps all data local and provides rich file/folder context injection.

## Architecture

OneShot follows a layered MVVM architecture built entirely in Swift with SwiftUI:

```
UI Layer (SwiftUI) → ViewModels (ObservableObject) → Service Layer → Data Layer
```

### Core Services
- **LLMProviderService**: Manages OpenAI, Ollama, and extensible provider protocol
- **ContextManager**: Handles `@file` and `@folder` references with file monitoring
- **SessionManager**: Core Data-based conversation persistence
- **DiagnosticsService**: Real-time metrics and performance tracking

### Key Features
- Privacy-first architecture (all data local, Core Data + Keychain)
- Deep context system with drag-and-drop file injection
- Multi-provider LLM support (OpenAI, Ollama)
- Global hotkey summon (Cmd+Shift+A)
- Real-time file monitoring with context refresh
- Session management with full-text search
- Prompt library with variable substitution
- Export functionality (Markdown, HTML, JSON)

## Implementation Phases

### Phase 1: MVP (Current Target)
1. Basic chat interface with SwiftUI
2. OpenAI integration with streaming responses
3. File drag-and-drop context injection
4. Local data storage (Core Data + Keychain)

### Phase 2: Enhancement
1. Ollama local model integration
2. Global hotkey implementation
3. Diagnostics dashboard
4. Session management and search

### Phase 3: Advanced
1. Plugin architecture (MCP-compatible)
2. Prompt library system
3. Advanced context optimization
4. File system monitoring

## Project Structure

```
OneShot/
├── App/                 # App entry point and dependency injection
├── Views/               # SwiftUI views (Chat, Settings, Diagnostics)
├── ViewModels/          # ObservableObject view models
├── Services/            # Business logic services
│   ├── LLM/            # Provider implementations
│   ├── Context/        # File monitoring and context management
│   ├── Session/        # Core Data session management
│   └── Diagnostics/    # Metrics and performance tracking
├── Models/              # Domain models and Core Data entities
├── Utilities/           # Extensions and helpers
└── Resources/           # Assets and localizations
```

## Development Requirements

- **Minimum Target**: macOS 13.0+ (Ventura)
- **Swift Version**: 5.9+
- **Xcode**: 15+
- **Key Capabilities**: File system access, Keychain, Network (no sandbox)

## Key Protocols

### LLM Provider
```swift
protocol LLMProvider {
    func sendMessage(_ message: String, context: [ContextItem]) async throws -> AsyncStream<MessageChunk>
    func getModels() async throws -> [LLMModel]
    var isHealthy: Bool { get }
    var metrics: ProviderMetrics { get }
}
```

### Context Management
```swift
protocol ContextManager {
    func resolveReference(_ reference: String) async throws -> ContextItem
    func getAvailableReferences(in scope: ContextScope) -> [String]
    func startMonitoring(path: String)
    func calculateTokenCount(for items: [ContextItem]) -> Int
    func optimizeContext(_ items: [ContextItem], maxTokens: Int) -> [ContextItem]
}
```

## Core Data Schema

- **ConversationEntity**: Sessions with title, metadata, provider info
- **MessageEntity**: Individual messages with role, content, token usage
- **ContextItemEntity**: File references with path, content, token count

## Development Commands

Currently no build system is implemented. When implementation begins:

- **Build**: Standard Xcode build (Cmd+B)
- **Run**: Xcode run (Cmd+R) 
- **Test**: Xcode test (Cmd+U)
- **Archive**: Product → Archive for distribution

## Key Implementation Notes

- All API keys stored in macOS Keychain with appropriate access controls
- File access limited to user-selected directories
- Context optimization handles token limits through smart chunking
- File monitoring uses FSEventStream for efficient change detection
- Streaming responses implemented with AsyncStream
- Global hotkey requires Accessibility permissions
- Export supports multiple formats (Markdown, HTML, JSON, Plain Text)

## Security Considerations

- No network requests except to configured LLM providers
- Plugin execution sandboxed when implemented
- Optional local-only mode for maximum privacy
- File access permissions clearly scoped

This is a greenfield project - implementation will follow the detailed specifications in `docs/` directory.