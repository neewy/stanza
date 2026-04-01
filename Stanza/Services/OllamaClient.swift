import Foundation
import os

class OllamaClient {
    static let shared = OllamaClient()
    private let baseURL = "http://127.0.0.1:11434/api"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.trackerapp", category: "OllamaClient")
    
    var currentModel: String {
        UserDefaults.standard.string(forKey: "OllamaModelName") ?? "llama3.2:3b"
    }
    
    func checkDaemonStatus() async -> Bool {
        guard let url = URL(string: "http://127.0.0.1:11434/") else { return false }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    func fetchLocalModels() async -> [String] {
        guard let url = URL(string: "\(baseURL)/tags") else { return [] }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                return models.compactMap { $0["name"] as? String }
            }
        } catch {
            print("Ollama Error: \(error)")
        }
        return []
    }
    
    // Naively pull a model (returns true if successful)
    func pullModel(name: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/pull") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: Any] = ["name": name, "stream": false]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    func summarizeContext(windows: [String], events: [String], activeSessionStart: Date? = nil) async -> String? {
        logger.debug("Received Context -> Windows: \(windows.count) events | Calendar: \(events.count) events")
        
        if windows.isEmpty && events.isEmpty {
            logger.debug("Skipping Ollama prompt: Both datasets are completely empty.")
            return "General Activity"
        }
        
        let windowString = windows.prefix(20).joined(separator: "\n")
        let eventString = events.joined(separator: "\n")
        
        var activeSessionInfo = ""
        if let start = activeSessionStart {
            let duration = Date().timeIntervalSince(start)
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            if hours > 0 {
                activeSessionInfo = "\nActive Session Duration: \(hours)h \(minutes)m (started at \(start.formatted(date: .omitted, time: .shortened)))"
            } else {
                activeSessionInfo = "\nActive Session Duration: \(minutes) minutes (started at \(start.formatted(date: .omitted, time: .shortened)))"
            }
        }
        
        let prompt = """
        Review the following recent activity context from the user's computer:
        
        Active Windows & Apps:
        \(windowString)
        
        Calendar Events:
        \(eventString)
        \(activeSessionInfo)
        
        Note: Some entries above may include keyboard/mouse input metrics (key presses, clicks) and AFK status. Use these to determine if the user is actively working or passively reading.
        """
        
        guard let url = URL(string: "\(baseURL)/generate") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "model": currentModel,
            "system": "You are a rigid data processor. Your only protocol is to extract a 2-4 word overarching task name that summarizes the user's current computing activity based on their recent window logs, calendar entries, and input activity metrics. High keyboard presses suggest active coding or writing. High mouse clicks suggest UI navigation or design work. AFK periods suggest the user stepped away. Never converse. Never provide pleasantries. Do not output quotation marks. Example outputs: 'Programming Swift App', 'Browsing Web', 'UI Design Session', 'Code Review'. If the data is empty or confusing, just return 'General Computer Usage'.",
            "prompt": prompt,
            "stream": false
        ]
        
        logger.debug("Prompting Ollama model: \(self.currentModel)")
        logger.debug("--- PROMPT ---\n\(prompt, privacy: .public)\n--------------")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseText = json["response"] as? String {
                let cleanedText = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                                              .replacingOccurrences(of: "\"", with: "")
                                              .replacingOccurrences(of: "'", with: "")
                logger.debug("--- RESPONSE ---\n\(cleanedText, privacy: .public)\n----------------")
                return cleanedText
            } else {
                let errorStr = String(data: data, encoding: .utf8) ?? "unknown"
                logger.error("Failed to parse standard Ollama JSON: \(errorStr, privacy: .public)")
            }
        } catch {
            logger.error("Ollama Generation Error: \(error.localizedDescription, privacy: .public)")
        }
        return nil
    }
}
