import SwiftUI
import UserNotifications
import DayTrackerCore

/// Today's check-in occurrences with their status; due ones can be answered from here too.
struct TodayCheckIns: View {
    let day: DateInterval
    let schedules: [CheckInSchedule]
    let sessions: [CheckInSession]

    private struct Slot: Identifiable {
        let schedule: CheckInSchedule
        let time: Date
        let session: CheckInSession?
        var id: String { "\(schedule.id.uuidString)-\(time.timeIntervalSince1970)" }
    }

    var body: some View {
        let now = Date.now
        let slots: [Slot] = schedules.filter(\.enabled).flatMap { (schedule: CheckInSchedule) -> [Slot] in
            schedule.recurring.occurrences(in: day, calendar: .current).map { (time: Date) -> Slot in
                Slot(schedule: schedule, time: time, session: sessions.first {
                    $0.scheduleID == schedule.id && $0.scheduledFor == time
                })
            }
        }
        .sorted { $0.time < $1.time }

        if !slots.isEmpty {
            VStack(spacing: 0) {
                ForEach(slots) { slot in
                    CheckInRow(name: slot.schedule.name, time: slot.time, session: slot.session, now: now) {
                        AppRouter.shared.activeCheckIn = CheckInRequest(
                            scheduleID: slot.schedule.id, scheduledFor: slot.time)
                    }
                    if slot.id != slots.last?.id {
                        Divider()
                    }
                }
            }
            .card()
        }
    }
}

private struct CheckInRow: View {
    enum RowState {
        case upcoming, due, answered, partial, skipped, missed
    }

    let name: String
    let time: Date
    let session: CheckInSession?
    let now: Date
    let open: () -> Void

    private var rowState: RowState {
        if let session {
            switch session.status {
            case .answered: return .answered
            case .partial: return .partial
            case .skipped: return .skipped
            case .missed: return .missed
            case .pending: return CheckInPolicy.isOverdue(time, now: now) ? .missed : .due
            }
        }
        if time > now { return .upcoming }
        return CheckInPolicy.isDue(time, now: now) ? .due : .missed
    }

    var body: some View {
        let state = rowState
        Button(action: open) {
            HStack(spacing: 14) {
                Image(systemName: icon(state))
                    .font(.title3)
                    .foregroundStyle(color(state))
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(time.shortTime) · \(label(state))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if state == .due || state == .partial {
                    Text(state == .due ? "Answer" : "Continue")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .foregroundStyle(.white)
                        .background(Color.accentColor, in: .capsule)
                }
            }
            .padding(.vertical, 8)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(state == .upcoming || state == .answered || state == .skipped)
    }

    private func icon(_ state: RowState) -> String {
        switch state {
        case .upcoming: "clock"
        case .due: "bell.badge.fill"
        case .answered: "checkmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .skipped: "forward.circle"
        case .missed: "exclamationmark.circle"
        }
    }

    private func color(_ state: RowState) -> Color {
        switch state {
        case .upcoming, .skipped: .secondary
        case .due: .accentColor
        case .answered: .green
        case .partial: .orange
        case .missed: .red
        }
    }

    private func label(_ state: RowState) -> String {
        switch state {
        case .upcoming: "Upcoming"
        case .due: "Due now"
        case .answered: "Answered"
        case .partial: "Partly answered"
        case .skipped: "Skipped"
        case .missed: "Missed – tap to answer late"
        }
    }
}

/// Asks for notification permission on the Today screen (not at first launch, D08).
struct ReminderPermissionBanner: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        Group {
            switch status {
            case .notDetermined?:
                banner(
                    title: "Turn on reminders",
                    message: "DayTracker can remind you at check-in and medicine times.",
                    button: "Turn on"
                ) {
                    Task {
                        _ = await NotificationScheduler.requestAuthorization()
                        await refresh()
                    }
                }
            case .denied?:
                banner(
                    title: "Reminders are off",
                    message: "Notifications for DayTracker are turned off in iOS Settings.",
                    button: "Open Settings"
                ) {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
            default:
                EmptyView()
            }
        }
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
    }

    private func refresh() async {
        status = await NotificationScheduler.authorizationStatus()
    }

    private func banner(title: String, message: String, button: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "bell.badge")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button(button, action: action)
                    .buttonStyle(.borderedProminent)
            }
            Spacer(minLength: 0)
        }
        .card()
    }
}
