import SwiftUI
import SwiftData
import DayTrackerCore

/// One medicine: name, appearance, daily reminder times (D11) and archiving.
struct MedicineDetailView: View {
    @Bindable var tracker: Tracker

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var newTime = ClockTime(hour: 8, minute: 0).date()

    var body: some View {
        Form {
            Section("Name") {
                TextField("Name", text: $tracker.name)
            }

            Section("Appearance") {
                AppearancePicker(icon: $tracker.icon, colorName: $tracker.colorName)
            }

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
                DatePicker("New time", selection: $newTime, displayedComponents: .hourAndMinute)
                Button("Add reminder", systemImage: "plus") {
                    let minutes = ClockTime(date: newTime).minutesSinceMidnight
                    if !tracker.reminderMinutes.contains(minutes) {
                        tracker.reminderMinutes.append(minutes)
                    }
                    changed()
                }
            } header: {
                Text("Daily reminders")
            } footer: {
                Text("Reminders have Taken, Skip and Snooze buttons on the notification. You can always tap Taken on the Today screen, with or without reminders.")
            }

            Section {
                Button("Archive medicine", role: .destructive) {
                    tracker.archived = true
                    changed()
                    dismiss()
                }
            } footer: {
                Text("Archiving hides it from Today and stops its reminders. Its history stays, and you can restore it from the Medicines list.")
            }
        }
        .navigationTitle(tracker.name.isEmpty ? "Medicine" : tracker.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            // Name and appearance are edited live; save them and refresh notification titles.
            if tracker.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                tracker.name = "Medicine"
            }
            changed()
        }
    }

    private func changed() {
        try? context.save()
        Task { await NotificationScheduler.reschedule() }
    }
}
