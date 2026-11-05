import SwiftUI
import SwiftData
import DayTrackerCore

/// One counter, rating, number or note tracker: name, appearance, units/range, archiving.
struct TrackerDetailView: View {
    @Bindable var tracker: Tracker

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $tracker.name)
                LabeledContent("Kind", value: tracker.kind.displayName)
            }

            Section("Appearance") {
                AppearancePicker(icon: $tracker.icon, colorName: $tracker.colorName,
                                 icons: TrackerPalette.generalIcons)
            }

            switch tracker.kind {
            case .counter:
                Section {
                    TextField("Unit, e.g. glass", text: optional($tracker.unit))
                    TextField("Plural, e.g. glasses", text: optional($tracker.unitPlural))
                    Stepper(value: $tracker.defaultAmount, in: 0.5...20, step: 0.5) {
                        LabeledContent("Each tap adds", value: ValueFormat.number(tracker.defaultAmount))
                    }
                } header: {
                    Text("Counting")
                } footer: {
                    Text("Shown as \"\(ValueFormat.amount(3, singular: tracker.unit, plural: tracker.unitPlural))\".")
                }
            case .number:
                Section("Unit") {
                    TextField("e.g. kg, steps, hours", text: optional($tracker.unit))
                }
            case .scale:
                Section {
                    Stepper(value: scaleMin, in: 0...9) {
                        LabeledContent("Lowest", value: "\(tracker.scaleRange.lowerBound)")
                    }
                    Stepper(value: scaleMax, in: (tracker.scaleRange.lowerBound + 1)...10) {
                        LabeledContent("Highest", value: "\(tracker.scaleRange.upperBound)")
                    }
                } header: {
                    Text("Range")
                } footer: {
                    Text("Changing the range doesn't change ratings you've already given.")
                }
            case .note, .dose:
                EmptyView()
            }

            Section {
                Button("Archive tracker", role: .destructive) {
                    tracker.archived = true
                    try? context.save()
                    dismiss()
                }
            } footer: {
                Text("Archiving hides it from Today, Trends and check-ins. Its history stays, and you can restore it from the Trackers list.")
            }
        }
        .navigationTitle(tracker.name.isEmpty ? "Tracker" : tracker.name)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            if tracker.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                tracker.name = tracker.kind.displayName
            }
            try? context.save()
            // Check-in notification bodies list tracker names.
            Task { await NotificationScheduler.reschedule() }
        }
    }

    private var scaleMin: Binding<Int> {
        Binding(
            get: { tracker.scaleRange.lowerBound },
            set: { newValue in
                tracker.scaleMin = newValue
                if (tracker.scaleMax ?? 10) <= newValue { tracker.scaleMax = newValue + 1 }
            }
        )
    }

    private var scaleMax: Binding<Int> {
        Binding(
            get: { tracker.scaleRange.upperBound },
            set: { tracker.scaleMax = $0 }
        )
    }

    /// Edits an optional string, storing nil when empty.
    private func optional(_ binding: Binding<String?>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue ?? "" },
            set: {
                let trimmed = $0.trimmingCharacters(in: .whitespaces)
                binding.wrappedValue = trimmed.isEmpty ? nil : $0
            }
        )
    }
}
