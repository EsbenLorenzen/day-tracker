import Foundation
import SwiftData
import DayTrackerCore

/// One occurrence of a check-in. Identified by schedule + scheduled time.
@Model
final class CheckInSession {
    var id: UUID = UUID()
    var scheduleID: UUID = UUID()
    var scheduledFor: Date = Date.now
    var openedAt: Date?
    var completedAt: Date?
    var statusRaw: String = CheckInStatus.pending.rawValue
    var questionCount: Int = 0
    var answeredCount: Int = 0

    init(scheduleID: UUID, scheduledFor: Date) {
        self.scheduleID = scheduleID
        self.scheduledFor = scheduledFor
    }

    var status: CheckInStatus {
        get { CheckInStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

@MainActor
enum CheckInStore {
    static func session(scheduleID: UUID, scheduledFor: Date, in context: ModelContext) -> CheckInSession? {
        var descriptor = FetchDescriptor<CheckInSession>(
            predicate: #Predicate { $0.scheduleID == scheduleID && $0.scheduledFor == scheduledFor })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Finds or creates the session for this occurrence and marks it opened.
    static func open(_ request: CheckInRequest, questionCount: Int, in context: ModelContext) -> CheckInSession {
        let session: CheckInSession
        if let existing = Self.session(scheduleID: request.scheduleID, scheduledFor: request.scheduledFor, in: context) {
            session = existing
        } else {
            session = CheckInSession(scheduleID: request.scheduleID, scheduledFor: request.scheduledFor)
            context.insert(session)
        }
        if session.openedAt == nil { session.openedAt = .now }
        session.questionCount = questionCount
        return session
    }

    static func recordAnswer(_ session: CheckInSession) {
        session.answeredCount += 1
        session.status = .progress(answered: session.answeredCount, total: session.questionCount)
        if session.status == .answered { session.completedAt = .now }
    }

    static func skip(_ session: CheckInSession) {
        session.status = session.answeredCount == 0 ? .skipped : .partial
        session.completedAt = .now
    }

    /// Marks unanswered past check-ins as missed (D16). Runs on launch and when returning to the app.
    static func reconcile(now: Date = .now, in context: ModelContext) {
        let calendar = Calendar.current
        let lookbackStart = calendar.date(byAdding: .day, value: -CheckInPolicy.lookbackDays, to: now) ?? now
        let schedules = (try? context.fetch(FetchDescriptor<CheckInSchedule>())) ?? []
        let sessions = (try? context.fetch(FetchDescriptor<CheckInSession>(
            predicate: #Predicate { $0.scheduledFor >= lookbackStart }))) ?? []

        for session in sessions
        where session.status == .pending && session.answeredCount == 0
            && CheckInPolicy.isOverdue(session.scheduledFor, now: now) {
            session.status = .missed
        }

        for schedule in schedules where schedule.enabled {
            let existing = Set(sessions.filter { $0.scheduleID == schedule.id }.map(\.scheduledFor))
            let missed = CheckInPolicy.missedOccurrences(
                of: schedule.recurring,
                since: max(schedule.updatedAt, lookbackStart),
                now: now,
                existing: existing,
                calendar: calendar
            )
            for occurrence in missed {
                let session = CheckInSession(scheduleID: schedule.id, scheduledFor: occurrence)
                session.status = .missed
                session.questionCount = schedule.trackerIDs.count
                context.insert(session)
            }
        }
        try? context.save()
    }
}
