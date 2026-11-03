import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var router = AppRouter.shared

    var body: some View {
        TabView {
            Tab("Today", systemImage: "sun.max") {
                TodayView()
            }
            Tab("History", systemImage: "list.bullet") {
                HistoryView()
            }
            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }
        }
        .sheet(item: $router.activeCheckIn) { request in
            CheckInSheet(request: request)
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            // On launch and on return: fill in missed check-ins and keep reminders in sync with settings.
            if phase == .active {
                CheckInStore.reconcile(in: context)
                Task { await NotificationScheduler.reschedule() }
            }
        }
    }
}
