import SwiftUI
import SwiftData
import DayTrackerCore

/// Steps through a check-in's questions, one tap each.
struct CheckInSheet: View {
    let request: CheckInRequest

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var schedules: [CheckInSchedule]
    @Query(filter: #Predicate<Tracker> { $0.archived == false }) private var trackers: [Tracker]

    @State private var session: CheckInSession?
    @State private var index = 0
    @State private var draftValue: Double = 1
    @State private var draftNote = ""

    private var schedule: CheckInSchedule? {
        schedules.first { $0.id == request.scheduleID }
    }

    private var questions: [Tracker] {
        guard let schedule else { return [] }
        return schedule.trackerIDs.compactMap { id in trackers.first { $0.id == id } }
    }

    var body: some View {
        let questions = questions
        NavigationStack {
            VStack(spacing: 24) {
                if index < questions.count {
                    question(questions[index], number: index + 1, of: questions.count)
                        .id(index)
                        .transition(.push(from: .trailing))
                } else {
                    done(hasQuestions: !questions.isEmpty)
                }
            }
            .padding()
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle(schedule?.name ?? "Check-in")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            if session == nil, schedule != nil {
                session = CheckInStore.open(request, questionCount: questions.count, in: context)
            }
        }
        .onDisappear { try? context.save() }
    }

    @ViewBuilder
    private func question(_ tracker: Tracker, number: Int, of total: Int) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 6) {
                Text("Question \(number) of \(total) · \(request.scheduledFor.shortTime)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Label(tracker.name, systemImage: tracker.icon)
                    .font(.title2.bold())
                    .foregroundStyle(tracker.color)
            }

            switch tracker.kind {
            case .scale:
                ScaleGrid(range: tracker.scaleRange, selection: nil, color: tracker.color) {
                    answer(tracker, value: Double($0))
                }
            case .dose:
                HStack(spacing: 12) {
                    Button("Skipped") { answer(tracker, value: 0) }
                        .buttonStyle(.bordered)
                    Button("Taken") { answer(tracker, value: 1) }
                        .buttonStyle(.borderedProminent)
                        .tint(tracker.color)
                }
                .controlSize(.large)
            case .counter, .number:
                Stepper(value: $draftValue, in: 0...50, step: tracker.defaultAmount) {
                    Text(tracker.format(draftValue))
                        .font(.title3)
                }
                Button("Next") { answer(tracker, value: draftValue) }
                    .buttonStyle(.borderedProminent)
            case .note:
                TextField("Write a note", text: $draftNote, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                Button("Next") { answer(tracker, value: 0, note: draftNote) }
                    .buttonStyle(.borderedProminent)
            }

            HStack {
                Button("Skip question") { advance() }
                Spacer()
                Button("Skip check-in", role: .destructive) { skipAll() }
            }
            .font(.subheadline)
        }
    }

    private func done(hasQuestions: Bool) -> some View {
        VStack(spacing: 16) {
            Image(systemName: hasQuestions ? "checkmark.circle.fill" : "questionmark.circle")
                .font(.system(size: 56))
                .foregroundStyle(hasQuestions ? Color.green : Color.secondary)
            Text(hasQuestions ? "All done" : "This check-in has no questions")
                .font(.title3.bold())
            if !hasQuestions {
                Text("Choose questions in Settings → Check-ins.")
                    .foregroundStyle(.secondary)
            }
            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.top, 24)
    }

    private func answer(_ tracker: Tracker, value: Double, note: String? = nil) {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let entry = EntryLogger.log(
            tracker, value: value, source: .checkIn,
            note: (trimmed?.isEmpty ?? true) ? nil : trimmed, in: context)
        entry.sessionID = session?.id
        if let session { CheckInStore.recordAnswer(session) }
        advance()
    }

    private func advance() {
        withAnimation { index += 1 }
        draftValue = 1
        draftNote = ""
        try? context.save()
    }

    private func skipAll() {
        if let session { CheckInStore.skip(session) }
        try? context.save()
        dismiss()
    }
}
