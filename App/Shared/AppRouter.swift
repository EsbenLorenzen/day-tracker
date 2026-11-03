import Foundation
import Observation

/// One check-in occurrence to answer.
struct CheckInRequest: Identifiable, Hashable {
    let scheduleID: UUID
    let scheduledFor: Date
    var id: String { "\(scheduleID.uuidString)-\(scheduledFor.timeIntervalSince1970)" }
}

/// App-wide navigation state that notification taps can change.
@MainActor
@Observable
final class AppRouter {
    static let shared = AppRouter()

    var activeCheckIn: CheckInRequest?
}
