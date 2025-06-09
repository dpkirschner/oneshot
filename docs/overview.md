# OneShot PRD - Privacy-First macOS Developer Chat Assistant

## Executive Summary

OneShot is a native macOS chatbot application designed specifically for developers who need deep project context integration with Large Language Models while maintaining complete privacy. Unlike cloud-based solutions, OneShot keeps all data local, provides rich file/folder context injection, and offers a plugin architecture for extending functionality.

## Problem Statement

Current developer-focused AI assistants suffer from:
- **Privacy concerns**: Chat history and context stored in cloud
- **Limited context**: Can't easily reference entire projects or file structures
- **Poor integration**: Difficult to bridge chat with actual development tools
- **Performance opacity**: No visibility into model performance or token usage
- **Inflexibility**: Locked into single providers or limited customization

## Solution Overview

OneShot addresses these issues by providing:
- **Complete privacy**: All data remains on device
- **Rich context injection**: File, folder, and project-level references
- **Multi-provider support**: OpenAI, Ollama, and extensible architecture
- **Developer-focused UX**: Native macOS app with hotkeys, diagnostics, and tooling
- **Plugin ecosystem**: Extensible via MCP-style command runners

## Target Users

**Primary**: Professional software developers using macOS who work with sensitive codebases and need AI assistance with deep project context.

**Secondary**: Development teams requiring privacy-compliant AI tools, freelancers handling client code, and security-conscious developers.

## Success Metrics

- **Adoption**: 1,000+ active users within 6 months
- **Engagement**: Average 5+ sessions per user per week
- **Context Usage**: 80%+ of conversations include file/folder references
- **Performance**: <500ms average response time for context injection
- **Retention**: 70%+ monthly active user retention

## Core Features

### 1. Privacy-First Architecture
**Priority**: P0 (MVP)
- All chat history stored locally in Core Data
- API keys encrypted in macOS Keychain
- No telemetry or cloud sync
- Optional local-only models via Ollama

### 2. Deep Context System
**Priority**: P0 (MVP)
- `@file` and `@folder` autocomplete references
- Drag-and-drop file injection
- Project root detection and context
- Smart context refresh on file changes
- Token budgeting to stay within model limits
- Scoped search within referenced context

### 3. Multi-Provider LLM Support
**Priority**: P0 (MVP)
- OpenAI API integration (GPT-4, GPT-3.5)
- Ollama local model support
- Extensible provider protocol for future models
- Per-conversation model switching
- Temperature and parameter tuning

### 4. Native macOS Experience
**Priority**: P0 (MVP)
- Swift + SwiftUI native app
- Global hotkey summon (Cmd+Shift+A)
- System-native UI patterns and animations
- Dark/light mode support
- Accessibility compliance

### 5. Developer Tools Integration
**Priority**: P1 (Post-MVP)
- Code syntax highlighting
- Diff visualization
- Snippet export to clipboard/editor
- Quick Apply to active editor
- Terminal command execution

### 6. Performance Diagnostics
**Priority**: P1 (Post-MVP)
- Real-time latency tracking
- Tokens per second metrics
- Provider health status
- A/B model performance comparison
- Usage analytics dashboard

### 7. Session Management
**Priority**: P1 (Post-MVP)
- Archived vs temporary chat distinction
- Full-text search across conversations
- Auto-summarized thread titles
- Conversation forking and branching
- Export/import conversation data

### 8. Prompt Library
**Priority**: P1 (Post-MVP)
- Reusable system prompts
- Dynamic placeholder variables
- Prompt versioning and history
- Community prompt sharing (optional)
- Quick prompt application

### 9. Plugin Architecture
**Priority**: P2 (Future)
- MCP-compatible plugin execution
- Sandboxed command runners
- File system access controls
- Custom tool integration
- Plugin marketplace

## Technical Architecture

### Core Components

1. **App Layer** (SwiftUI)
   - Main chat interface
   - Settings and configuration
   - File browser and context picker
   - Diagnostics dashboard

2. **Service Layer**
   - LLMProviderService (protocol-based)
   - ContextManager (file parsing, change detection)
   - SessionManager (conversation persistence)
   - PluginManager (future)

3. **Data Layer**
   - Core Data for chat history
   - Keychain for API keys
   - File system monitoring
   - User defaults for preferences

### Key Protocols

```swift
protocol LLMProvider {
    func sendMessage(_ message: String, context: [ContextItem]) async throws -> AsyncStream<String>
    func getModels() async throws -> [LLMModel]
    var isHealthy: Bool { get }
    var metrics: ProviderMetrics { get }
}

protocol ContextProvider {
    func resolveReference(_ ref: String) throws -> ContextItem
    func getAvailableReferences() -> [String]
    func startMonitoring(path: String)
}
```

### Data Models

```swift
struct Conversation {
    let id: UUID
    let title: String
    let createdAt: Date
    let isArchived: Bool
    let messages: [Message]
}

struct Message {
    let id: UUID
    let content: String
    let role: MessageRole
    let timestamp: Date
    let contextItems: [ContextItem]
    let metadata: MessageMetadata
}

struct ContextItem {
    let type: ContextType
    let path: String
    let content: String
    let tokenCount: Int
    let lastModified: Date
}
```

## User Experience Flow

### Primary Flow: Context-Aware Chat
1. User summons app with global hotkey
2. Types message with `@file` reference
3. Autocomplete suggests available files
4. User selects file, content injected as context
5. Message sent to LLM with full context
6. Response streams back with syntax highlighting
7. User can export code snippets or continue conversation

### Secondary Flow: Project Setup
1. User drags project folder into app
2. App scans for common file types
3. Context structure indexed and cached
4. Project root detected and saved
5. Ongoing file monitoring enabled

## Development Phases

### Phase 1: MVP (Months 1-3)
- Basic chat interface
- OpenAI integration
- File drag-and-drop
- Context injection
- Local data storage

### Phase 2: Enhancement (Months 4-6)
- Ollama integration
- Global hotkey
- Diagnostics dashboard
- Session management
- Prompt library basics

### Phase 3: Advanced (Months 7-12)
- Plugin architecture
- Advanced context features
- Performance optimizations
- Community features
- Additional providers

## Technical Specifications

### Minimum Requirements
- macOS 13.0+ (Ventura)
- 8GB RAM
- 1GB available storage
- Internet connection (for remote models)

### Performance Targets
- App launch: <2 seconds
- Context injection: <500ms for files up to 100KB
- UI responsiveness: 60fps maintained
- Memory usage: <200MB baseline

### Security Considerations
- API keys stored in Keychain with appropriate access controls
- File access limited to user-selected directories
- Plugin execution sandboxed
- No network requests except to configured LLM providers
- Optional local-only mode for maximum privacy

## Risks and Mitigation

### Technical Risks
- **Context size limitations**: Implement smart chunking and summarization
- **File monitoring performance**: Use efficient file system events
- **Memory usage with large contexts**: Implement lazy loading and caching

### Product Risks
- **User adoption**: Focus on developer community outreach
- **Provider API changes**: Maintain flexible provider abstraction
- **Competition**: Differentiate through privacy and context features

### Business Risks
- **Open source sustainability**: Consider dual licensing model
- **API costs for users**: Promote local model usage
- **Platform dependencies**: Plan for potential macOS API changes

## Success Criteria

### Phase 1 Success
- App launches and basic chat works
- File context injection functional
- 100+ developer beta users
- Positive feedback on core concept

### Phase 2 Success
- Feature parity with major competitors
- 500+ active users
- Strong community engagement
- Plugin API documentation complete

### Phase 3 Success
- 1000+ active users
- Thriving plugin ecosystem
- Revenue model established
- Cross-platform planning initiated

## Appendices

### A. Competitive Analysis
- GitHub Copilot Chat: Strong VS Code integration, limited context
- Cursor: Good context but cloud-based
- Codeium: Multi-IDE but privacy concerns
- Local solutions: Limited UX and features

### B. Technical Research
- LLM provider APIs and rate limits
- macOS file system monitoring best practices
- Core Data performance optimization
- SwiftUI architecture patterns

### C. User Research
- Developer privacy concerns survey
- Context usage pattern analysis
- Preferred interaction models
- Integration point priorities