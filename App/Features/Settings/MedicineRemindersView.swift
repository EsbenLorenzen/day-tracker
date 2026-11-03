import SwiftUI
import SwiftData
import DayTrackerCore

/// Daily reminder times for one medicine (D11). No times = as-needed only.
struct MedicineRemindersView: View {
    let tracker: Tracker

    @Environment(\.modelContext) private var context
    @State private var newTime = ClockTime(hour: 8, minute: 0).date()

    var body: some View {
        Form {
            Section {
                if tracker.reminderTimes.isEmpty {
                    Text("No reminders – as needed only")
                        .foregroundStyle(.secondary)
                }
                ForEach(tracker.reminderTimes, id: \.self) { time in
                    Text(time.display)
                        .monospacedDigit()
                }
                .onDelete { offsets in
                    let times = tracker.reminderTimes
                    let removed = Set(offsets.map { times[$0].minutesSinceMidnight })
                    tracker.reminderMinutes.removeAll { removed.contains($0) }
                    changed()
                }
            } header: {
                Text("Daily reminders")
            } footer: {
                Text("You can always tap Taken on the Today screen, with or without reminders.")
            }

            Section {
                DatePicker("Time", selection: $newTime, displayedComponents: .hourAndMinute)
                Button("Add reminder", systemImage: "plus") {
                    let minutes = ClockTime(date: newTime).minutesSinceMidnight
                    if !tracker.reminderMinutes.contains(minutes) {
                        tracker.reminderMinutes.append(minutes)
                    }
                    changed()
                }
            }
        }
        .navigationTitle(tracker.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func changed() {
        try? context.save()
        Task { await NotificationScheduler.reschedule() }
    }
}
