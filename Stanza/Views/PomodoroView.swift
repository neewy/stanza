import SwiftUI
import SwiftData
import UserNotifications

enum PomodoroPhase: String {
    case focus = "Focus"
    case shortBreak = "Short Break"
    case longBreak = "Long Break"
}

struct PomodoroView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var categories: [Category]
    
    // Timer state
    @State private var phase: PomodoroPhase = .focus
    @State private var timeRemaining: TimeInterval = 25 * 60
    @State private var isRunning = false
    @State private var sessionStartTime: Date?
    @State private var completedPomodoros: Int = 0
    
    // Task info
    @State private var focusTitle: String = ""
    @State private var selectedCategory: Category?
    
    // Settings & State
    @State private var showSettings = false
    @State private var showManageCategoriesSheet = false
    @State private var focusDuration: Double = 25
    @State private var shortBreakDuration: Double = 5
    @State private var longBreakDuration: Double = 15
    @State private var pomodorosBeforeLongBreak: Int = 4
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var progress: Double {
        let total = totalSecondsForPhase
        guard total > 0 else { return 0 }
        return 1.0 - (timeRemaining / total)
    }
    
    var totalSecondsForPhase: TimeInterval {
        switch phase {
        case .focus: return focusDuration * 60
        case .shortBreak: return shortBreakDuration * 60
        case .longBreak: return longBreakDuration * 60
        }
    }
    
    var phaseColor: Color {
        switch phase {
        case .focus: return .purple
        case .shortBreak: return .green
        case .longBreak: return .blue
        }
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Focus task input
            HStack {
                TextField("I'm focusing on...", text: $focusTitle)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .disabled(isRunning)
                
                Menu {
                    ForEach(categories) { category in
                        Button(action: { selectedCategory = category }) {
                            HStack {
                                Circle().fill(category.color).frame(width: 8, height: 8)
                                Text(category.name)
                            }
                        }
                    }
                    Divider()
                    Button("Manage Categories...") {
                        showManageCategoriesSheet = true
                    }
                } label: {
                    HStack {
                        if let cat = selectedCategory {
                            Circle().fill(cat.color).frame(width: 8, height: 8)
                            Text(cat.name).lineLimit(1)
                        } else {
                            Image(systemName: "tag")
                            Text("Category")
                        }
                    }
                }
                .fixedSize()
            }
            .padding(.horizontal, 40)
            .padding(.top, 60)
            
            // Circular timer
            ZStack {
                // Track ring
                Circle()
                    .stroke(Color.secondary.opacity(0.15), lineWidth: 8)
                    .frame(width: 220, height: 220)
                
                // Progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        phaseColor,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                
                // Tick marks
                ForEach(0..<60) { tick in
                    Rectangle()
                        .fill(tick % 5 == 0 ? Color.white.opacity(0.5) : Color.white.opacity(0.15))
                        .frame(width: tick % 5 == 0 ? 2 : 1, height: tick % 5 == 0 ? 12 : 6)
                        .offset(y: -90)
                        .rotationEffect(.degrees(Double(tick) * 6))
                }
                
                // Center content
                VStack(spacing: 4) {
                    Text(phase.rawValue)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(formatTime(timeRemaining))
                        .font(.system(size: 44, weight: .bold, design: .monospaced))
                    
                    if !isRunning && timeRemaining == totalSecondsForPhase {
                        Text("Ready?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else if isRunning {
                        Text("Stay focused")
                            .font(.subheadline)
                            .foregroundColor(phaseColor)
                    }
                }
            }
            
            // Pomodoro count indicators
            HStack(spacing: 10) {
                ForEach(0..<pomodorosBeforeLongBreak, id: \.self) { i in
                    ZStack {
                        Circle()
                            .stroke(i < completedPomodoros ? Color.purple : Color.secondary.opacity(0.3), lineWidth: 1.5)
                            .frame(width: 14, height: 14)
                        if i < completedPomodoros {
                            Circle()
                                .fill(Color.purple)
                                .frame(width: 14, height: 14)
                        }
                    }
                }
            }
            
            // Start / Stop button
            Button(action: toggleTimer) {
                Text(isRunning ? "Pause" : (timeRemaining < totalSecondsForPhase ? "Resume" : "Start session"))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(phaseColor)
                    )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            
            // Skip / Reset controls
            HStack(spacing: 20) {
                if isRunning || timeRemaining < totalSecondsForPhase {
                    Button("Reset") {
                        resetTimer()
                    }
                    .foregroundColor(.secondary)
                    .buttonStyle(.plain)
                    
                    Button("Skip →") {
                        skipPhase()
                    }
                    .foregroundColor(.secondary)
                    .buttonStyle(.plain)
                }
            }
            
            Spacer()
            
            // Settings link
            Button(action: { showSettings.toggle() }) {
                Text("Pomodoro settings ▸")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
        .onReceive(timer) { _ in
            guard isRunning else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
            } else {
                phaseCompleted()
            }
        }
        .sheet(isPresented: $showSettings) {
            PomodoroSettingsView(
                focusDuration: $focusDuration,
                shortBreakDuration: $shortBreakDuration,
                longBreakDuration: $longBreakDuration,
                pomodorosBeforeLongBreak: $pomodorosBeforeLongBreak,
                onDismiss: {
                    showSettings = false
                    resetTimer()
                }
            )
        }
        .sheet(isPresented: $showManageCategoriesSheet) {
            ManageCategoriesSheet()
        }
    }
    
    // MARK: - Actions
    
    private func toggleTimer() {
        if isRunning {
            isRunning = false
        } else {
            if sessionStartTime == nil {
                sessionStartTime = Date()
            }
            isRunning = true
        }
    }
    
    private func resetTimer() {
        isRunning = false
        sessionStartTime = nil
        timeRemaining = totalSecondsForPhase
    }
    
    private func skipPhase() {
        if phase == .focus {
            completedPomodoros += 1
            logFocusSession()
        }
        advancePhase()
    }
    
    private func phaseCompleted() {
        isRunning = false
        
        // Send notification
        sendNotification()
        
        if phase == .focus {
            completedPomodoros += 1
            logFocusSession()
        }
        
        advancePhase()
    }
    
    private func advancePhase() {
        isRunning = false
        sessionStartTime = nil
        
        switch phase {
        case .focus:
            if completedPomodoros >= pomodorosBeforeLongBreak {
                phase = .longBreak
                completedPomodoros = 0
            } else {
                phase = .shortBreak
            }
        case .shortBreak, .longBreak:
            phase = .focus
        }
        
        timeRemaining = totalSecondsForPhase
    }
    
    private func logFocusSession() {
        guard let start = sessionStartTime else { return }
        let title = focusTitle.isEmpty ? "Pomodoro Focus" : focusTitle
        let entry = TimeEntry(title: title, category: selectedCategory)
        entry.startTime = start
        entry.endTime = Date()
        modelContext.insert(entry)
        
        Task {
            let catName = selectedCategory?.name ?? "Uncategorized"
            _ = await ActivityWatchClient.shared.sendEvent(
                title: title,
                startTime: start,
                endTime: Date(),
                category: catName
            )
        }
        
        sessionStartTime = nil
    }
    
    private func sendNotification() {
        let content = UNMutableNotificationContent()
        switch phase {
        case .focus:
            content.title = "Focus session complete!"
            content.body = "Time for a break. You've earned it."
        case .shortBreak:
            content.title = "Break's over!"
            content.body = "Ready for another focus session?"
        case .longBreak:
            content.title = "Long break's over!"
            content.body = "Let's get back to work."
        }
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
    
    private func formatTime(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Settings Sheet

struct PomodoroSettingsView: View {
    @Binding var focusDuration: Double
    @Binding var shortBreakDuration: Double
    @Binding var longBreakDuration: Double
    @Binding var pomodorosBeforeLongBreak: Int
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pomodoro Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Focus: \(Int(focusDuration)) min")
                Slider(value: $focusDuration, in: 5...60, step: 5)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Short Break: \(Int(shortBreakDuration)) min")
                Slider(value: $shortBreakDuration, in: 1...15, step: 1)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Long Break: \(Int(longBreakDuration)) min")
                Slider(value: $longBreakDuration, in: 5...30, step: 5)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text("Pomodoros before long break: \(pomodorosBeforeLongBreak)")
                Picker("", selection: $pomodorosBeforeLongBreak) {
                    ForEach(2...8, id: \.self) { n in
                        Text("\(n)").tag(n)
                    }
                }
                .pickerStyle(.segmented)
            }
            
            HStack {
                Spacer()
                Button("Done") { onDismiss() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 350)
    }
}
