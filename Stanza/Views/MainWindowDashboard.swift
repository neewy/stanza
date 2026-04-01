import SwiftUI
import SwiftData

struct MainWindowDashboard: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TimeEntry.startTime, order: .reverse) private var entries: [TimeEntry]
    @Query private var categories: [Category]
    
    @State private var taskTitle: String = ""
    @State private var selectedCategory: Category?
    
    // AI States
    @State private var aiSuggestion: String? = nil
    @State private var isPredicting = false
    @State private var activeSessionStart: Date? = nil
    // UI States
    @State private var showManageCategoriesSheet = false
    
    enum ViewMode: String, CaseIterable, Identifiable {
        case list = "List"
        case calendar = "Calendar"
        var id: String { self.rawValue }
    }
    
    @State private var viewMode: ViewMode = .list
    @State private var selectedEntry: TimeEntry?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                TextField("What are you working on?", text: $taskTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.title3)
                
                Menu {
                    ForEach(categories) { category in
                        Button(action: {
                            selectedCategory = category
                            // Update running entry category immediately
                            if let running = runningEntry {
                                running.category = category
                                syncAll()
                            }
                        }) {
                            HStack {
                                Circle().fill(category.color).frame(width: 8, height: 8)
                                Text(category.name)
                            }
                        }
                    }
                    Button("Manage Categories...") {
                        showManageCategoriesSheet = true
                    }
                } label: {
                    HStack {
                        if let cat = selectedCategory {
                            Circle().fill(cat.color).frame(width: 8, height: 8)
                            Text(cat.name)
                        } else {
                            Image(systemName: "tag")
                            Text("Category")
                        }
                    }
                }
                
                if let running = runningEntry {
                    DatePicker("", selection: Binding(get: { running.startTime }, set: { running.startTime = $0 }), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .onChange(of: running.startTime) { syncAll() }
                        
                    TimerView(entry: running)
                        .font(.title3.monospacedDigit())
                        .foregroundColor(.red)
                        .padding(.horizontal)
                    
                    Button(action: stopTracking) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: startTracking) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(taskTitle.isEmpty)
                }
                }
                
                // AI Row
                if isPredicting {
                    HStack {
                        ProgressView().controlSize(.small)
                        Text("AI is reading context...").font(.caption).foregroundColor(.secondary)
                    }
                } else if let suggestion = aiSuggestion {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Button(action: {
                                taskTitle = suggestion
                                aiSuggestion = nil
                            }) {
                                HStack {
                                    Image(systemName: "sparkles").foregroundColor(.purple)
                                    Text("Suggest Task: \(suggestion)").font(.caption)
                                }
                            }
                            .buttonStyle(.plain)
                            
                            if let start = activeSessionStart {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.arrow.circlepath")
                                    Text("Active for \(formatActiveDuration(since: start)) (since \(start.formatted(date: .omitted, time: .shortened)))")
                                }
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            }
                        }
                        
                        Spacer()
                        
                        if activeSessionStart != nil {
                            Button(action: {
                                taskTitle = suggestion
                                startTrackingFrom(date: activeSessionStart!)
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.purple)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } else {
                    Button(action: deriveContext) {
                        HStack {
                            Image(systemName: "sparkles").foregroundColor(.purple)
                            Text("Generate AI Suggestion").font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .sheet(isPresented: $showManageCategoriesSheet) {
                ManageCategoriesSheet()
            }
            .onAppear {
                NSApplication.shared.activate(ignoringOtherApps: true)
                // Sync UI with running entry
                if let running = runningEntry {
                    selectedCategory = running.category
                    taskTitle = running.title
                }
            }
            .onChange(of: runningEntry) { old, new in
                if let new = new {
                    selectedCategory = new.category
                    taskTitle = new.title
                }
            }
            
            VStack(spacing: 0) {
                Picker("", selection: $viewMode) {
                    ForEach(ViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            
            Divider()
            
            if viewMode == .list {
                // List of previous entries grouped dynamically by chronos layout
                List {
                    let grouped = Dictionary(grouping: entries.filter { !$0.isRunning }) { entry in
                        Calendar.current.startOfDay(for: entry.startTime)
                    }
                    let sortedDays = grouped.keys.sorted(by: >)
                    
                    ForEach(sortedDays, id: \.self) { day in
                        Section(header: Text(formatDay(day)).font(.caption).foregroundColor(.secondary)) {
                            ForEach(grouped[day] ?? []) { entry in
                                EntryRowView(entry: entry, onPlay: {
                                    taskTitle = entry.title
                                    selectedCategory = entry.category
                                    startTracking()
                                }, onClick: {
                                    selectedEntry = entry
                                })
                            }
                            .onDelete { offsets in
                                deleteEntries(offsets: offsets, day: day, grouped: grouped)
                            }
                        }
                    }
                }
            } else {
                DailyCalendarLayoutView(entries: entries, selectedEntry: $selectedEntry)
            }
        }
        .inspector(isPresented: Binding(
            get: { selectedEntry != nil },
            set: { if !$0 { selectedEntry = nil } }
        )) {
            if let entry = selectedEntry {
                EntryDetailsEditor(entry: entry, categories: categories, onSync: syncAll, onDelete: {
                    modelContext.delete(entry)
                    selectedEntry = nil
                    syncAll()
                }, onClose: {
                    selectedEntry = nil
                })
            }
        }
        .inspectorColumnWidth(min: 350, ideal: 400, max: 800)
    }
    
    var runningEntry: TimeEntry? {
        entries.first { $0.isRunning }
    }
    
    private func startTracking() {
        // Stop any running task first
        if runningEntry != nil {
            stopTracking()
        }
        
        let newEntry = TimeEntry(title: taskTitle, category: selectedCategory)
        modelContext.insert(newEntry)
        taskTitle = ""
        aiSuggestion = nil
    }
    
    private func deriveContext() {
        Task {
            isPredicting = true
            let context = await ActivityWatchClient.shared.fetchFullContext()
            let calendarEvents = CalendarService.shared.fetchUpcomingEvents()
            
            let suggestion = await OllamaClient.shared.summarizeContext(
                windows: context.windowTitles,
                events: calendarEvents,
                activeSessionStart: context.activeSessionStart
            )
            
            await MainActor.run {
                self.activeSessionStart = context.activeSessionStart
                self.aiSuggestion = suggestion ?? "Unknown Activity"
                self.isPredicting = false
            }
        }
    }
    
    private func stopTracking() {
        guard let running = runningEntry else { return }
        
        // Sync edited title from the input field before stopping
        if !taskTitle.isEmpty {
            running.title = taskTitle
        }
        running.endTime = Date()
        taskTitle = ""
        
        // Sync to ActivityWatch
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
    
    private func deleteEntries(offsets: IndexSet, day: Date, grouped: [Date: [TimeEntry]]) {
        if let dayEntries = grouped[day] {
            for index in offsets {
                modelContext.delete(dayEntries[index])
            }
            syncAll()
        }
    }
    
    private func formatDay(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func syncAll() {
        Task {
            await ActivityWatchClient.shared.rebuildTrackerBucket(entries: entries)
        }
    }
    
    private func startTrackingFrom(date: Date) {
        // Save title before stopTracking clears it
        let title = taskTitle
        
        // Stop any running task first
        if runningEntry != nil {
            stopTracking()
        }
        
        let newEntry = TimeEntry(title: title, category: selectedCategory)
        newEntry.startTime = date
        modelContext.insert(newEntry)
        taskTitle = title  // Restore so the user sees the tracked task name
        aiSuggestion = nil
        activeSessionStart = nil
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
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00:00"
    }
}

struct EntryRowView: View {
    @Bindable var entry: TimeEntry
    var onPlay: () -> Void
    var onClick: () -> Void
    
    var body: some View {
        Button(action: onClick) {
            HStack {
                Text(entry.title.isEmpty ? "No description" : entry.title)
                    .font(.body)
                    .lineLimit(1)
                
                Spacer()
                
                if let cat = entry.category {
                    Text(cat.name)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(cat.color.opacity(0.2))
                        .cornerRadius(4)
                }
                
                Text(formatDuration(entry.duration))
                    .font(.body.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
                
                Button(action: onPlay) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.blue)
                        .frame(width: 20)
                }
                .buttonStyle(.plain)
                .padding(.leading, 8)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00:00"
    }
}

struct TimerView: View {
    let entry: TimeEntry
    @State private var timeString = "00:00:00"
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(timeString)
            .onReceive(timer) { _ in
                let duration = Date().timeIntervalSince(entry.startTime)
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.unitsStyle = .positional
                formatter.zeroFormattingBehavior = .pad
                timeString = formatter.string(from: duration) ?? "00:00:00"
            }
            .onAppear {
                let duration = Date().timeIntervalSince(entry.startTime)
                let formatter = DateComponentsFormatter()
                formatter.allowedUnits = [.hour, .minute, .second]
                formatter.unitsStyle = .positional
                formatter.zeroFormattingBehavior = .pad
                timeString = formatter.string(from: duration) ?? "00:00:00"
            }
    }
}
