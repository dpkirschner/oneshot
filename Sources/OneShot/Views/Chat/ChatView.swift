import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var sessionManager: CoreDataSessionManager
    @EnvironmentObject private var contextManager: DefaultContextManager
    @StateObject private var viewModel = ChatViewModel()
    
    @State private var inputText = ""
    @State private var isGenerating = false
    @State private var showingContextSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Context indicator bar
            if !contextManager.activeContextItems.isEmpty {
                contextIndicatorBar
                    .background(Color.blue.opacity(0.1))
            }
            
            // Messages area
            messagesArea
            
            // Input area
            inputArea
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
        }
        .navigationTitle(sessionManager.currentSession?.title ?? "New Chat")
        .navigationSubtitle(contextSummary)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: { showingContextSheet = true }) {
                    Image(systemName: "paperclip")
                }
                .help("Manage Context")
                
                Button(action: clearContext) {
                    Image(systemName: "trash")
                }
                .help("Clear Context")
                .disabled(contextManager.activeContextItems.isEmpty)
                
                Button(action: newChat) {
                    Image(systemName: "square.and.pencil")
                }
                .help("New Chat")
            }
        }
        .sheet(isPresented: $showingContextSheet) {
            ContextSheetView()
                .environmentObject(contextManager)
        }
        .onAppear {
            viewModel.setup(sessionManager: sessionManager, contextManager: contextManager)
        }
    }
    
    @ViewBuilder
    private var contextIndicatorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Image(systemName: "paperclip")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                ForEach(contextManager.activeContextItems) { item in
                    ContextChip(item: item) {
                        contextManager.removeContextItem(id: item.id)
                    }
                }
                
                Spacer()
                
                Text("\(contextManager.totalTokenCount) tokens")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
        }
        .frame(height: 36)
    }
    
    @ViewBuilder
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.messages.isEmpty {
                        emptyState
                            .padding(.top, 50)
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageView(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "message")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Start a conversation")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Ask questions, get code help, or discuss your project")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if !contextManager.activeContextItems.isEmpty {
                VStack(spacing: 8) {
                    Text("Context loaded:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(contextManager.contextSummary)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .frame(maxWidth: 400)
    }
    
    @ViewBuilder
    private var inputArea: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Type your message...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .onSubmit {
                        sendMessage()
                    }
                    .disabled(isGenerating)
                
                Button(action: sendMessage) {
                    Image(systemName: isGenerating ? "stop.circle" : "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(isGenerating ? .red : .blue)
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isGenerating)
                .keyboardShortcut(.return, modifiers: .command)
            }
            
            HStack {
                Text("⌘↩ to send")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !contextManager.activeContextItems.isEmpty {
                    Text("\(contextManager.activeContextItems.count) context item(s)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var contextSummary: String {
        guard !contextManager.activeContextItems.isEmpty else { return "" }
        return contextManager.contextSummary
    }
    
    private func sendMessage() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        if isGenerating {
            // Stop generation
            viewModel.stopGeneration()
            return
        }
        
        let message = inputText
        inputText = ""
        isGenerating = true
        
        Task {
            await viewModel.sendMessage(message)
            await MainActor.run {
                isGenerating = false
            }
        }
    }
    
    private func clearContext() {
        contextManager.clearContext()
    }
    
    private func newChat() {
        // Clear current conversation but keep context
        viewModel.clearMessages()
        let newSession = sessionManager.createQuickSession(
            provider: "openai", // This should come from current provider
            model: "gpt-4"
        )
        sessionManager.setCurrentSession(newSession)
    }
}

struct ContextChip: View {
    let item: ContextItem
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: item.type.icon)
                .font(.caption2)
            
            Text(item.name)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Context Sheet

struct ContextSheetView: View {
    @EnvironmentObject private var contextManager: DefaultContextManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    Section("Active Context") {
                        if contextManager.activeContextItems.isEmpty {
                            Text("No context items")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(contextManager.activeContextItems) { item in
                                ContextItemRow(item: item) {
                                    contextManager.removeContextItem(id: item.id)
                                }
                            }
                        }
                    }
                    
                    Section("Add Context") {
                        Button("Add File...") {
                            // Trigger file picker
                            NotificationCenter.default.post(name: .addFileContextRequested, object: nil)
                        }
                        
                        Button("Add Folder...") {
                            // Trigger folder picker
                            NotificationCenter.default.post(name: .addFolderContextRequested, object: nil)
                        }
                        
                        Button("Add Clipboard") {
                            Task {
                                try? await contextManager.addClipboardContext()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Context Management")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 500, height: 400)
    }
}

struct ContextItemRow: View {
    let item: ContextItem
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: item.type.icon)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                
                HStack {
                    Text(item.type.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(item.tokenCount) tokens")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Preview

#if DEBUG
struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView()
            .environmentObject(MockSessionManager())
            .environmentObject(MockContextManager())
    }
}
#endif