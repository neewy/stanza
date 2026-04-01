import Foundation
import SwiftData

@Model
final class TimeEntry {
    @Attribute(.unique) var id: UUID
    var title: String
    var startTime: Date
    var endTime: Date?
    
    var category: Category?
    
    init(id: UUID = UUID(), title: String, startTime: Date = Date(), endTime: Date? = nil, category: Category? = nil) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.category = category
    }
    
    var duration: TimeInterval {
        return (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    var isRunning: Bool {
        return endTime == nil
    }
}
