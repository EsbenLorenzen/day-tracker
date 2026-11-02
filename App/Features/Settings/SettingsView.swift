import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var notificationStatus: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button("Send test notification in 10 s") {
                        Task { notificationStatus = await NotificationTester.scheduleTest() }
                    }
                    if let notificationStatus {
                        Text(notificationStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Check-in reminders arrive in Phase 2. This verifies notifications work on your phone.")
                }

                Section("About") {
                    LabeledContent("Version", value: AppConfig.version)
                }
            }
            .navigationTitle("Settings")
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
