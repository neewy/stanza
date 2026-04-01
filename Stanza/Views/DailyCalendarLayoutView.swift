import SwiftUI
import SwiftData

struct DailyCalendarLayoutView: View {
    let entries: [TimeEntry]
    @Binding var selectedEntry: TimeEntry?
    
    // Config
    let hourHeight: CGFloat = 60
    
    var todayEntries: [TimeEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDateInToday($0.startTime) }
    }
    
    var body: some View {
        ScrollView {
            ZStack(alignment: .topLeading) {
                // Background hour lines
                VStack(spacing: 0) {
                    ForEach(0..<25) { hour in
                        HStack(alignment: .top) {
                            Text(String(format: "%02d:00", hour == 24 ? 0 : hour))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 40, alignment: .trailing)
                            
                            Rectangle()
                                .fill(Color.secondary.opacity(0.1))
                                .frame(height: 1)
                                .offset(y: 6) // Align with text
                        }
                        .frame(height: hourHeight, alignment: .top)
                    }
                }
                
                // Overlay Time Blocks
                ForEach(todayEntries) { entry in
                    let cal = Calendar.current
                    let startHour = cal.component(.hour, from: entry.startTime)
                    let startMinute = cal.component(.minute, from: entry.startTime)
                    let startMinutesTotal = CGFloat(startHour * 60 + startMinute)
                    
                    let durationMinutes = CGFloat(entry.duration / 60)
                    let blockHeight = max(durationMinutes * (hourHeight / 60.0), 15) // Ensure minimum tap area
                    
                    Button {
                        selectedEntry = entry
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.title.isEmpty ? "No description" : entry.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                            
                            if let cat = entry.category {
                                Text(cat.name).font(.caption2).lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: blockHeight)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(entry.category?.color.opacity(0.3) ?? Color.blue.opacity(0.3))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(entry.category?.color ?? Color.blue, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.leading, 50)
                    .padding(.trailing, 10)
                    .offset(y: startMinutesTotal * (hourHeight / 60.0) + 6)
                }
            }
            .padding(.vertical)
        }
    }
}
