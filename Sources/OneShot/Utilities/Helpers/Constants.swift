import Foundation

enum Constants {
    enum App {
        static let name = "OneShot"
        static let bundleIdentifier = "com.oneshot.app"
        static let version = "1.0.0"
        static let build = "1"
    }
    
    enum UI {
        static let cornerRadius: CGFloat = 8
        static let smallCornerRadius: CGFloat = 4
        static let cardPadding: CGFloat = 16
        static let defaultSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 16
        
        enum Animation {
            static let defaultDuration: Double = 0.3
            static let quickDuration: Double = 0.15
            static let slowDuration: Double = 0.5
        }
        
        enum Sizes {
            static let avatarSize: CGFloat = 32
            static let iconSize: CGFloat = 16
            static let buttonHeight: CGFloat = 36
            static let textFieldHeight: CGFloat = 32
        }
    }
    
    enum Context {
        static let maxTokensDefault = 8192
        static let maxFileSize = 1024 * 1024 // 1MB
        static let maxFiles = 50
        static let supportedExtensions = [
            "swift", "js", "jsx", "ts", "tsx", "py", "rb", "go", "rs",
            "java", "kt", "cpp", "c", "cs", "php", "html", "css", "scss",
            "xml", "json", "yaml", "yml", "toml", "md", "markdown", "sql",
            "sh", "bash", "ps1", "dockerfile", "txt", "log"
        ]
    }
    
    enum LLM {
        static let defaultTemperature = 0.7
        static let defaultMaxTokens = 2048
        static let maxContextWindow = 128000 // For GPT-4 Turbo
        static let requestTimeoutSeconds: TimeInterval = 60
        static let maxRetries = 3
        
        enum OpenAI {
            static let baseURL = "https://api.openai.com/v1"
            static let modelsEndpoint = "/models"
            static let chatEndpoint = "/chat/completions"
        }
        
        enum Ollama {
            static let defaultBaseURL = "http://localhost:11434"
            static let modelsEndpoint = "/api/tags"
            static let chatEndpoint = "/api/chat"
            static let generateEndpoint = "/api/generate"
        }
    }
    
    enum Storage {
        static let coreDataModelName = "OneShot"
        static let keychainServiceName = "com.oneshot.keychain"
        static let userDefaultsSuiteName = "com.oneshot.userdefaults"
        
        enum Keys {
            static let apiKeyPrefix = "api_key_"
            static let currentProvider = "currentProvider"
            static let theme = "theme"
            static let globalHotkey = "globalHotkey"
            static let onboardingComplete = "onboardingComplete"
            static let recentFiles = "recentFiles"
            static let favoritePrompts = "favoritePrompts"
            static let autoSave = "autoSave"
            static let contextOptimization = "contextOptimization"
            static let maxTokens = "maxTokens"
        }
    }
    
    enum Diagnostics {
        static let metricsRetentionDays = 30
        static let maxRequestHistory = 1000
        static let maxErrorHistory = 500
        static let healthCheckInterval: TimeInterval = 300 // 5 minutes
        static let metricsUpdateInterval: TimeInterval = 5
    }
    
    enum FileTypes {
        static let codeFiles = ["swift", "js", "jsx", "ts", "tsx", "py", "rb", "go", "rs", "java", "kt", "cpp", "c", "cs", "php"]
        static let configFiles = ["json", "yaml", "yml", "toml", "xml", "plist", "cfg", "conf", "ini"]
        static let documentFiles = ["md", "markdown", "txt", "rtf", "pdf"]
        static let webFiles = ["html", "htm", "css", "scss", "sass", "less"]
        static let scriptFiles = ["sh", "bash", "ps1", "bat", "cmd"]
        static let dataFiles = ["sql", "csv", "tsv", "log"]
        
        static let allSupported = codeFiles + configFiles + documentFiles + webFiles + scriptFiles + dataFiles
    }
    
    enum Hotkeys {
        static let defaultGlobalHotkey = "⌘⇧Space"
        static let sendMessage = "⌘↩"
        static let newChat = "⌘N"
        static let clearContext = "⌘⌥K"
        static let addFile = "⌘⇧O"
        static let addFolder = "⌘⇧D"
        static let showDiagnostics = "⌘⌥D"
        static let toggleSidebar = "⌘⌃S"
    }
    
    enum Network {
        static let requestTimeoutInterval: TimeInterval = 30
        static let resourceTimeoutInterval: TimeInterval = 60
        static let maxConcurrentRequests = 5
        static let retryDelay: TimeInterval = 1
        static let maxRetryDelay: TimeInterval = 60
    }
    
    enum Privacy {
        static let dataRetentionDays = 365
        static let anonymizeAfterDays = 30
        static let maxLocalStorageSize = 1024 * 1024 * 1024 // 1GB
    }
}

// MARK: - Environment Detection

extension Constants {
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
    
    static var isTesting: Bool {
        NSClassFromString("XCTestCase") != nil
    }
}

// MARK: - URLs and Paths

extension Constants {
    enum URLs {
        static let website = URL(string: "https://oneshot.dev")!
        static let documentation = URL(string: "https://docs.oneshot.dev")!
        static let github = URL(string: "https://github.com/oneshot/oneshot")!
        static let openAIDocs = URL(string: "https://platform.openai.com/docs")!
        static let ollamaDocs = URL(string: "https://ollama.ai/docs")!
    }
    
    enum Paths {
        static var applicationSupport: URL {
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                .appendingPathComponent(App.name)
        }
        
        static var coreDataStore: URL {
            applicationSupport.appendingPathComponent("\(Storage.coreDataModelName).sqlite")
        }
        
        static var logs: URL {
            applicationSupport.appendingPathComponent("Logs")
        }
        
        static var cache: URL {
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
                .appendingPathComponent(App.name)
        }
        
        static var exports: URL {
            FileManager.default.urls(for: .documentsDirectory, in: .userDomainMask).first!
                .appendingPathComponent("\(App.name) Exports")
        }
    }
}