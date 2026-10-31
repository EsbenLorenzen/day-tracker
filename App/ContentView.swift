import SwiftUI
import UserNotifications

/// Phase 0 screen: proves the app installs and can deliver a local notification.
struct ContentView: View {
    @State private var status = "Tap the button, then lock your phone or stay here."

    private var buildInfo: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "Version \(version) (build \(build))"
    }

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            VStack(spacing: 4) {
                Text("DayTracker")
                    .font(.largeTitle.bold())
                Text("Phase 0 – toolchain test")
                    .foregroundStyle(.secondary)
            }

            Button("Send test notification in 10 s") {
                Task { await scheduleTestNotification() }
            }
            .buttonStyle(.borderedProminent)

            Text(status)
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            Text(buildInfo)
                .font(.caption2.monospaced())
                .foregroundStyle(.tertiary)
        }
        .padding(32)
    }

    private func scheduleTestNotification() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else {
                status = "Notifications are off. Turn them on in Settings → Apps → DayTracker."
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "DayTracker"
            content.body = "Test notification – it works! 🎉"
            content.sound = .default

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
            let request = UNNotificationRequest(identifier: "phase0-test", content: content, trigger: trigger)
            try await center.add(request)
            status = "Scheduled – it should arrive in about 10 seconds."
        } catch {
            status = "Failed: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
}
