import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var diagnostics: DiagnosticsService
    @EnvironmentObject private var appState: AppStateManager
    
    @State private var selectedTimeRange: TimeRange = .lastHour
    @State private var autoRefresh = true
    @State private var refreshTimer: Timer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            header
            
            // Metrics overview
            metricsOverview
            
            // Charts and detailed views
            ScrollView {
                LazyVStack(spacing: 16) {
                    performanceMetrics
                    
                    providerHealth
                    
                    recentActivity
                    
                    systemMetrics
                }
                .padding()
            }
        }
        .navigationTitle("Diagnostics")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.displayName).tag(range)
                    }
                }
                .pickerStyle(.menu)
                
                Toggle("Auto Refresh", isOn: $autoRefresh)
                
                Button("Export") {
                    exportDiagnostics()
                }
                
                Button("Clear") {
                    diagnostics.clearMetrics()
                }
            }
        }
        .onAppear {
            setupAutoRefresh()
        }
        .onDisappear {
            refreshTimer?.invalidate()
        }
        .onChange(of: autoRefresh) { _ in
            setupAutoRefresh()
        }
    }
    
    @ViewBuilder
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("System Diagnostics")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Monitor performance and health metrics")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            healthIndicator
        }
        .padding()
    }
    
    @ViewBuilder
    private var healthIndicator: some View {
        let healthStatus = diagnostics.getHealthStatus()
        
        HStack(spacing: 8) {
            Circle()
                .fill(Color(healthStatus.level.color))
                .frame(width: 12, height: 12)
            
            Text(healthStatus.message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
    
    @ViewBuilder
    private var metricsOverview: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
            MetricCard(
                title: "Avg Latency",
                value: String(format: "%.0fms", diagnostics.metrics.averageLatency * 1000),
                icon: "speedometer",
                color: .blue,
                trend: .stable
            )
            
            MetricCard(
                title: "Tokens/sec",
                value: String(format: "%.1f", diagnostics.metrics.tokensPerSecond),
                icon: "gauge",
                color: .green,
                trend: .up
            )
            
            MetricCard(
                title: "Requests",
                value: "\(diagnostics.metrics.totalRequests)",
                icon: "arrow.up.arrow.down",
                color: .orange,
                trend: .up
            )
            
            MetricCard(
                title: "Error Rate",
                value: String(format: "%.1f%%", diagnostics.metrics.errorRate * 100),
                icon: "exclamationmark.triangle",
                color: diagnostics.metrics.errorRate > 0.05 ? .red : .gray,
                trend: diagnostics.metrics.errorRate > 0.05 ? .down : .stable
            )
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var performanceMetrics: some View {
        GroupBox("Performance Metrics") {
            VStack(spacing: 16) {
                // Latency chart placeholder
                ChartPlaceholder(title: "Response Latency", metric: "ms")
                
                // Tokens per second chart placeholder
                ChartPlaceholder(title: "Tokens per Second", metric: "tokens/s")
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var providerHealth: some View {
        GroupBox("Provider Health") {
            VStack(spacing: 12) {
                let providerMetrics = diagnostics.getProviderMetrics()
                
                if providerMetrics.isEmpty {
                    Text("No providers configured")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(Array(providerMetrics.keys), id: \.self) { providerId in
                        if let metrics = providerMetrics[providerId] {
                            ProviderHealthRow(providerId: providerId, metrics: metrics)
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var recentActivity: some View {
        GroupBox("Recent Activity") {
            VStack(spacing: 8) {
                let recentRequests = diagnostics.getRecentRequests(limit: 10)
                
                if recentRequests.isEmpty {
                    Text("No recent activity")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(recentRequests) { request in
                        RequestRow(request: request)
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var systemMetrics: some View {
        GroupBox("System Resources") {
            VStack(spacing: 16) {
                // Memory usage
                HStack {
                    Text("Memory Usage")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(String(format: "%.1f MB", diagnostics.metrics.memoryUsage.currentMB))
                        .foregroundColor(.secondary)
                }
                
                ProgressView(value: diagnostics.metrics.memoryUsage.currentMB / diagnostics.metrics.memoryUsage.availableMB)
                    .tint(.blue)
                
                // Uptime
                HStack {
                    Text("Uptime")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(formatUptime(diagnostics.metrics.uptime))
                        .foregroundColor(.secondary)
                }
                
                // Session count
                HStack {
                    Text("Active Sessions")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(diagnostics.metrics.sessionCount)")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
    }
    
    private func setupAutoRefresh() {
        refreshTimer?.invalidate()
        
        if autoRefresh {
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
                // Refresh metrics
            }
        }
    }
    
    private func exportDiagnostics() {
        let savePanel = NSSavePanel()
        savePanel.title = "Export Diagnostics"
        savePanel.nameFieldStringValue = "oneshot_diagnostics_\(Date().formatted(date: .numeric, time: .omitted)).json"
        savePanel.allowedContentTypes = [.json]
        
        if savePanel.runModal() == .OK,
           let url = savePanel.url {
            do {
                let data = diagnostics.exportMetrics(format: .json)
                try data.write(to: url)
            } catch {
                print("Failed to export: \(error)")
            }
        }
    }
    
    private func formatUptime(_ uptime: TimeInterval) -> String {
        let hours = Int(uptime) / 3600
        let minutes = (Int(uptime) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let trend: TrendDirection
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
                
                Image(systemName: trend.iconName)
                    .foregroundColor(trend.color)
                    .font(.caption)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

enum TrendDirection {
    case up, down, stable
    
    var iconName: String {
        switch self {
        case .up: return "arrow.up"
        case .down: return "arrow.down"
        case .stable: return "minus"
        }
    }
    
    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }
}

struct ChartPlaceholder: View {
    let title: String
    let metric: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 120)
                .overlay {
                    Text("Chart: \(title) (\(metric))")
                        .foregroundColor(.secondary)
                }
                .cornerRadius(8)
        }
    }
}

struct ProviderHealthRow: View {
    let providerId: String
    let metrics: ProviderMetrics
    
    var body: some View {
        HStack {
            Circle()
                .fill(metrics.isHealthy ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            
            Text(providerId.capitalized)
                .font(.body)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(metrics.requestCount) requests")
                    .font(.caption)
                
                Text(String(format: "%.0fms avg", metrics.averageLatency * 1000))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct RequestRow: View {
    let request: RequestMetric
    
    var body: some View {
        HStack {
            Circle()
                .fill(request.success ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(request.modelId)
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(request.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("\(request.totalTokens) tokens")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(String(format: "%.0fms", request.latency * 1000))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

enum TimeRange: String, CaseIterable {
    case lastHour = "1h"
    case last6Hours = "6h"
    case last24Hours = "24h"
    case lastWeek = "7d"
    
    var displayName: String {
        switch self {
        case .lastHour: return "Last Hour"
        case .last6Hours: return "Last 6 Hours"
        case .last24Hours: return "Last 24 Hours"
        case .lastWeek: return "Last Week"
        }
    }
}

// MARK: - Sessions View

struct SessionsView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @State private var searchText = ""
    @State private var showingArchived = false
    @State private var selectedSession: SessionSummary?
    
    var body: some View {
        VStack {
            // Search and filters
            HStack {
                TextField("Search sessions...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                Toggle("Archived", isOn: $showingArchived)
                
                Button("New Session") {
                    createNewSession()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            // Sessions list
            if filteredSessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text(showingArchived ? "No archived sessions" : "No sessions yet")
                        .font(.headline)
                    
                    Text(showingArchived ? "Archive sessions to see them here" : "Start a conversation to create your first session")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filteredSessions, id: \.id, selection: $selectedSession) { session in
                    SessionDetailRow(session: session)
                        .onTapGesture {
                            openSession(session)
                        }
                        .contextMenu {
                            Button("Open") {
                                openSession(session)
                            }
                            
                            Button(session.isArchived ? "Unarchive" : "Archive") {
                                toggleArchive(session)
                            }
                            
                            Button("Duplicate") {
                                duplicateSession(session)
                            }
                            
                            Divider()
                            
                            Button("Delete", role: .destructive) {
                                deleteSession(session)
                            }
                        }
                }
            }
        }
        .navigationTitle("Sessions")
    }
    
    private var filteredSessions: [SessionSummary] {
        let sessions = showingArchived ? sessionManager.getArchivedSessions() : sessionManager.getActiveSessions()
        
        if searchText.isEmpty {
            return sessions
        } else {
            return sessionManager.searchSessions(query: searchText, filters: nil)
        }
    }
    
    private func createNewSession() {
        let session = sessionManager.createQuickSession(provider: "openai", model: "gpt-4")
        sessionManager.setCurrentSession(session)
    }
    
    private func openSession(_ session: SessionSummary) {
        Task {
            if let fullSession = try? sessionManager.getSession(id: session.id) {
                sessionManager.setCurrentSession(fullSession)
            }
        }
    }
    
    private func toggleArchive(_ session: SessionSummary) {
        do {
            if session.isArchived {
                try sessionManager.unarchiveSession(id: session.id)
            } else {
                try sessionManager.archiveSession(id: session.id)
            }
        } catch {
            print("Failed to toggle archive: \(error)")
        }
    }
    
    private func duplicateSession(_ session: SessionSummary) {
        do {
            let _ = try sessionManager.duplicateSession(session.id)
        } catch {
            print("Failed to duplicate session: \(error)")
        }
    }
    
    private func deleteSession(_ session: SessionSummary) {
        do {
            try sessionManager.deleteSession(id: session.id)
        } catch {
            print("Failed to delete session: \(error)")
        }
    }
}

struct SessionDetailRow: View {
    let session: SessionSummary
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                if session.isArchived {
                    Text("Archived")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
            
            HStack {
                Label(session.provider, systemImage: "brain")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Label(session.model, systemImage: "cpu")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(session.lastModified, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("\(session.messageCount) messages")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text("\(session.totalTokens) tokens")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
struct DiagnosticsView_Previews: PreviewProvider {
    static var previews: some View {
        DiagnosticsView()
            .environmentObject(MockDiagnosticsService())
            .environmentObject(AppStateManager(container: DefaultServiceContainer().setupTestContainer()))
    }
}
#endif