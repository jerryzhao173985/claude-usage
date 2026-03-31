import SwiftUI
import UserNotifications

@main
struct Claude2xWatchApp: App {
    @Environment(\.scenePhase) var scenePhase

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .onAppear {
                    NotificationManager.requestPermission()
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                NotificationManager.scheduleAll()
            }
        }
    }
}
