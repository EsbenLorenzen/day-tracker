import SwiftUI
import SwiftData
import UserNotifications

@main
struct DayTrackerApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Tracker.self, LogEntry.self)
        } catch {
            fatalError("Could not open the database: \(error)")
        }
        Seeder.seedIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show notifications as banners even while the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
