import SwiftUI
import SwiftData

struct EntryDetailsEditor: View {
    @Bindable var entry: TimeEntry
    var categories: [Category]
    var onSync: () -> Void
    var onDelete: () -> Void
    var onClose: () -> Void
    
    @State private var showManageCategoriesSheet = false
    @State private var windowActivities: [WindowActivity] = []
    @State private var timelineBlocks: [TimelineBlock] = []
    @State private var isLoadingActivity = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("DETAILS").font(.headline).foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    onSync()
                    onClose()
                }) { 
                    Image(systemName: "xmark") 
                }.buttonStyle(.plain)
            }
            .padding(.bottom, 20)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("Task Name", text: $entry.title)
                        .textFieldStyle(.roundedBorder)
                    
                    HStack {
                        Menu {
                            ForEach(categories) { cat in
                                Button(cat.name) { entry.category = cat }
                            }
                            Button("Clear") { entry.category = nil }
                            Divider()
                            Button("Manage Categories...") { showManageCategoriesSheet = true }
                        } label: {
                            if let cat = entry.category {
                                Text(cat.name)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(cat.color.opacity(0.15))
                                    .foregroundColor(cat.color)
                                    .cornerRadius(6)
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag")
                                    Text("No Category")
                                }
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            }
                        }
                        .menuStyle(.borderlessButton)
                        
                        Spacer()
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("DURATION").font(.caption).foregroundColor(.secondary).bold()
                        
                        DatePicker("Start time", selection: $entry.startTime, displayedComponents: [.date, .hourAndMinute])
                            .font(.subheadline)
                        
                        if let end = entry.endTime {
                            DatePicker("End time", selection: Binding(
                                get: { end },
                                set: { entry.endTime = $0 }
                            ), displayedComponents: [.date, .hourAndMinute])
                            .font(.subheadline)
                        }
                    }
                    
                    Divider()
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ACTIVITY").font(.caption).foregroundColor(.secondary).bold()
                        
                        if isLoadingActivity {
                            HStack {
                                Spacer()
                                ProgressView().scaleEffect(0.8)
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else if windowActivities.isEmpty {
                            Text("No activity data available for this period.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.vertical, 10)
                        } else {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(windowActivities.prefix(12)) { activity in
                                    ActivityRow(activity: activity, totalDuration: entry.duration)
                                }
                            }
                        }
                    }

                    if !timelineBlocks.isEmpty {
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TIMELINE").font(.caption).foregroundColor(.secondary).bold()
                            
                            TimelineListView(blocks: timelineBlocks)
                        }
                    }
                }
                .padding(.trailing, 8) // Space for scrollbar
            }
            
            Divider().padding(.vertical, 16)
            
            // Sticky Footer
            HStack {
                Button(role: .destructive, action: onDelete) {
                    Text("Delete").foregroundColor(.red)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Save") {
                    onSync()
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .sheet(isPresented: $showManageCategoriesSheet) {
            ManageCategoriesSheet()
        }
        .task(id: entry.startTime) {
            await fetchActivity()
        }
        .task(id: entry.endTime) {
            await fetchActivity()
        }
    }
    
    private func fetchActivity() async {
        guard let endTime = entry.endTime else { 
            windowActivities = []
            timelineBlocks = []
            return 
        }
        
        isLoadingActivity = true
        async let activities = ActivityWatchClient.shared.fetchWindowActivity(from: entry.startTime, to: endTime)
        async let timeline = ActivityWatchClient.shared.fetchTimeline(from: entry.startTime, to: endTime)
        
        let (windowActs, timelineBlks) = await (activities, timeline)
        
        windowActivities = windowActs
        timelineBlocks = timelineBlks
        isLoadingActivity = false
    }
}

struct TimelineListView: View {
    let blocks: [TimelineBlock]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks.indices, id: \.self) { index in
                TimelineBlockView(block: blocks[index], isFirst: index == 0, isLast: index == blocks.count - 1)
            }
        }
    }
}

struct TimelineBlockView: View {
    let block: TimelineBlock
    let isFirst: Bool
    let isLast: Bool
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 8, height: 8)
                
                if !isLast {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 2)
                }
            }
            .frame(width: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(block.app)
                        .font(.caption)
                        .bold()
                    
                    Spacer()
                    
                    Text(block.startTime.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                
                Text(formatDuration(block.duration))
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                
                if let firstTitle = block.titles.first {
                    Text(firstTitle)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(.bottom, isLast ? 0 : 16)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration / 60)
        let secs = Int(duration.truncatingRemainder(dividingBy: 60))
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

struct ActivityRow: View {
    let activity: WindowActivity
    let totalDuration: TimeInterval
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(activity.app)
                    .font(.caption)
                    .fontWeight(.bold)
                    .lineLimit(1)
                Spacer()
                Text(formatDuration(activity.duration))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            
            if !activity.title.isEmpty {
                Text(activity.title)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
            }
            
            // Minimalist activity bar
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.secondary.opacity(0.1))
                    .frame(height: 3)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.8))
                    .frame(width: max(2, (CGFloat(activity.duration / totalDuration) * 100).clamped(to: 0...100) / 100 * 200), height: 3) 
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let mins = Int(duration / 60)
        let secs = Int(duration.truncatingRemainder(dividingBy: 60))
        if mins > 0 {
            return "\(mins)m \(secs)s"
        } else {
            return "\(secs)s"
        }
    }
}

extension Comparable {
    func clamped(to limits: ClosedRange<Self>) -> Self {
        return min(max(self, limits.lowerBound), limits.upperBound)
    }
}
