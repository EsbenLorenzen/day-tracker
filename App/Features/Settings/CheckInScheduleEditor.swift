import SwiftUI
import SwiftData
import DayTrackerCore

/// Create or edit a check-in: name, time, days and which questions to ask (D13).
struct CheckInScheduleEditor: View {
    let target: ScheduleEditorTarget

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Tracker> { $0.archived == false }, sort: \Tracker.sortOrder)
    private var trackers: [Tracker]

    @State private var name = "Check-in"
    @State private var time = ClockTime(hour: 12, minute: 0).date()
    @State private var days: Weekdays = .everyDay
    @State private var selected: Set<UUID> = []
    @State private var enabled = true
    @State private var didLoad = false

    private var isNew: Bool {
        if case .new = target { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                    DatePicker("Time", selection: $time, displayedComponents: .hourAndMinute)
                    Toggle("Reminder on", isOn: $enabled)
                }

                Section("Days") {
                    WeekdayPicker(days: $days)
                        .padding(.vertical, 4)
                }

                Section {
                    ForEach(trackers) { tracker in
                        Button {
                            if selected.contains(tracker.id) {
                                selected.remove(tracker.id)
                            } else {
                                selected.insert(tracker.id)
                            }
                        } label: {
                            HStack {
                                Label(tracker.name, systemImage: tracker.icon)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selected.contains(tracker.id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Questions")
                } footer: {
                    Text("Asked in the order shown.")
                }

                if case .edit(let schedule) = target {
                    Section {
                        Button("Delete check-in", role: .destructive) {
                            context.delete(schedule)
                            finish()
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "New check-in" : "Edit check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || days.isEmpty)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        switch target {
        case .new:
            selected = Set(trackers.filter { DefaultCheckIns.questionNames.contains($0.name) }.map(\.id))
        case .edit(let schedule):
            name = schedule.name
            time = schedule.time.date()
            days = schedule.days
            selected = Set(schedule.trackerIDs)
            enabled = schedule.enabled
        }
    }

    private func save() {
        let questionIDs = trackers.filter { selected.contains($0.id) }.map(\.id)
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        switch target {
        case .new:
            let schedule = CheckInSchedule(
                name: trimmedName, time: ClockTime(date: time), days: days, trackerIDs: questionIDs)
            schedule.enabled = enabled
            context.insert(schedule)
        case .edit(let schedule):
            schedule.name = trimmedName
            schedule.time = ClockTime(date: time)
            schedule.days = days
            schedule.trackerIDs = questionIDs
            schedule.enabled = enabled
            schedule.updatedAt = .now
        }
        finish()
    }

    private func finish() {
        try? context.save()
        Task { await NotificationScheduler.reschedule() }
        dismiss()
    }
}

/// Seven round day toggles in locale order.
struct WeekdayPicker: View {
    @Binding var days: Weekdays

    var body: some View {
        let calendar = Calendar.current
        HStack(spacing: 6) {
            ForEach(Weekdays.ordered(calendar: calendar), id: \.self) { weekday in
                let isOn = days.contains(calendarWeekday: weekday)
                Button {
                    let day = Weekdays(calendarWeekday: weekday)
                    if isOn { days.remove(day) } else { days.insert(day) }
                } label: {
                    Text(calendar.veryShortWeekdaySymbols[weekday - 1])
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                        .background(isOn ? Color.accentColor : Color(.tertiarySystemFill), in: .circle)
                }
                // Borderless: several buttons in one Form row must not all fire on a row tap.
                .buttonStyle(.borderless)
                .accessibilityLabel(calendar.weekdaySymbols[weekday - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
    }
}
