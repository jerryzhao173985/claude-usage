import UserNotifications
import Foundation

struct NotificationManager {

    // Notification categories
    static let zoneCategory = "ZONE_CHANGE"
    static let warningCategory = "ZONE_WARNING"

    static func requestPermission() {
        let center = UNUserNotificationCenter.current()

        let zoneCategory = UNNotificationCategory(
            identifier: Self.zoneCategory, actions: [], intentIdentifiers: []
        )
        let warningCategory = UNNotificationCategory(
            identifier: Self.warningCategory, actions: [], intentIdentifiers: []
        )

        center.setNotificationCategories([zoneCategory, warningCategory])

        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted { scheduleAll() }
        }
    }

    /// Schedules notifications for all transitions + advance warnings over the next 7 days.
    static func scheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()

        let now = Date()
        var date = now
        let horizon = now.addingTimeInterval(7 * 86400)

        while date < horizon {
            guard let next = Claude2xLogic.nextTransition(from: date) else { break }
            guard next.date < horizon else { break }

            // Zone transition notification
            scheduleTransitionNotification(at: next.date, enteringOffPeak: next.enteringOffPeak)

            // 5-minute advance warning
            let warningDate = next.date.addingTimeInterval(-300)
            if warningDate > now {
                scheduleWarningNotification(at: warningDate, enteringOffPeak: next.enteringOffPeak, transitionDate: next.date)
            }

            date = next.date.addingTimeInterval(1)
        }
    }

    // MARK: - Zone Transition

    private static func scheduleTransitionNotification(at date: Date, enteringOffPeak: Bool) {
        let content = UNMutableNotificationContent()
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"

        if enteringOffPeak {
            content.title = "\u{2705} Peak Hours Ended"
            content.subtitle = "Normal usage rates are back"

            if let nextEnd = Claude2xLogic.nextTransition(from: date.addingTimeInterval(1)) {
                let duration = Claude2xLogic.formatCountdown(nextEnd.date.timeIntervalSince(date))
                content.body = "Off-peak for the next \(duration). Your session limits won\u{2019}t burn as fast."
            } else {
                content.body = "Off-peak hours are active. Normal session limit usage."
            }
        } else {
            content.title = "\u{26A0}\u{FE0F} Peak Hours Started"

            if let nextEnd = Claude2xLogic.nextTransition(from: date.addingTimeInterval(1)) {
                let endTime = timeFmt.string(from: nextEnd.date)
                let duration = Claude2xLogic.formatCountdown(nextEnd.date.timeIntervalSince(date))
                content.subtitle = "Session limits burn faster until \(endTime)"
                content.body = "Usage burns faster for \(duration). Off-peak returns at \(endTime)."
            } else {
                content.subtitle = "Session limits burn faster now"
                content.body = "Your 5-hour session limits will be consumed faster during peak hours."
            }
        }

        content.sound = .default
        content.categoryIdentifier = zoneCategory
        content.interruptionLevel = .timeSensitive

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "transition-\(Int(date.timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Advance Warning

    private static func scheduleWarningNotification(at date: Date, enteringOffPeak: Bool, transitionDate: Date) {
        let content = UNMutableNotificationContent()
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mm a"

        if enteringOffPeak {
            // Peak is ending soon → off-peak coming back
            content.title = "\u{2705} Peak Ends in 5 Minutes"
            content.subtitle = "Off-peak at \(timeFmt.string(from: transitionDate))"
            content.body = "Normal usage rates resume shortly."
        } else {
            // Off-peak ending soon → peak starting
            content.title = "\u{26A0}\u{FE0F} Peak Starts in 5 Minutes"
            content.subtitle = "Peak hours at \(timeFmt.string(from: transitionDate))"
            content.body = "Session limits will burn faster soon. Send important prompts now!"
        }

        content.sound = .default
        content.categoryIdentifier = warningCategory
        content.interruptionLevel = .timeSensitive

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: "warning-\(Int(date.timeIntervalSince1970))",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }
}
