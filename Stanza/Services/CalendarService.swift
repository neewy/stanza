import Foundation
import EventKit

class CalendarService {
    static let shared = CalendarService()
    let store = EKEventStore()
    
    var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        } else {
            return status == .authorized
        }
    }
    
    func requestAccess() async -> Bool {
        do {
            if #available(macOS 14.0, *) {
                return try await store.requestFullAccessToEvents()
            } else {
                return try await store.requestAccess(to: .event)
            }
        } catch {
            return false
        }
    }
    
    func fetchUpcomingEvents() -> [String] {
        guard isAuthorized else { return [] }
        
        let calendars = store.calendars(for: .event)
        
        let startDate = Date()
        let endDate = Date().addingTimeInterval(3600 * 2) // Next 2 hours
        
        let predicate = store.predicateForEvents(withStart: startDate, end: endDate, calendars: calendars)
        let events = store.events(matching: predicate)
        
        return events.compactMap { $0.title }
    }
}
