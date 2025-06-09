import SwiftUI

struct MessageView: View {
    let message: DisplayMessage
    @State private var isHovering = false
    @State private var showingActions = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Role avatar
            roleAvatar
            
            // Message content
            VStack(alignment: .leading, spacing: 8) {
                // Message header
                messageHeader
                
                // Message content
                messageContent
                
                // Context indicators
                if !message.contextItems.isEmpty {
                    contextIndicators
                }
                
                // Error display
                if let error = message.error {
                    errorView(error)
                }
            }
            
            Spacer()
            
            // Action buttons
            if isHovering || showingActions {
                messageActions
            }
        }
        .padding(.vertical, 8)
        .background(messageBackground)
        .cornerRadius(8)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
    
    @ViewBuilder
    private var roleAvatar: some View {
        Circle()
            .fill(avatarColor)
            .frame(width: 32, height: 32)
            .overlay {
                Image(systemName: avatarIcon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
            }
    }
    
    @ViewBuilder
    private var messageHeader: some View {
        HStack {
            Text(message.role.displayName)
                .font(.headline)
                .foregroundColor(headerColor)
            
            Text(message.timestamp, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if message.isStreaming {
                ProgressView()
                    .scaleEffect(0.6)
                    .progressViewStyle(CircularProgressViewStyle())
            }
            
            Spacer()
        }
    }
    
    @ViewBuilder
    private var messageContent: some View {
        if message.content.isEmpty && message.isStreaming {
            HStack {
                ProgressView()
                    .scaleEffect(0.8)
                Text("Thinking...")
                    .foregroundColor(.secondary)
            }
        } else {
            SelectableText(content: message.content)
                .textSelection(.enabled)
        }
    }
    
    @ViewBuilder
    private var contextIndicators: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(message.contextItems) { item in
                    ContextIndicator(item: item)
                }
            }
        }
    }
    
    @ViewBuilder
    private var messageActions: some View {
        VStack(spacing: 4) {
            Button(action: copyMessage) {
                Image(systemName: "doc.on.doc")
            }
            .help("Copy message")
            
            if message.role == .assistant {
                Button(action: regenerateMessage) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Regenerate response")
            }
            
            Menu {
                Button("Save as File") { saveAsFile() }
                Button("Export as Markdown") { exportAsMarkdown() }
                if message.role == .assistant {
                    Button("Use as Template") { useAsTemplate() }
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .help("More actions")
        }
        .buttonStyle(.borderless)
        .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private func errorView(_ error: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
            
            Text(error)
                .font(.caption)
                .foregroundColor(.red)
            
            Spacer()
            
            Button("Retry") {
                retryMessage()
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding(8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(6)
    }
    
    // MARK: - Computed Properties
    
    private var avatarColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return .green
        case .system: return .orange
        }
    }
    
    private var avatarIcon: String {
        switch message.role {
        case .user: return "person.fill"
        case .assistant: return "brain"
        case .system: return "gear"
        }
    }
    
    private var headerColor: Color {
        switch message.role {
        case .user: return .blue
        case .assistant: return .green
        case .system: return .orange
        }
    }
    
    private var messageBackground: Color {
        switch message.role {
        case .user: return Color.blue.opacity(0.05)
        case .assistant: return Color.clear
        case .system: return Color.orange.opacity(0.05)
        }
    }
    
    // MARK: - Actions
    
    private func copyMessage() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(message.content, forType: .string)
    }
    
    private func regenerateMessage() {
        // This would be handled by the parent view or view model
        NotificationCenter.default.post(
            name: .regenerateMessageRequested,
            object: message.id
        )
    }
    
    private func retryMessage() {
        NotificationCenter.default.post(
            name: .retryMessageRequested,
            object: message.id
        )
    }
    
    private func saveAsFile() {
        let savePanel = NSSavePanel()
        savePanel.title = "Save Message"
        savePanel.nameFieldStringValue = "message_\(message.timestamp.formatted(date: .numeric, time: .omitted)).txt"
        savePanel.allowedContentTypes = [.plainText]
        
        if savePanel.runModal() == .OK,
           let url = savePanel.url {
            do {
                try message.content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Failed to save file: \(error)")
            }
        }
    }
    
    private func exportAsMarkdown() {
        let markdown = """
        ## \(message.role.displayName) - \(message.timestamp.formatted())
        
        \(message.content)
        """
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(markdown, forType: .string)
    }
    
    private func useAsTemplate() {
        NotificationCenter.default.post(
            name: .useMessageAsTemplate,
            object: message.content
        )
    }
}

// MARK: - Selectable Text

struct SelectableText: NSViewRepresentable {
    let content: String
    
    func makeNSView(context: Context) -> NSTextView {
        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.backgroundColor = .clear
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = .zero
        
        // Configure for better text rendering
        textView.font = NSFont.systemFont(ofSize: 14)
        textView.textColor = NSColor.labelColor
        
        return textView
    }
    
    func updateNSView(_ textView: NSTextView, context: Context) {
        textView.string = content
        
        // Apply syntax highlighting for code blocks
        if content.contains("```") {
            applySyntaxHighlighting(to: textView)
        }
    }
    
    private func applySyntaxHighlighting(to textView: NSTextView) {
        let attributedString = NSMutableAttributedString(string: content)
        
        // Basic code block highlighting
        let codeBlockPattern = "```[\\s\\S]*?```"
        let regex = try? NSRegularExpression(pattern: codeBlockPattern, options: [])
        let range = NSRange(location: 0, length: content.count)
        
        regex?.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
            guard let matchRange = match?.range else { return }
            
            attributedString.addAttributes([
                .backgroundColor: NSColor.quaternaryLabelColor,
                .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
            ], range: matchRange)
        }
        
        textView.textStorage?.setAttributedString(attributedString)
    }
}

// MARK: - Context Indicator

struct ContextIndicator: View {
    let item: ContextItem
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: item.type.icon)
                .font(.caption2)
                .foregroundColor(.blue)
            
            Text(item.name)
                .font(.caption2)
                .lineLimit(1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Notification Extensions

extension Notification.Name {
    static let regenerateMessageRequested = Notification.Name("regenerateMessageRequested")
    static let retryMessageRequested = Notification.Name("retryMessageRequested")
    static let useMessageAsTemplate = Notification.Name("useMessageAsTemplate")
}

// MARK: - Preview

#if DEBUG
struct MessageView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            MessageView(message: DisplayMessage(
                content: "Hello! How can I help you today?",
                role: .assistant
            ))
            
            MessageView(message: DisplayMessage(
                content: "Can you help me understand this Swift code?",
                role: .user,
                contextItems: [
                    ContextItem(
                        type: .file(language: "swift"),
                        path: "/Users/test/ContentView.swift",
                        name: "ContentView.swift",
                        content: "// Some Swift code"
                    )
                ]
            ))
            
            MessageView(message: DisplayMessage(
                content: "",
                role: .assistant,
                isStreaming: true
            ))
        }
        .padding()
        .frame(width: 600)
    }
}
#endif