import SwiftUI
import SwiftData
import UserNotifications

@main
struct DayTrackerApp: App {
    @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate

    init() {
        Seeder.seedIfNeeded(Persistence.container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(Persistence.container)
    }
}

// The delegate methods run on the main actor: iOS calls them on the main thread and requires the
// completion (when the async method returns) on the main thread too, or opening the app from a
// notification aborts in UIKit. @preconcurrency lets main-actor methods satisfy the protocol.
final class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        NotificationScheduler.registerCategories()
        return true
    }

    // Show notifications as banners even while the app is open.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    // Taps and action buttons. May run with the app in the background (Taken / Skip / Snooze).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let content = response.notification.request.content
        guard let payload = NotificationPayload(userInfo: content.userInfo) else { return }
        let action = response.actionIdentifier
        let slot = payload.slot(deliveredAt: response.notification.date)

        if action == NotificationAction.snooze {
            await NotificationScheduler.snooze(content, slot: slot)
            return
        }
        NotificationHandler.handle(action: action, payload: payload, slot: slot)
    }
}
