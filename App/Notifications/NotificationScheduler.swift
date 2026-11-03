import Foundation
import SwiftData
import UserNotifications
import DayTrackerCore

/// Builds the repeating local notifications from check-in schedules and medicine reminders (D08).
@MainActor
enum NotificationScheduler {
    nonisolated private static let snoozePrefix = "snooze."
    nonisolated private static let snoozeInterval: TimeInterval = 15 * 60

    static func registerCategories() {
        let taken = UNNotificationAction(identifier: NotificationAction.taken, title: "Taken", options: [])
        let skip = UNNotificationAction(identifier: NotificationAction.skip, title: "Skip", options: [.destructive])
        let snooze = UNNotificationAction(identifier: NotificationAction.snooze, title: "Snooze 15 min", options: [])
        let dose = UNNotificationCategory(
            identifier: NotificationCategory.dose, actions: [taken, skip, snooze],
            intentIdentifiers: [], options: [])
        let checkIn = UNNotificationCategory(
            identifier: NotificationCategory.checkIn, actions: [snooze],
            intentIdentifiers: [], options: [])
        UNUserNotificationCenter.current().setNotificationCategories([dose, checkIn])
    }

    nonisolated static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func requestAuthorization() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { await reschedule() }
        return granted
    }

    /// Replaces all pending reminders with ones matching the current settings. Keeps snoozes.
    static func reschedule() async {
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let planned = plannedRequests(in: Persistence.container.mainContext)
        await replacePending(with: planned)
    }

    /// Sendable description of one reminder; turned into a `UNNotificationRequest` off the main actor.
    private struct PlannedRequest: Sendable {
        let trigger: PlannedTrigger
        let title: String
        let body: String
        let category: String
        let payload: NotificationPayload
    }

    nonisolated private static func replacePending(with planned: [PlannedRequest]) async {
        let center = UNUserNotificationCenter.current()
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { !$0.hasPrefix(snoozePrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for item in planned {
            try? await center.add(request(for: item))
        }
    }

    /// Re-delivers the same notification in 15 minutes, pinned to its original slot.
    static func snooze(_ original: UNNotificationContent, slot: Date) async {
        guard let content = original.mutableCopy() as? UNMutableNotificationContent else { return }
        content.userInfo[NotificationPayload.Key.scheduledFor] = slot.timeIntervalSince1970
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: snoozeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: snoozePrefix + UUID().uuidString, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func plannedRequests(in context: ModelContext) -> [PlannedRequest] {
        let schedules = ((try? context.fetch(FetchDescriptor<CheckInSchedule>())) ?? []).filter(\.enabled)
        let trackers = ((try? context.fetch(FetchDescriptor<Tracker>())) ?? []).filter { !$0.archived }
        var planned: [PlannedRequest] = []

        for schedule in schedules {
            let names = schedule.trackerIDs.compactMap { id in trackers.first { $0.id == id }?.name }
            let body = names.isEmpty
                ? "Time for your check-in."
                : names.joined(separator: ", ") + " – takes a few seconds."
            let payload = NotificationPayload(
                kind: .checkIn, targetID: schedule.id, minutes: schedule.time.minutesSinceMidnight)
            for trigger in NotificationPlanner.triggers(
                idPrefix: "checkin.\(schedule.id.uuidString)", recurring: schedule.recurring) {
                planned.append(PlannedRequest(
                    trigger: trigger, title: "\(schedule.name) check-in", body: body,
                    category: NotificationCategory.checkIn, payload: payload))
            }
        }

        for tracker in trackers where tracker.kind == .dose {
            for time in tracker.reminderTimes {
                let payload = NotificationPayload(
                    kind: .dose, targetID: tracker.id, minutes: time.minutesSinceMidnight)
                for trigger in NotificationPlanner.triggers(
                    idPrefix: "dose.\(tracker.id.uuidString).\(time.minutesSinceMidnight)",
                    recurring: RecurringTime(time: time)) {
                    planned.append(PlannedRequest(
                        trigger: trigger, title: tracker.name,
                        body: "Time to take \(tracker.name.lowercased()).",
                        category: NotificationCategory.dose, payload: payload))
                }
            }
        }

        // Leave a little room under iOS's limit for snoozed copies.
        return Array(planned.prefix(NotificationPlanner.pendingLimit - 4))
    }

    nonisolated private static func request(for item: PlannedRequest) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = item.title
        content.body = item.body
        content.sound = .default
        content.categoryIdentifier = item.category
        content.threadIdentifier = item.category
        content.userInfo = item.payload.userInfo

        var components = DateComponents()
        components.hour = item.trigger.hour
        components.minute = item.trigger.minute
        components.weekday = item.trigger.weekday
        return UNNotificationRequest(
            identifier: item.trigger.identifier,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        )
    }
}

/// Acts on notification taps and action buttons.
@MainActor
enum NotificationHandler {
    static func handle(action: String, payload: NotificationPayload, slot: Date) {
        let context = Persistence.container.mainContext
        switch payload.kind {
        case .dose:
            guard action == NotificationAction.taken || action == NotificationAction.skip,
                  let tracker = Tracker.find(id: payload.targetID, in: context)
            else { return }
            DoseRecorder.record(
                tracker, taken: action == NotificationAction.taken, slot: slot,
                source: .notificationAction, in: context)
            try? context.save()
        case .checkIn:
            if action == UNNotificationDefaultActionIdentifier {
                AppRouter.shared.activeCheckIn = CheckInRequest(scheduleID: payload.targetID, scheduledFor: slot)
            }
        }
    }
}
