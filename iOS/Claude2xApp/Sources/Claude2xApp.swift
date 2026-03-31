import SwiftUI
import UserNotifications

@main
struct Claude2xApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var liveActivityManager = LiveActivityManager.shared
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(liveActivityManager)
                .task {
                    // .task runs once per view lifetime (not on every foreground return)
                    NotificationManager.requestPermission()
                    await liveActivityManager.start()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationManager.scheduleAll()
                UNUserNotificationCenter.current().setBadgeCount(0)
                Task { await liveActivityManager.updateNow() }
            }
        }
    }
}

/// Handles notification actions — tapping "Open Claude" from a notification
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    // Tapping a notification opens the app — no custom action handling needed
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        // Default action: just opens the app (no URL opening)
    }
}
