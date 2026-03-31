import Foundation

struct Claude2xLogic {
    // Peak hours: 5 AM–11 AM PT / 1 PM–7 PM GMT / 8 AM–2 PM ET
    // = UTC 12:00–18:00 on weekdays
    static let peakStartUTC = 12
    static let peakEndUTC = 18

    private static let utcCal: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    /// Returns true when usage is normal (outside peak hours or on weekends).
    static func isOffPeak(now: Date = Date()) -> Bool {
        let cal = utcCal
        let weekday = cal.component(.weekday, from: now)
        let hour = cal.component(.hour, from: now)
        // Weekends are always off-peak
        if weekday == 1 || weekday == 7 { return true }
        return hour < peakStartUTC || hour >= peakEndUTC
    }

    /// Returns the next transition date and whether it enters off-peak.
    static func nextTransition(from now: Date = Date()) -> (date: Date, enteringOffPeak: Bool)? {
        let cal = utcCal
        let offPeak = isOffPeak(now: now)

        if !offPeak {
            // Currently peak → off-peak returns at peakEnd today
            let target = cal.date(bySettingHour: peakEndUTC, minute: 0, second: 0, of: now)!
            return (target, true)
        }

        // Currently off-peak → find next weekday peak start
        let weekday = cal.component(.weekday, from: now)
        let hour = cal.component(.hour, from: now)

        if (2...6).contains(weekday) && hour < peakStartUTC {
            let target = cal.date(bySettingHour: peakStartUTC, minute: 0, second: 0, of: now)!
            return (target, false)
        }

        var next = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
        for _ in 0..<7 {
            let wd = cal.component(.weekday, from: next)
            if (2...6).contains(wd) {
                let target = cal.date(bySettingHour: peakStartUTC, minute: 0, second: 0, of: next)!
                return (target, false)
            }
            next = cal.date(byAdding: .day, value: 1, to: next)!
        }
        return nil
    }

    /// When the current zone (off-peak or peak) started.
    static func zoneStartDate(from now: Date = Date()) -> Date? {
        let cal = utcCal
        let offPeak = isOffPeak(now: now)
        let weekday = cal.component(.weekday, from: now)
        let hour = cal.component(.hour, from: now)

        if !offPeak {
            // Peak started at peakStartUTC today
            return cal.date(bySettingHour: peakStartUTC, minute: 0, second: 0, of: now)
        }
        if (2...6).contains(weekday) && hour >= peakEndUTC {
            // Off-peak started at peakEndUTC today
            return cal.date(bySettingHour: peakEndUTC, minute: 0, second: 0, of: now)
        }

        // Weekday before peak or weekend → find last weekday's peakEndUTC
        var scan = cal.startOfDay(for: now)
        if (2...6).contains(weekday) && hour < peakStartUTC {
            scan = cal.date(byAdding: .day, value: -1, to: scan)!
        }
        for _ in 0..<7 {
            let wd = cal.component(.weekday, from: scan)
            if (2...6).contains(wd) {
                return cal.date(bySettingHour: peakEndUTC, minute: 0, second: 0, of: scan)
            }
            scan = cal.date(byAdding: .day, value: -1, to: scan)!
        }
        return cal.startOfDay(for: now)
    }

    /// Progress through current zone (0.0 → 1.0).
    static func zoneProgress(now: Date = Date()) -> Double {
        guard let start = zoneStartDate(from: now),
              let next = nextTransition(from: now) else { return 0 }
        let total = next.date.timeIntervalSince(start)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(start) / total))
    }

    /// Today's off-peak/peak time blocks in local timezone.
    static func todaySchedule(now: Date = Date()) -> [(start: Date, end: Date, isOffPeak: Bool)] {
        let localCal = Calendar.current
        let dayStart = localCal.startOfDay(for: now)
        let dayEnd = localCal.date(byAdding: .day, value: 1, to: dayStart)!
        let cal = utcCal

        var transitions: [Date] = [dayStart]
        let utcDayOfStart = cal.startOfDay(for: dayStart)

        for dayOffset in -1...1 {
            guard let utcDay = cal.date(byAdding: .day, value: dayOffset, to: utcDayOfStart) else { continue }
            let wd = cal.component(.weekday, from: utcDay)
            guard (2...6).contains(wd) else { continue }
            for hour in [peakStartUTC, peakEndUTC] {
                if let t = cal.date(bySettingHour: hour, minute: 0, second: 0, of: utcDay),
                   t > dayStart, t < dayEnd {
                    transitions.append(t)
                }
            }
        }

        transitions.sort()

        var blocks: [(start: Date, end: Date, isOffPeak: Bool)] = []
        for (i, t) in transitions.enumerated() {
            if t >= dayEnd { break }
            let end = i + 1 < transitions.count ? min(transitions[i + 1], dayEnd) : dayEnd
            let status = isOffPeak(now: t.addingTimeInterval(1))
            if let last = blocks.last, last.isOffPeak == status {
                blocks[blocks.count - 1] = (last.start, end, status)
            } else {
                blocks.append((t, end, status))
            }
        }
        return blocks
    }

    /// Peak hours formatted in the given timezone.
    static func peakHoursLocalString(in tz: TimeZone = .current) -> String {
        let cal = utcCal
        var ref = Date()
        while cal.component(.weekday, from: ref) == 1 || cal.component(.weekday, from: ref) == 7 {
            ref = cal.date(byAdding: .day, value: 1, to: ref)!
        }
        let peakStart = cal.date(bySettingHour: peakStartUTC, minute: 0, second: 0, of: ref)!
        let peakEnd = cal.date(bySettingHour: peakEndUTC, minute: 0, second: 0, of: ref)!
        let fmt = DateFormatter()
        fmt.timeZone = tz
        fmt.dateFormat = "h:mm a"
        return "\(fmt.string(from: peakStart)) \u{2013} \(fmt.string(from: peakEnd))"
    }

    /// Compact countdown: "2h 34m", "45m", "< 1m"
    static func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "< 1m"
    }
}
