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

        let requests = plannedRequests(in: Persistence.container.mainContext)
        await replacePending(with: requests)
    }

    /// Runs off the main actor so the (non-Sendable) requests never cross isolation per item.
    nonisolated private static func replacePending(with requests: [UNNotificationRequest]) async {
        let center = UNUserNotificationCenter.current()
        let stale = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { !$0.hasPrefix(snoozePrefix) }
        center.removePendingNotificationRequests(withIdentifiers: stale)
        for request in requests {
            try? await center.add(request)
        }
    }

    /// Re-delivers the same notification in 15 minutes, pinned to its original slot.
    nonisolated static func snooze(_ original: UNNotificationContent, slot: Date) async {
        guard let content = original.mutableCopy() as? UNMutableNotificationContent else { return }
        content.userInfo[NotificationPayload.Key.scheduledFor] = slot.timeIntervalSince1970
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: snoozeInterval, repeats: false)
        let request = UNNotificationRequest(
            identifier: snoozePrefix + UUID().uuidString, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private static func plannedRequests(in context: ModelContext) -> [UNNotificationRequest] {
        let schedules = ((try? context.fetch(FetchDescriptor<CheckInSchedule>())) ?? []).filter(\.enabled)
        let trackers = ((try? context.fetch(FetchDescriptor<Tracker>())) ?? []).filter { !$0.archived }
        var requests: [UNNotificationRequest] = []

        for schedule in schedules {
            let names = schedule.trackerIDs.compactMap { id in trackers.first { $0.id == id }?.name }
            let body = names.isEmpty
                ? "Time for your check-in."
                : names.joined(separator: ", ") + " – takes a few seconds."
            let payload = NotificationPayload(
                kind: .checkIn, targetID: schedule.id, minutes: schedule.time.minutesSinceMidnight)
            for trigger in NotificationPlanner.triggers(
                idPrefix: "checkin.\(schedule.id.uuidString)", recurring: schedule.recurring) {
                requests.append(request(trigger, content: content(
                    title: "\(schedule.name) check-in", body: body,
                    category: NotificationCategory.checkIn, payload: payload)))
            }
        }

        for tracker in trackers where tracker.kind == .dose {
            for time in tracker.reminderTimes {
                let payload = NotificationPayload(
                    kind: .dose, targetID: tracker.id, minutes: time.minutesSinceMidnight)
                for trigger in NotificationPlanner.triggers(
                    idPrefix: "dose.\(tracker.id.uuidString).\(time.minutesSinceMidnight)",
                    recurring: RecurringTime(time: time)) {
                    requests.append(request(trigger, content: content(
                        title: tracker.name, body: "Time to take \(tracker.name.lowercased()).",
                        category: NotificationCategory.dose, payload: payload)))
                }
            }
        }

        // Leave a little room under iOS's limit for snoozed copies.
        return Array(requests.prefix(NotificationPlanner.pendingLimit - 4))
    }

    private static func content(
        title: String, body: String, category: String, payload: NotificationPayload
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = category
        content.threadIdentifier = category
        content.userInfo = payload.userInfo
        return content
    }

    private static func request(_ trigger: PlannedTrigger, content: UNMutableNotificationContent) -> UNNotificationRequest {
        var components = DateComponents()
        components.hour = trigger.hour
        components.minute = trigger.minute
        components.weekday = trigger.weekday
        return UNNotificationRequest(
            identifier: trigger.identifier,
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
