import Foundation

/// Bundles all context data from ActivityWatch for AI and UI consumption.
struct ActivityContext {
    let windowTitles: [String]
    let activeSessionStart: Date?  // When the current active session began (nil if no AFK data)
}

struct WindowActivity: Identifiable, Sendable {
    let id = UUID()
    let app: String
    let title: String
    let duration: TimeInterval
}

struct TimelineBlock: Identifiable, Sendable {
    let id = UUID()
    let app: String
    let startTime: Date
    let duration: TimeInterval
    let titles: [String]
}

class ActivityWatchClient {
    static let shared = ActivityWatchClient()
    private let baseURL = "http://127.0.0.1:5600/api/0"
    
    // Check if the daemon is reachable
    func checkDaemonStatus() async -> Bool {
        guard let url = URL(string: "\(baseURL)/info") else { return false }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    // Check which deep watchers are running
    func fetchActiveWatchers() async -> [String] {
        guard let bucketsURL = URL(string: "\(baseURL)/buckets/") else { return [] }
        var request = URLRequest(url: bucketsURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let buckets = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
            var active = Set<String>()
            for key in buckets.keys {
                if key.contains("aw-watcher-window") { active.insert("Window") }
                if key.contains("aw-watcher-web") { active.insert("Browser") }
                if key.contains("aw-watcher-vscode") { active.insert("VSCode") }
                if key.contains("aw-watcher-input") { active.insert("Keyboard") }
            }
            return Array(active).sorted()
        } catch { return [] }
    }
    
    // Create the custom bucket
    func createTrackerBucketIfNeeded() async -> Bool {
        guard let url = URL(string: "\(baseURL)/buckets/aw-watcher-tracker_app") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let payload: [String: Any] = [
            "client": "tracker_app",
            "type": "currentwindow", // Reusing this type so it shows nicely
            "hostname": Host.current().localizedName ?? "macOS"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200 || (response as? HTTPURLResponse)?.statusCode == 304
        } catch {
            return false
        }
    }
    
    // Completely obliterate and meticulously rebuild the tracker bucket
    func rebuildTrackerBucket(entries: [TimeEntry]) async {
        guard let url = URL(string: "\(baseURL)/buckets/aw-watcher-tracker_app?force=1") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        let _ = try? await URLSession.shared.data(for: request)
        
        // Wait gracefully to ensure deletion closure
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        let created = await createTrackerBucketIfNeeded()
        if created {
            // Replay every single log backward into time sequentially
            for entry in entries where !entry.isRunning {
                let catName = entry.category?.name ?? "Uncategorized"
                _ = await sendEvent(title: entry.title, startTime: entry.startTime, endTime: entry.endTime ?? Date(), category: catName)
            }
        }
    }
    
    // Sync a manual time entry to AW
    @discardableResult
    func sendEvent(title: String, startTime: Date, endTime: Date, category: String) async -> Bool {
        guard let url = URL(string: "\(baseURL)/buckets/aw-watcher-tracker_app/events") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let duration = endTime.timeIntervalSince(startTime)
        
        // Event format specification
        let payload: [String: Any] = [
            "timestamp": formatter.string(from: startTime),
            "duration": duration,
            "data": [
                "title": title,
                "app": category // We exploit 'app' key to group by category in AW UI
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (_, response) = try await URLSession.shared.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
    
    // Fetch last 15 mins of active window data + input/afk context
    func fetchRecentWindows() async -> [String] {
        guard let bucketsURL = URL(string: "\(baseURL)/buckets/") else { return [] }
        var request = URLRequest(url: bucketsURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let buckets = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
            
            let targetBuckets = buckets.keys.filter {
                $0.contains("aw-watcher-window") ||
                $0.contains("aw-watcher-web") ||
                $0.contains("aw-watcher-vscode") ||
                $0.contains("aw-watcher-afk") ||
                $0.contains("aw-watcher-input")
            }
            guard !targetBuckets.isEmpty else { return [] }
            
            var titles = Set<String>()
            let endTime = ISO8601DateFormatter().string(from: Date())
            let startTime = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-15 * 60))
            
            // Accumulators for input metrics
            var totalKeyPresses = 0
            var totalClicks = 0
            var afkSeconds: TimeInterval = 0
            var activeSeconds: TimeInterval = 0
            var inputEvents: [(timestamp: Date, presses: Int, clicks: Int)] = []
            
            let isoParserFrac = ISO8601DateFormatter()
            isoParserFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let isoParserPlain = ISO8601DateFormatter()
            isoParserPlain.formatOptions = [.withInternetDateTime]
            
            for bucket in targetBuckets {
                let queryURL = URL(string: "\(baseURL)/query/")!
                var queryRequest = URLRequest(url: queryURL)
                queryRequest.httpMethod = "POST"
                queryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let query = """
                events = query_bucket('\(bucket)');
                RETURN = events;
                """
                
                let payload: [String: Any] = [
                    "query": [query],
                    "timeperiods": ["\(startTime)/\(endTime)"]
                ]
                
                queryRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let (queryData, _) = try await URLSession.shared.data(for: queryRequest)
                
                guard let results = try? JSONSerialization.jsonObject(with: queryData) as? [[ [String: Any] ]],
                      let firstSet = results.first else { continue }
                
                for event in firstSet {
                    let duration = event["duration"] as? Double ?? 0
                    if let data = event["data"] as? [String: Any] {
                        if bucket.contains("aw-watcher-window") {
                            let title = (data["title"] as? String ?? "").trimmingCharacters(in: .whitespaces)
                            let app = data["app"] as? String ?? ""
                            if app != "loginwindow" && !title.isEmpty && !app.isEmpty {
                                titles.insert("\(app) - \(title)")
                            }
                        } else if bucket.contains("aw-watcher-web") {
                            let url = (data["url"] as? String ?? "").trimmingCharacters(in: .whitespaces)
                            let title = (data["title"] as? String ?? "").trimmingCharacters(in: .whitespaces)
                            if !url.isEmpty {
                                titles.insert("Browser URL: \(url) - \(title)")
                            }
                        } else if bucket.contains("aw-watcher-vscode") {
                            let file = (data["file"] as? String ?? "").trimmingCharacters(in: .whitespaces)
                            let project = (data["project"] as? String ?? "").trimmingCharacters(in: .whitespaces)
                            let language = (data["language"] as? String ?? "").trimmingCharacters(in: .whitespaces)
                            if !file.isEmpty {
                                titles.insert("VSCode Project [\(project)]: Editing \(file) (\(language))")
                            }
                        } else if bucket.contains("aw-watcher-afk") {
                            let status = data["status"] as? String ?? ""
                            if status == "afk" {
                                afkSeconds += duration
                            } else {
                                activeSeconds += duration
                            }
                        } else if bucket.contains("aw-watcher-input") {
                            let presses = (data["presses"] as? NSNumber)?.intValue ?? 0
                            let clicks = (data["clicks"] as? NSNumber)?.intValue ?? 0
                            totalKeyPresses += presses
                            totalClicks += clicks
                            
                            // Capture per-event data for timeline
                            if presses > 0 || clicks > 0, let ts = event["timestamp"] as? String {
                                if let date = isoParserFrac.date(from: ts) ?? isoParserPlain.date(from: ts) {
                                    inputEvents.append((timestamp: date, presses: presses, clicks: clicks))
                                }
                            }
                        }
                    }
                }
            }
            
            // Synthesize input timeline
            if !inputEvents.isEmpty {
                let timeFormatter = DateFormatter()
                timeFormatter.dateFormat = "h:mm a"
                
                // Sort by time and show individual events for granular context
                let sorted = inputEvents.sorted { $0.timestamp < $1.timestamp }
                
                var inputLines: [String] = ["Input Activity Timeline (last 15m):"]
                for event in sorted.suffix(15) { // Cap at 15 most recent events
                    let time = timeFormatter.string(from: event.timestamp)
                    var label = ""
                    if event.presses > 50 { label = " [heavy typing]" }
                    else if event.presses > 20 { label = " [moderate typing]" }
                    else if event.clicks > 20 { label = " [mouse-heavy]" }
                    inputLines.append("  \(time): \(event.presses) keys, \(event.clicks) clicks\(label)")
                }
                inputLines.append("  Total: \(totalKeyPresses) key presses, \(totalClicks) mouse clicks")
                titles.insert(inputLines.joined(separator: "\n"))
            } else if totalKeyPresses > 0 || totalClicks > 0 {
                titles.insert("Input Activity (last 15m): \(totalKeyPresses) key presses, \(totalClicks) mouse clicks")
            }
            if afkSeconds > 30 {
                let afkMins = Int(afkSeconds / 60)
                titles.insert("User was AFK for \(afkMins)m \(Int(afkSeconds.truncatingRemainder(dividingBy: 60)))s in the last 15 minutes")
            }
            if activeSeconds > 0 {
                let activeMins = Int(activeSeconds / 60)
                titles.insert("User was actively at computer for \(activeMins)m \(Int(activeSeconds.truncatingRemainder(dividingBy: 60)))s")
            }
            
            return Array(titles)
            
        } catch {
            print("Error parsing AW: \(error)")
            return []
        }
    }
    
    /// Determine when the user's current active (not-AFK) session began.
    /// Walks backward through the AFK watcher bucket; any AFK period > 60s is a session boundary.
    /// Returns nil if the AFK bucket doesn't exist or the user is currently AFK.
    func fetchActiveSessionStart() async -> Date? {
        guard let bucketsURL = URL(string: "\(baseURL)/buckets/") else { return nil }
        var request = URLRequest(url: bucketsURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let buckets = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
            
            // Find the AFK bucket
            guard let afkBucket = buckets.keys.first(where: { $0.contains("aw-watcher-afk") }) else {
                return nil // No AFK watcher running
            }
            
            // Query a generous window (last 8 hours) to find the session boundary
            let endTime = ISO8601DateFormatter().string(from: Date())
            let startTime = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-8 * 60 * 60))
            
            let queryURL = URL(string: "\(baseURL)/query/")!
            var queryRequest = URLRequest(url: queryURL)
            queryRequest.httpMethod = "POST"
            queryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            // Sort events newest-first so we can walk backward easily
            let query = """
            events = query_bucket('\(afkBucket)');
            events = sort_by_timestamp(events);
            RETURN = events;
            """
            
            let payload: [String: Any] = [
                "query": [query],
                "timeperiods": ["\(startTime)/\(endTime)"]
            ]
            
            queryRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (queryData, _) = try await URLSession.shared.data(for: queryRequest)
            
            guard let results = try? JSONSerialization.jsonObject(with: queryData) as? [[ [String: Any] ]],
                  let events = results.first, !events.isEmpty else { return nil }
            
            // Events are oldest-first after sort_by_timestamp; reverse to walk backward from now
            let reversed = events.reversed()
            
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let isoFormatterFallback = ISO8601DateFormatter()
            isoFormatterFallback.formatOptions = [.withInternetDateTime]
            
            // Check if the most recent event is "not-afk" (user is currently active)
            if let latest = reversed.first,
               let latestData = latest["data"] as? [String: String],
               latestData["status"] == "afk" {
                // User is currently AFK — no active session
                return nil
            }
            
            // Walk backward: find the first AFK event with duration > 60s — that's the session boundary
            for event in reversed {
                guard let eventData = event["data"] as? [String: String],
                      let timestampStr = event["timestamp"] as? String,
                      let duration = event["duration"] as? Double else { continue }
                
                let status = eventData["status"] ?? ""
                
                if status == "afk" && duration > 60 {
                    // Session boundary: the active session started at the END of this AFK event
                    if let eventStart = isoFormatter.date(from: timestampStr) ?? isoFormatterFallback.date(from: timestampStr) {
                        let sessionStart = eventStart.addingTimeInterval(duration)
                        return sessionStart
                    }
                }
            }
            
            // If we walked all 8 hours without a >60s AFK gap, use the earliest event timestamp
            if let earliest = events.first,
               let ts = earliest["timestamp"] as? String {
                return isoFormatter.date(from: ts) ?? isoFormatterFallback.date(from: ts)
            }
            
            return nil
        } catch {
            print("Error fetching AFK session: \(error)")
            return nil
        }
    }
    
    /// Unified context fetch: windows + AFK session start in parallel.
    func fetchFullContext() async -> ActivityContext {
        async let windows = fetchRecentWindows()
        async let sessionStart = fetchActiveSessionStart()
        
        return ActivityContext(
            windowTitles: await windows,
            activeSessionStart: await sessionStart
        )
    }

    /// Fetch window activity for a specific time range, aggregated by app and title.
    func fetchWindowActivity(from startTime: Date, to endTime: Date) async -> [WindowActivity] {
        guard let bucketsURL = URL(string: "\(baseURL)/buckets/") else { return [] }
        var request = URLRequest(url: bucketsURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let buckets = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
            
            // We focus on the main window bucket for details
            let targetBuckets = buckets.keys.filter { $0.contains("aw-watcher-window") }
            if targetBuckets.isEmpty { return [] }
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let startStr = formatter.string(from: startTime)
            let endStr = formatter.string(from: endTime)
            
            var activityMap: [String: [String: Double]] = [:] // App -> [Title -> Duration]
            
            for bucket in targetBuckets {
                let queryURL = URL(string: "\(baseURL)/query/")!
                var queryRequest = URLRequest(url: queryURL)
                queryRequest.httpMethod = "POST"
                queryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let query = """
                events = query_bucket('\(bucket)');
                RETURN = events;
                """
                
                let payload: [String: Any] = [
                    "query": [query],
                    "timeperiods": ["\(startStr)/\(endStr)"]
                ]
                
                queryRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let (queryData, _) = try await URLSession.shared.data(for: queryRequest)
                
                guard let results = try? JSONSerialization.jsonObject(with: queryData) as? [[ [String: Any] ]],
                      let events = results.first else { continue }
                
                for event in events {
                    let duration = event["duration"] as? Double ?? 0
                    if let eventData = event["data"] as? [String: Any] {
                        let app = eventData["app"] as? String ?? "Unknown"
                        let title = eventData["title"] as? String ?? ""
                        
                        if app == "loginwindow" || title.isEmpty { continue }
                        
                        var appActivity = activityMap[app] ?? [:]
                        appActivity[title] = (appActivity[title] ?? 0) + duration
                        activityMap[app] = appActivity
                    }
                }
            }
            
            // Flatten and sort
            var flattened: [WindowActivity] = []
            for (app, titles) in activityMap {
                for (title, duration) in titles {
                    if duration > 1 { // Filter out micro-switches
                        flattened.append(WindowActivity(app: app, title: title, duration: duration))
                    }
                }
            }
            
            return flattened.sorted { $0.duration > $1.duration }
            
        } catch {
            print("Error fetching window activity for entry: \(error)")
            return []
        }
    }

    /// Fetch window activity timeline for a specific time range, grouped by contiguous app usage.
    func fetchTimeline(from startTime: Date, to endTime: Date) async -> [TimelineBlock] {
        guard let bucketsURL = URL(string: "\(baseURL)/buckets/") else { return [] }
        var request = URLRequest(url: bucketsURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let buckets = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [] }
            
            let targetBuckets = buckets.keys.filter { $0.contains("aw-watcher-window") }
            if targetBuckets.isEmpty { return [] }
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let startStr = formatter.string(from: startTime)
            let endStr = formatter.string(from: endTime)
            
            var allEvents: [[String: Any]] = []
            
            for bucket in targetBuckets {
                let queryURL = URL(string: "\(baseURL)/query/")!
                var queryRequest = URLRequest(url: queryURL)
                queryRequest.httpMethod = "POST"
                queryRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let query = """
                events = query_bucket('\(bucket)');
                events = sort_by_timestamp(events);
                RETURN = events;
                """
                
                let payload: [String: Any] = [
                    "query": [query],
                    "timeperiods": ["\(startStr)/\(endStr)"]
                ]
                
                queryRequest.httpBody = try JSONSerialization.data(withJSONObject: payload)
                let (queryData, _) = try await URLSession.shared.data(for: queryRequest)
                
                guard let results = try? JSONSerialization.jsonObject(with: queryData) as? [[ [String: Any] ]],
                      let events = results.first else { continue }
                
                allEvents.append(contentsOf: events)
            }
            
            // Sort all events by timestamp (if from multiple buckets)
            let sortedEvents = allEvents.sorted {
                let ts1 = $0["timestamp"] as? String ?? ""
                let ts2 = $1["timestamp"] as? String ?? ""
                return ts1 < ts2
            }
            
            var blocks: [TimelineBlock] = []
            var currentBlock: (app: String, start: Date, duration: Double, titles: Set<String>)?
            
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            
            let isoFormatterFallback = ISO8601DateFormatter()
            isoFormatterFallback.formatOptions = [.withInternetDateTime]
            
            for event in sortedEvents {
                let duration = event["duration"] as? Double ?? 0
                guard let eventData = event["data"] as? [String: Any],
                      let tsStr = event["timestamp"] as? String,
                      let date = isoFormatter.date(from: tsStr) ?? isoFormatterFallback.date(from: tsStr) else { continue }
                
                let app = eventData["app"] as? String ?? "Unknown"
                let title = eventData["title"] as? String ?? ""
                
                if app == "loginwindow" || title.isEmpty { continue }
                
                if let current = currentBlock, current.app == app {
                    // Continue current block
                    var titles = current.titles
                    titles.insert(title)
                    currentBlock = (app: app, start: current.start, duration: current.duration + duration, titles: titles)
                } else {
                    // Switch blocks
                    if let finished = currentBlock {
                        if finished.duration > 1 {
                            blocks.append(TimelineBlock(app: finished.app, startTime: finished.start, duration: finished.duration, titles: Array(finished.titles).sorted()))
                        }
                    }
                    currentBlock = (app: app, start: date, duration: duration, titles: [title])
                }
            }
            
            // Final block
            if let finished = currentBlock, finished.duration > 1 {
                blocks.append(TimelineBlock(app: finished.app, startTime: finished.start, duration: finished.duration, titles: Array(finished.titles).sorted()))
            }
            
            return blocks
            
        } catch {
            print("Error fetching timeline: \(error)")
            return []
        }
    }
}
