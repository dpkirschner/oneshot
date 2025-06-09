import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppStateManager
    @EnvironmentObject private var llmService: LLMProviderService
    @EnvironmentObject private var diagnostics: DiagnosticsService
    
    var body: some View {
        TabView {
            ProvidersSettingsView()
                .tabItem {
                    Label("Providers", systemImage: "brain")
                }
                .environmentObject(llmService)
            
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .environmentObject(appState)
            
            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "lock")
                }
                .environmentObject(appState)
                .environmentObject(diagnostics)
            
            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
                .environmentObject(appState)
        }
        .frame(width: 600, height: 500)
        .navigationTitle("Settings")
    }
}

// MARK: - Providers Settings

struct ProvidersSettingsView: View {
    @EnvironmentObject private var llmService: LLMProviderService
    @State private var showingAddProvider = false
    @State private var testingProvider: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LLM Providers")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Configure your AI providers and models")
                .foregroundColor(.secondary)
            
            // Providers list
            GroupBox("Configured Providers") {
                if llmService.availableProviders.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "brain")
                            .font(.title)
                            .foregroundColor(.secondary)
                        
                        Text("No providers configured")
                            .font(.headline)
                        
                        Text("Add a provider to get started")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } else {
                    VStack(spacing: 8) {
                        ForEach(llmService.availableProviders, id: \.id) { provider in
                            ProviderRow(
                                provider: provider,
                                isSelected: llmService.currentProvider?.id == provider.id,
                                isTesting: testingProvider == provider.id
                            ) {
                                llmService.currentProvider = provider
                            } onTest: {
                                testProvider(provider)
                            } onRemove: {
                                llmService.removeProvider(id: provider.id)
                            }
                        }
                    }
                    .padding()
                }
            }
            
            // Add provider button
            HStack {
                Button("Add Provider") {
                    showingAddProvider = true
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showingAddProvider) {
            AddProviderSheet()
                .environmentObject(llmService)
        }
    }
    
    private func testProvider(_ provider: LLMProvider) {
        testingProvider = provider.id
        
        Task {
            let isHealthy = await llmService.validateProvider(provider)
            
            await MainActor.run {
                testingProvider = nil
                // Show result somehow
            }
        }
    }
}

struct ProviderRow: View {
    let provider: LLMProvider
    let isSelected: Bool
    let isTesting: Bool
    let onSelect: () -> Void
    let onTest: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(provider.name)
                        .font(.headline)
                    
                    if isSelected {
                        Text("Current")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                    }
                }
                
                Text("\(provider.supportedModels.count) models available")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Circle()
                        .fill(provider.isAvailable ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    
                    Text(provider.statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if isTesting {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Button("Test") {
                        onTest()
                    }
                    .buttonStyle(.borderless)
                    .disabled(!provider.isAvailable)
                }
                
                if !isSelected {
                    Button("Select") {
                        onSelect()
                    }
                    .buttonStyle(.borderless)
                    .disabled(!provider.isAvailable)
                }
                
                Button("Remove") {
                    onRemove()
                }
                .buttonStyle(.borderless)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppStateManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                Section("Appearance") {
                    Picker("Theme", selection: $appState.currentTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("Hotkeys") {
                    HStack {
                        Text("Global Hotkey")
                        Spacer()
                        Text(appState.globalHotkey?.displayString ?? "None")
                            .foregroundColor(.secondary)
                        Button("Change") {
                            // Open hotkey configuration
                        }
                    }
                }
                
                Section("File Management") {
                    Toggle("Remember recent files", isOn: .constant(true))
                    
                    HStack {
                        Text("Recent files")
                        Spacer()
                        Text("\(appState.recentFiles.count) files")
                            .foregroundColor(.secondary)
                        Button("Clear") {
                            appState.clearRecentFiles()
                        }
                        .disabled(appState.recentFiles.isEmpty)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .onChange(of: appState.currentTheme) { _ in
            appState.saveSettings()
        }
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    @EnvironmentObject private var appState: AppStateManager
    @EnvironmentObject private var diagnostics: DiagnosticsService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy & Data")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("OneShot keeps all your data local and private")
                .foregroundColor(.secondary)
            
            Form {
                Section("Data Collection") {
                    Toggle("Collect usage metrics", isOn: $diagnostics.isCollectingMetrics)
                    
                    Text("Metrics are stored locally and never shared")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Data Storage") {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Chat History")
                            Text("Stored in local Core Data database")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("View Location") {
                            showDataLocation()
                        }
                    }
                    
                    HStack {
                        VStack(alignment: .leading) {
                            Text("API Keys")
                            Text("Stored in macOS Keychain")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("🔒 Encrypted")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Section("Data Management") {
                    Button("Clear All Chat History") {
                        // Confirmation dialog and clear
                    }
                    .foregroundColor(.red)
                    
                    Button("Export All Data") {
                        exportAllData()
                    }
                    
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            
            Spacer()
        }
        .padding()
    }
    
    private func showDataLocation() {
        // Open Finder to app data location
        let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        if let appSupportURL = urls.first {
            let oneShotURL = appSupportURL.appendingPathComponent("OneShot")
            NSWorkspace.shared.open(oneShotURL)
        }
    }
    
    private func exportAllData() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export OneShot Data"
        savePanel.nameFieldStringValue = "oneshot_export_\(Date().formatted(date: .numeric, time: .omitted)).json"
        savePanel.allowedContentTypes = [.json]
        
        if savePanel.runModal() == .OK {
            // Export data
        }
    }
    
    private func resetToDefaults() {
        // Show confirmation and reset
    }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
    @EnvironmentObject private var appState: AppStateManager
    @State private var maxTokens = 4096
    @State private var contextOptimization = ContextOptimizationStrategy.smart
    @State private var autoSave = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced")
                .font(.title2)
                .fontWeight(.semibold)
            
            Form {
                Section("Context Management") {
                    HStack {
                        Text("Max Context Tokens")
                        Spacer()
                        TextField("4096", value: $maxTokens, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }
                    
                    Picker("Context Optimization", selection: $contextOptimization) {
                        ForEach(ContextOptimizationStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                    
                    Text(contextOptimization.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Performance") {
                    Toggle("Auto-save conversations", isOn: $autoSave)
                    
                    HStack {
                        Text("Memory Usage")
                        Spacer()
                        Text("125 MB")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Development") {
                    Button("Show Debug Info") {
                        // Show debug window
                    }
                    
                    Button("Reset Onboarding") {
                        appState.isOnboardingComplete = false
                        appState.saveSettings()
                    }
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Add Provider Sheet

struct AddProviderSheet: View {
    @EnvironmentObject private var llmService: LLMProviderService
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedProviderType = "openai"
    @State private var apiKey = ""
    @State private var baseURL = ""
    @State private var isConfiguring = false
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Add LLM Provider")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Form {
                    Picker("Provider Type", selection: $selectedProviderType) {
                        Text("OpenAI").tag("openai")
                        Text("Ollama (Local)").tag("ollama")
                        Text("Custom").tag("custom")
                    }
                    .pickerStyle(.segmented)
                    
                    if selectedProviderType == "openai" {
                        TextField("API Key", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("Get your API key from platform.openai.com")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if selectedProviderType == "ollama" {
                        TextField("Base URL", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("Default: http://localhost:11434")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if selectedProviderType == "custom" {
                        TextField("Base URL", text: $baseURL)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("API Key (optional)", text: $apiKey)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Add Provider")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addProvider()
                    }
                    .disabled(isConfiguring || !canAddProvider)
                }
            }
        }
        .frame(width: 500, height: 400)
    }
    
    private var canAddProvider: Bool {
        switch selectedProviderType {
        case "openai":
            return !apiKey.isEmpty
        case "ollama":
            return true // Ollama doesn't require API key
        case "custom":
            return !baseURL.isEmpty
        default:
            return false
        }
    }
    
    private func addProvider() {
        isConfiguring = true
        
        Task {
            // This would create and configure the actual provider
            // For now, just simulate the process
            
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            await MainActor.run {
                isConfiguring = false
                dismiss()
            }
        }
    }
}

// MARK: - Onboarding View

struct OnboardingView: View {
    @EnvironmentObject private var appState: AppStateManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var currentStep = 0
    private let totalSteps = 3
    
    var body: some View {
        VStack(spacing: 24) {
            // Progress indicator
            HStack {
                ForEach(0..<totalSteps, id: \.self) { step in
                    Circle()
                        .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)
                    
                    if step < totalSteps - 1 {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            .padding(.horizontal)
            
            // Step content
            Group {
                switch currentStep {
                case 0:
                    WelcomeStep()
                case 1:
                    ProviderSetupStep()
                case 2:
                    PrivacyStep()
                default:
                    EmptyView()
                }
            }
            .frame(maxWidth: 500)
            
            Spacer()
            
            // Navigation buttons
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        currentStep -= 1
                    }
                }
                
                Spacer()
                
                if currentStep < totalSteps - 1 {
                    Button("Next") {
                        currentStep += 1
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
    
    private func completeOnboarding() {
        appState.completeOnboarding()
        dismiss()
    }
}

struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "brain")
                .font(.system(size: 64))
                .foregroundColor(.blue)
            
            Text("Welcome to OneShot")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Your privacy-first AI coding assistant")
                .font(.title2)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                FeatureBullet(icon: "lock", text: "All data stays on your device")
                FeatureBullet(icon: "folder", text: "Deep project context integration")
                FeatureBullet(icon: "brain", text: "Multiple AI providers supported")
                FeatureBullet(icon: "keyboard", text: "Global hotkey access")
            }
        }
    }
}

struct ProviderSetupStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gear")
                .font(.system(size: 64))
                .foregroundColor(.green)
            
            Text("Set Up Your AI Provider")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Choose how you want to access AI models")
                .font(.title2)
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                ProviderOption(
                    icon: "cloud",
                    title: "OpenAI",
                    description: "Use GPT-4 and other OpenAI models"
                )
                
                ProviderOption(
                    icon: "desktopcomputer",
                    title: "Ollama (Local)",
                    description: "Run models locally on your machine"
                )
            }
        }
    }
}

struct PrivacyStep: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 64))
                .foregroundColor(.purple)
            
            Text("Your Privacy Matters")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("OneShot is designed with privacy at its core")
                .font(.title2)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                PrivacyBullet(text: "Chat history stored locally in Core Data")
                PrivacyBullet(text: "API keys encrypted in macOS Keychain")
                PrivacyBullet(text: "No telemetry or data collection")
                PrivacyBullet(text: "Optional local-only mode available")
            }
        }
    }
}

struct FeatureBullet: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
        }
    }
}

struct ProviderOption: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PrivacyBullet: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(AppStateManager(container: DefaultServiceContainer().setupTestContainer()))
            .environmentObject(MockLLMProviderService())
            .environmentObject(MockDiagnosticsService())
    }
}
#endif