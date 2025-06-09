import Foundation

final class OpenAIProvider: LLMProvider {
    let id = "openai"
    let name = "OpenAI"
    let requiresAuthentication = true
    
    private var apiKey: String?
    private let baseURL = "https://api.openai.com/v1"
    private let session = URLSession.shared
    private var _metrics = ProviderMetrics()
    private let metricsLock = NSLock()
    
    var isAvailable: Bool {
        apiKey != nil && !apiKey!.isEmpty
    }
    
    var supportedModels: [LLMModel] {
        // Base models without pricing - pricing will be fetched dynamically
        [
            LLMModel(
                id: "gpt-4",
                name: "GPT-4", 
                contextWindow: 8192,
                capabilities: [.chat, .functionCalling],
                provider: id
            ),
            LLMModel(
                id: "gpt-4-turbo-preview",
                name: "GPT-4 Turbo",
                contextWindow: 128000,
                capabilities: [.chat, .functionCalling, .imageAnalysis],
                provider: id
            ),
            LLMModel(
                id: "gpt-3.5-turbo",
                name: "GPT-3.5 Turbo",
                contextWindow: 16385,
                capabilities: [.chat, .functionCalling],
                provider: id
            )
        ]
    }
    
    var metrics: ProviderMetrics {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        return _metrics
    }
    
    func authenticate(credentials: [String: String]) async throws {
        guard let key = credentials["apiKey"], !key.isEmpty else {
            throw LLMProviderError.authenticationFailed
        }
        
        apiKey = key
        
        // Validate the API key by making a test request
        let isValid = await validateCredentials()
        if !isValid {
            apiKey = nil
            throw LLMProviderError.authenticationFailed
        }
    }
    
    func sendMessage(
        _ message: String,
        context: [ContextItem],
        model: LLMModel,
        parameters: LLMParameters
    ) throws -> AsyncThrowingStream<MessageChunk, Error> { // 1. Return type changed
        guard let apiKey = apiKey else {
            throw LLMProviderError.notConfigured
        }

        let startTime = Date()

        // 2. Initializer changed to AsyncThrowingStream
        return AsyncThrowingStream(MessageChunk.self, bufferingPolicy: .unbounded) { continuation in
            Task {
                do {
                    let request = try buildChatRequest(
                        message: message,
                        context: context,
                        model: model,
                        parameters: parameters,
                        apiKey: apiKey
                    )

                    let (asyncBytes, response) = try await session.bytes(for: request)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        // This will now compile correctly
                        continuation.finish(throwing: LLMProviderError.invalidResponse)
                        return
                    }

                    if httpResponse.statusCode != 200 {
                        let errorMessage = try await handleErrorResponse(httpResponse, asyncBytes)
                        continuation.finish(throwing: LLMProviderError.networkError(
                            NSError(domain: "OpenAI", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                        ))
                        return
                    }

                    var inputTokens = 0
                    var outputTokens = 0

                    for try await line in asyncBytes.lines {
                        if line.hasPrefix("data: ") {
                            let data = String(line.dropFirst(6))

                            if data == "[DONE]" {
                                let duration = Date().timeIntervalSince(startTime)
                                recordRequest(duration: duration, inputTokens: inputTokens, outputTokens: outputTokens)
                                // Yielding a final chunk is often unnecessary before finishing.
                                // continuation.yield(MessageChunk(content: "", isComplete: true))
                                continuation.finish() // Finish successfully
                                return
                            }

                            if let jsonData = data.data(using: .utf8),
                               let streamResponse = try? JSONDecoder().decode(OpenAIStreamResponse.self, from: jsonData) {

                                if let usage = streamResponse.usage {
                                    inputTokens = usage.promptTokens
                                    outputTokens = usage.completionTokens
                                }

                                if let choice = streamResponse.choices.first,
                                   let content = choice.delta.content {
                                    continuation.yield(MessageChunk(content: content, isComplete: false))
                                }
                            }
                        }
                    }

                    // In case the stream ends without a [DONE] message
                    let duration = Date().timeIntervalSince(startTime)
                    recordRequest(duration: duration, inputTokens: inputTokens, outputTokens: outputTokens)
                    continuation.finish()

                } catch {
                    recordError(error)
                    continuation.finish(throwing: error) // Also correctly handled here
                }
            }
        }
    }
    
    func getModels() async throws -> [LLMModel] {
        // Try to fetch models with current pricing from OpenAI API
        do {
            return try await fetchModelsWithPricing()
        } catch {
            // Fall back to base models without pricing if API call fails
            return supportedModels
        }
    }
    
    private func fetchModelsWithPricing() async throws -> [LLMModel] {
        guard let apiKey = apiKey else {
            throw LLMProviderError.notConfigured
        }
        
        var request = URLRequest(url: URL(string: "\(baseURL)/models")!)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw LLMProviderError.networkError(NSError(domain: "OpenAI", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch models"]))
        }
        
        let modelsResponse = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        
        // Map API response to our models with pricing lookup
        return supportedModels.compactMap { baseModel in
            guard modelsResponse.data.contains(where: { $0.id == baseModel.id }) else {
                return nil
            }
            
            // Get current pricing for this model (this would need a separate pricing API or config)
            let pricing = getCurrentPricing(for: baseModel.id)
            
            return LLMModel(
                id: baseModel.id,
                name: baseModel.name,
                contextWindow: baseModel.contextWindow,
                inputPricing: pricing?.input,
                outputPricing: pricing?.output,
                capabilities: baseModel.capabilities,
                provider: baseModel.provider,
                isLocal: baseModel.isLocal
            )
        }
    }
    
    private func getCurrentPricing(for modelId: String) -> (input: Double, output: Double)? {
        // In a real implementation, this could:
        // 1. Make a call to a pricing API
        // 2. Load from a regularly updated config file
        // 3. Parse from OpenAI's pricing page
        // 4. Use a cached pricing database that updates periodically
        
        // For now, we'll use a configuration-based approach that can be updated
        let pricingConfig: [String: (input: Double, output: Double)] = [
            "gpt-4": (0.03, 0.06),
            "gpt-4-turbo-preview": (0.01, 0.03), 
            "gpt-3.5-turbo": (0.0015, 0.002)
        ]
        
        return pricingConfig[modelId]
    }
    
    func healthCheck() async -> Bool {
        do {
            _ = try await getModels()
            updateHealthStatus(isHealthy: true)
            return true
        } catch {
            updateHealthStatus(isHealthy: false)
            return false
        }
    }
    
    func validateCredentials() async -> Bool {
        guard let apiKey = apiKey else { return false }
        
        do {
            var request = URLRequest(url: URL(string: "\(baseURL)/models")!)
            request.httpMethod = "GET"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
            
            return false
        } catch {
            return false
        }
    }
}

// MARK: - Private Implementation

private extension OpenAIProvider {
    func buildChatRequest(
        message: String,
        context: [ContextItem],
        model: LLMModel,
        parameters: LLMParameters,
        apiKey: String
    ) throws -> URLRequest {
        var request = URLRequest(url: URL(string: "\(baseURL)/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Build messages array
        var messages: [OpenAIChatMessage] = []
        
        // Add context as system messages
        if !context.isEmpty {
            let contextContent = buildContextContent(context)
            messages.append(OpenAIChatMessage(role: "system", content: contextContent))
        }
        
        // Add user message
        messages.append(OpenAIChatMessage(role: "user", content: message))
        
        let requestBody = OpenAIChatRequest(
            model: model.id,
            messages: messages,
            temperature: parameters.temperature,
            maxTokens: parameters.maxTokens,
            topP: parameters.topP,
            frequencyPenalty: parameters.frequencyPenalty,
            presencePenalty: parameters.presencePenalty,
            stream: true
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        return request
    }
    
    func buildContextContent(_ context: [ContextItem]) -> String {
        var content = "You have access to the following context:\n\n"
        
        for item in context {
            content += "## \(item.name)\n"
            content += "Path: \(item.path)\n"
            content += "Type: \(item.type.displayName)\n\n"
            content += "```\n\(item.content)\n```\n\n"
        }
        
        content += "Please use this context to provide more accurate and relevant responses."
        return content
    }
    
    func handleErrorResponse(_ response: HTTPURLResponse, _ bytes: URLSession.AsyncBytes) async throws -> String {
        var errorData = Data()
        for try await byte in bytes {
            errorData.append(byte)
        }
        
        if let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: errorData) {
            switch response.statusCode {
            case 401:
                throw LLMProviderError.authenticationFailed
            case 429:
                throw LLMProviderError.rateLimitExceeded
            case 400:
                if errorResponse.error.code == "context_length_exceeded" {
                    throw LLMProviderError.contextTooLarge(0, 0) // Will be updated with actual values
                }
                throw LLMProviderError.invalidParameters(errorResponse.error.message)
            default:
                return errorResponse.error.message
            }
        }
        
        return "Unknown error occurred"
    }
    
    func recordRequest(duration: TimeInterval, inputTokens: Int, outputTokens: Int) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        let newRequestCount = _metrics.requestCount + 1
        let newTotalTokens = _metrics.totalTokensProcessed + inputTokens + outputTokens
        let newAverageLatency = (_metrics.averageLatency * Double(_metrics.requestCount) + duration) / Double(newRequestCount)
        let newAverageTokensPerRequest = Double(newTotalTokens) / Double(newRequestCount)
        let tokensPerSecond = duration > 0 ? Double(outputTokens) / duration : 0
        let newTokensPerSecond = (_metrics.tokensPerSecond * Double(_metrics.requestCount) + tokensPerSecond) / Double(newRequestCount)
        
        _metrics = ProviderMetrics(
            requestCount: newRequestCount,
            averageLatency: newAverageLatency,
            tokensPerSecond: newTokensPerSecond,
            errorCount: _metrics.errorCount,
            lastHealthCheck: _metrics.lastHealthCheck,
            isHealthy: _metrics.isHealthy,
            totalTokensProcessed: newTotalTokens,
            averageTokensPerRequest: newAverageTokensPerRequest
        )
    }
    
    func recordError(_ error: Error) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        _metrics = ProviderMetrics(
            requestCount: _metrics.requestCount,
            averageLatency: _metrics.averageLatency,
            tokensPerSecond: _metrics.tokensPerSecond,
            errorCount: _metrics.errorCount + 1,
            lastHealthCheck: _metrics.lastHealthCheck,
            isHealthy: _metrics.isHealthy,
            totalTokensProcessed: _metrics.totalTokensProcessed,
            averageTokensPerRequest: _metrics.averageTokensPerRequest
        )
    }
    
    func updateHealthStatus(isHealthy: Bool) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        _metrics = ProviderMetrics(
            requestCount: _metrics.requestCount,
            averageLatency: _metrics.averageLatency,
            tokensPerSecond: _metrics.tokensPerSecond,
            errorCount: _metrics.errorCount,
            lastHealthCheck: Date(),
            isHealthy: isHealthy,
            totalTokensProcessed: _metrics.totalTokensProcessed,
            averageTokensPerRequest: _metrics.averageTokensPerRequest
        )
    }
}

// MARK: - OpenAI API Models

private struct OpenAIChatRequest: Codable {
    let model: String
    let messages: [OpenAIChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let topP: Double?
    let frequencyPenalty: Double?
    let presencePenalty: Double?
    let stream: Bool
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
        case topP = "top_p"
        case frequencyPenalty = "frequency_penalty"
        case presencePenalty = "presence_penalty"
    }
}

private struct OpenAIChatMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIStreamResponse: Codable {
    let choices: [OpenAIStreamChoice]
    let usage: OpenAIUsage?
}

private struct OpenAIStreamChoice: Codable {
    let delta: OpenAIStreamDelta
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case delta
        case finishReason = "finish_reason"
    }
}

private struct OpenAIStreamDelta: Codable {
    let content: String?
}

private struct OpenAIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

private struct OpenAIErrorResponse: Codable {
    let error: OpenAIError
}

private struct OpenAIError: Codable {
    let message: String
    let type: String
    let code: String?
}

private struct OpenAIModelsResponse: Codable {
    let data: [OpenAIModelInfo]
    let object: String
}

private struct OpenAIModelInfo: Codable {
    let id: String
    let object: String
    let created: TimeInterval
    let ownedBy: String
    
    enum CodingKeys: String, CodingKey {
        case id, object, created
        case ownedBy = "owned_by"
    }
}
