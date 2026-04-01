import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Query private var entries: [TimeEntry]
    @AppStorage("isOnboardingComplete") private var isOnboardingComplete = true
    
    var chartData: [(category: String, duration: TimeInterval, color: Color)] {
        var dict: [String: (TimeInterval, Color)] = [:]
        
        for entry in entries {
            let catName = entry.category?.name ?? "Uncategorized"
            let duration = entry.duration
            let catColor = entry.category?.color ?? .gray
            
            if let existing = dict[catName] {
                dict[catName] = (existing.0 + duration, existing.1)
            } else {
                dict[catName] = (duration, catColor)
            }
        }
        
        return dict.map { (category: $0.key, duration: $0.value.0, color: $0.value.1) }
            .sorted { $0.duration > $1.duration }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Areas of Work")
                .font(.title)
                .bold()
                .padding(.bottom, 20)
            
            if chartData.isEmpty {
                ContentUnavailableView("No Data", systemImage: "chart.bar.xaxis", description: Text("Track time to see reports."))
            } else {
                Chart(chartData, id: \.category) { item in
                    BarMark(
                        x: .value("Duration (Hours)", item.duration / 3600.0),
                        y: .value("Category", item.category)
                    )
                    .foregroundStyle(item.color)
                    .annotation(position: .trailing) {
                        Text(formatDuration(item.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 300)
            }
            
            Spacer()
            Divider()
            
            HStack {
                Text("Developer Testing:")
                    .foregroundColor(.secondary)
                Button("Reset Setup Wizard") {
                    isOnboardingComplete = false
                }
            }
            .font(.caption)
            .padding(.top, 10)
        }
        .padding(40)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0h"
    }
}
