import Foundation

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    var isNotEmpty: Bool {
        !trimmed.isEmpty
    }
    
    func estimateTokenCount() -> Int {
        // Rough estimation: ~4 characters per token for English text
        return max(1, count / 4)
    }
    
    func truncate(to length: Int, ellipsis: String = "...") -> String {
        if count <= length {
            return self
        } else {
            let truncated = String(prefix(length - ellipsis.count))
            return truncated + ellipsis
        }
    }
    
    func matches(for regex: String) -> [String] {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let results = regex.matches(in: self, range: NSRange(startIndex..., in: self))
            return results.map {
                String(self[Range($0.range, in: self)!])
            }
        } catch {
            return []
        }
    }
    
    func replacingMatches(of pattern: String, with replacement: String) -> String {
        do {
            let regex = try NSRegularExpression(pattern: pattern)
            return regex.stringByReplacingMatches(
                in: self,
                options: [],
                range: NSRange(startIndex..., in: self),
                withTemplate: replacement
            )
        } catch {
            return self
        }
    }
    
    var isValidFilePath: Bool {
        let fileURL = URL(fileURLWithPath: self)
        return FileManager.default.fileExists(atPath: fileURL.path)
    }
    
    var fileExtension: String {
        (self as NSString).pathExtension.lowercased()
    }
    
    var fileName: String {
        (self as NSString).lastPathComponent
    }
    
    var directoryPath: String {
        (self as NSString).deletingLastPathComponent
    }
    
    func detectLanguage() -> String? {
        let ext = fileExtension
        
        switch ext {
        case "swift": return "swift"
        case "js", "jsx": return "javascript"
        case "ts", "tsx": return "typescript"
        case "py": return "python"
        case "rb": return "ruby"
        case "go": return "go"
        case "rs": return "rust"
        case "java", "kt": return "java"
        case "cpp", "cc", "cxx": return "cpp"
        case "c": return "c"
        case "cs": return "csharp"
        case "php": return "php"
        case "html", "htm": return "html"
        case "css": return "css"
        case "scss", "sass": return "scss"
        case "xml": return "xml"
        case "json": return "json"
        case "yaml", "yml": return "yaml"
        case "toml": return "toml"
        case "md", "markdown": return "markdown"
        case "sql": return "sql"
        case "sh", "bash": return "bash"
        case "ps1": return "powershell"
        case "dockerfile": return "dockerfile"
        default: return nil
        }
    }
}