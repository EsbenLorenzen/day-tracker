import SwiftData

@MainActor
enum Persistence {
    /// Shared by the SwiftUI scene and notification handling, which can run before any view exists.
    static let container: ModelContainer = {
        do {
            return try ModelContainer(for: Tracker.self, LogEntry.self, CheckInSchedule.self, CheckInSession.self)
        } catch {
            fatalError("Could not open the database: \(error)")
        }
    }()
}
