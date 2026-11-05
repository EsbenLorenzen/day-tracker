import SwiftUI
import SwiftData
import UserNotifications
import DayTrackerCore

struct SettingsView: View {
    @State private var editingSchedule: ScheduleEditorTarget?
    @State private var testStatus: String?

    var body: some View {
        NavigationStack {
            Form {
                NotificationStatusSection()

                CheckInSchedulesSection { editingSchedule = $0 }

                MedicinesSection()

                Section {
                    NavigationLink {
                        TrackersView()
                    } label: {
                        Label("Counters, ratings, numbers, notes", systemImage: "slider.horizontal.3")
                    }
                } header: {
                    Text("Trackers")
                } footer: {
                    Text("Add your own, e.g. stress, alcohol, steps or a journal line. They show up on Today, in Trends and as check-in questions.")
                }

                DataSection()

                Section {
                    Button("Send test notification in 10 s") {
                        Task { testStatus = await NotificationTester.scheduleTest() }
                    }
                    if let testStatus {
                        Text(testStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Troubleshooting")
                }

                Section("About") {
                    LabeledContent("Version", value: AppConfig.version)
                }
            }
            .navigationTitle("Settings")
            .sheet(item: $editingSchedule) { target in
                CheckInScheduleEditor(target: target)
            }
        }
    }
}

private struct NotificationStatusSection: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var status: UNAuthorizationStatus?

    var body: some View {
        Section("Reminders") {
            LabeledContent("Notifications", value: statusText)
            if status == .notDetermined {
                Button("Turn on reminders") {
                    Task {
                        _ = await NotificationScheduler.requestAuthorization()
                        await refresh()
                    }
                }
            }
            if status == .denied {
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                }
            }
        }
        .task { await refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await refresh() } }
        }
    }

    private var statusText: String {
        switch status {
        case .authorized?, .provisional?: "On"
        case .denied?: "Off"
        case .notDetermined?: "Not set up"
        default: "…"
        }
    }

    private func refresh() async {
        status = await NotificationScheduler.authorizationStatus()
    }
}

enum ScheduleEditorTarget: Identifiable {
    case new
    case edit(CheckInSchedule)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let schedule): schedule.id.uuidString
        }
    }
}

private struct CheckInSchedulesSection: View {
    let onEdit: (ScheduleEditorTarget) -> Void

    @Query(sort: [SortDescriptor(\CheckInSchedule.hour), SortDescriptor(\CheckInSchedule.minute)])
    private var schedules: [CheckInSchedule]

    var body: some View {
        Section {
            ForEach(schedules) { schedule in
                Button {
                    onEdit(.edit(schedule))
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(schedule.name)
                                .foregroundStyle(schedule.enabled ? Color.primary : Color.secondary)
                            Text(schedule.enabled ? schedule.days.summary() : "Off")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(schedule.time.display)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Button("Add check-in", systemImage: "plus") { onEdit(.new) }
        } header: {
            Text("Check-ins")
        } footer: {
            Text("You get a notification at these times with the selected questions.")
        }
    }
}

private struct MedicinesSection: View {
    @Query(filter: #Predicate<Tracker> { $0.archived == false }, sort: \Tracker.sortOrder)
    private var trackers: [Tracker]

    var body: some View {
        let medicines = trackers.filter { $0.kind == .dose }
        Section {
            ForEach(medicines) { tracker in
                NavigationLink {
                    MedicineDetailView(tracker: tracker)
                } label: {
                    MedicineRow(tracker: tracker)
                }
            }
            NavigationLink {
                MedicinesView()
            } label: {
                Label("Add, reorder or archive", systemImage: "list.bullet")
            }
        } header: {
            Text("Medicines")
        } footer: {
            Text("Tap a medicine to rename it or set its reminder times.")
        }
    }
}

@MainActor
enum NotificationTester {
    static func scheduleTest() async -> String {
        let center = UNUserNotificationCenter.current()
        do {
            guard try await center.requestAuthorization(options: [.alert, .sound, .badge]) else {
                return "Notifications are off. Turn them on in Settings → Apps → DayTracker."
            }
            let content = UNMutableNotificationContent()
            content.title = "DayTracker"
            content.body = "Test notification – it works! 🎉"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            let request = UNNotificationRequest(identifier: "test", content: content, trigger: trigger)
            try await center.add(request)
            return "Scheduled – it should arrive in about 10 seconds."
        } catch {
            return "Failed: \(error.localizedDescription)"
        }
    }
}
