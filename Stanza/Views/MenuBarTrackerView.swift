import SwiftUI
import SwiftData

struct MenuBarTrackerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimeEntry.startTime, order: .reverse) private var entries: [TimeEntry]
    @Query private var categories: [Category]
    
    @State private var suggestion: String = "Loading suggestions..."
    @State private var taskTitle: String = ""
    @State private var isPredicting = true
    @State private var activeDataSources: [String] = []
    @State private var activeSessionStart: Date? = nil
    @State private var selectedCategory: Category? = nil
    
    var runningEntry: TimeEntry? {
        entries.first { $0.isRunning }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let running = runningEntry {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Actively Tracking").font(.caption).foregroundColor(.secondary)
                        Text(running.title).font(.headline)
                        
                        Menu {
                            ForEach(categories) { category in
                                Button(action: {
                                    running.category = category
                                    selectedCategory = category
                                }) {
                                    HStack {
                                        Circle().fill(category.color).frame(width: 8, height: 8)
                                        Text(category.name)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                if let cat = running.category {
                                    Circle().fill(cat.color).frame(width: 6, height: 6)
                                    Text(cat.name).font(.caption).foregroundColor(cat.color)
                                } else {
                                    Image(systemName: "tag")
                                    Text("No Category").font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.link)
                    }
                    Spacer()
                    TimerView(entry: running)
                        .font(.title2.monospacedDigit())
                    
                    Button(action: stopTracking) {
                        Image(systemName: "stop.circle.fill")
                            .foregroundColor(.red)
                            .font(.title)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            } else {
                Text("Not tracking").font(.caption).foregroundColor(.secondary)
            }
            
            Divider()
            
            Text("Suggestions")
                .font(.subheadline)
                .bold()
                
            if !activeDataSources.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "sensor.tag.radiowaves.forward")
                    Text("Sources: \(activeDataSources.joined(separator: ", "))")
                }
                .font(.system(size: 9))
                .foregroundColor(.green)
                .padding(.bottom, 2)
            }
            
            if isPredicting {
                HStack {
                    ProgressView().controlSize(.small)
                    Text("AI is generating a context...").font(.caption)
                }
            } else {
                Button(action: {
                    taskTitle = suggestion
                    startTracking(backdateTo: activeSessionStart)
                }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                            Text(suggestion)
                                .font(.body)
                            Spacer()
                            Image(systemName: "play.circle")
                        }
                        
                        if let start = activeSessionStart {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.arrow.circlepath")
                                Text("Active for \(formatActiveDuration(since: start)) (since \(start.formatted(date: .omitted, time: .shortened)))")
                            }
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Manual Start
            HStack {
                TextField("Manual entry...", text: $taskTitle)
                    .textFieldStyle(.roundedBorder)
                
                Menu {
                    ForEach(categories) { category in
                        Button(action: {
                            selectedCategory = category
                        }) {
                            HStack {
                                Circle().fill(category.color).frame(width: 8, height: 8)
                                Text(category.name)
                            }
                        }
                    }
                } label: {
                    if let cat = selectedCategory {
                        Circle().fill(cat.color).frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "tag")
                    }
                }
                .buttonStyle(.plain)
                .frame(width: 24)

                Button(action: { startTracking() }) {
                    Image(systemName: "play.fill")
                }
                .disabled(taskTitle.isEmpty)
            }
            
            Divider()
            
            Button("Quit Tracker") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.link)
            .foregroundColor(.red.opacity(0.8))
            .font(.caption)
            .frame(maxWidth: .infinity, alignment: .trailing)
            
        }
        .padding()
        .frame(width: 350)
        .onAppear {
            deriveContext()
            // Sync with running task
            if let running = runningEntry {
                selectedCategory = running.category
                taskTitle = running.title
            } else if selectedCategory == nil {
                selectedCategory = categories.first
            }
        }
    }
    
    func deriveContext() {
        Task {
            isPredicting = true
            
            // UI Status
            let sources = await ActivityWatchClient.shared.fetchActiveWatchers()
            await MainActor.run { self.activeDataSources = sources }
            
            let context = await ActivityWatchClient.shared.fetchFullContext()
            let calendarEvents = CalendarService.shared.fetchUpcomingEvents()
            
            let aiSuggestion = await OllamaClient.shared.summarizeContext(
                windows: context.windowTitles,
                events: calendarEvents,
                activeSessionStart: context.activeSessionStart
            )
            
            await MainActor.run {
                self.activeSessionStart = context.activeSessionStart
                self.suggestion = aiSuggestion ?? "Unknown Activity"
                self.isPredicting = false
            }
        }
    }
    
    func startTracking(backdateTo: Date? = nil) {
        if runningEntry != nil {
            stopTracking()
        }
        let categoryToUse = selectedCategory ?? categories.first
        let newEntry = TimeEntry(title: taskTitle, category: categoryToUse)
        if let start = backdateTo {
            newEntry.startTime = start
        }
        modelContext.insert(newEntry)
        taskTitle = ""
        activeSessionStart = nil
    }
    
    func stopTracking() {
        guard let running = runningEntry else { return }
        running.endTime = Date()
        Task {
            let catName = running.category?.name ?? "Uncategorized"
            _ = await ActivityWatchClient.shared.sendEvent(
                title: running.title,
                startTime: running.startTime,
                endTime: running.endTime ?? Date(),
                category: catName
            )
        }
    }
    
    private func formatActiveDuration(since date: Date) -> String {
        let duration = Date().timeIntervalSince(date)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}
