import AppKit

// MARK: - Progress Bar View

class ProgressBarView: NSView {
    let progress: CGFloat
    let barColor: NSColor

    init(progress: CGFloat, color: NSColor) {
        self.progress = min(1, max(0, progress))
        self.barColor = color
        super.init(frame: NSRect(x: 0, y: 0, width: 250, height: 16))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let pad: CGFloat = 18
        let barH: CGFloat = 3

        // Percentage label
        let pct = "\(Int(progress * 100))%"
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        let label = NSAttributedString(string: pct, attributes: attrs)
        let labelSize = label.size()
        let labelX = bounds.width - pad - labelSize.width
        let labelY = (bounds.height - labelSize.height) / 2

        // Bar track
        let barW = labelX - pad - 6
        let barY = (bounds.height - barH) / 2
        let trackRect = NSRect(x: pad, y: barY, width: barW, height: barH)

        NSColor.separatorColor.withAlphaComponent(0.15).setFill()
        NSBezierPath(roundedRect: trackRect, xRadius: barH / 2, yRadius: barH / 2).fill()

        // Bar fill
        if progress > 0 {
            let fillRect = NSRect(x: pad, y: barY, width: barW * progress, height: barH)
            barColor.setFill()
            NSBezierPath(roundedRect: fillRect, xRadius: barH / 2, yRadius: barH / 2).fill()
        }

        label.draw(at: NSPoint(x: labelX, y: labelY))
    }
}

// MARK: - Day Timeline View

class DayTimelineView: NSView {
    struct Block {
        let startFrac: CGFloat
        let endFrac: CGFloat
        let isOffPeak: Bool
    }

    let blocks: [Block]
    let nowFrac: CGFloat
    let labels: [(frac: CGFloat, text: String)]

    init(blocks: [Block], nowFrac: CGFloat, labels: [(frac: CGFloat, text: String)]) {
        self.blocks = blocks
        self.nowFrac = min(1, max(0, nowFrac))
        self.labels = labels
        super.init(frame: NSRect(x: 0, y: 0, width: 250, height: 36))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ dirtyRect: NSRect) {
        let pad: CGFloat = 18
        let barH: CGFloat = 8
        let barY: CGFloat = 18
        let barW = bounds.width - pad * 2
        let trackRect = NSRect(x: pad, y: barY, width: barW, height: barH)

        // Colored segments clipped to rounded track
        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(roundedRect: trackRect, xRadius: barH / 2, yRadius: barH / 2).addClip()
        for block in blocks {
            let x = pad + barW * block.startFrac
            let w = barW * (block.endFrac - block.startFrac)
            (block.isOffPeak ? NSColor.systemGreen : NSColor.systemOrange).setFill()
            NSBezierPath(rect: NSRect(x: x, y: barY, width: w, height: barH)).fill()
        }
        NSGraphicsContext.current?.restoreGraphicsState()

        // Current position marker (white circle with shadow)
        let mx = pad + barW * nowFrac
        let mr: CGFloat = 5
        let markerRect = NSRect(x: mx - mr, y: barY + barH / 2 - mr, width: mr * 2, height: mr * 2)
        let shadow = NSShadow()
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowBlurRadius = 3
        shadow.shadowColor = .black.withAlphaComponent(0.5)
        shadow.set()
        NSColor.white.setFill()
        NSBezierPath(ovalIn: markerRect).fill()
        NSShadow().set() // clear shadow

        // Transition time labels
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 9, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]
        for label in labels {
            let str = NSAttributedString(string: label.text, attributes: attrs)
            let sz = str.size()
            let lx = min(max(pad, pad + barW * label.frac - sz.width / 2),
                         bounds.width - pad - sz.width)
            str.draw(at: NSPoint(x: lx, y: 2))
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var timer: Timer?
    var wasOffPeak: Bool?
    var firedAdvanceWarning: Bool = false

    // Peak hours: 5 AM–11 AM PT / 1 PM–7 PM GMT / 8 AM–2 PM ET
    // = UTC 12:00–18:00 on weekdays
    static let peakStartUTC = 12
    static let peakEndUTC = 18

    // MARK: - Core Logic

    /// Returns true when usage is normal (outside peak hours or on weekends).
    func isOffPeak(now: Date = Date()) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let weekday = cal.component(.weekday, from: now)
        let hour = cal.component(.hour, from: now)
        if weekday == 1 || weekday == 7 { return true }
        return hour < Self.peakStartUTC || hour >= Self.peakEndUTC
    }

    /// Returns the next zone transition date and whether it enters off-peak.
    func nextTransition(from now: Date = Date()) -> (date: Date, enteringOffPeak: Bool)? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let offPeak = isOffPeak(now: now)

        if !offPeak {
            // Currently peak → off-peak returns at peakEnd today
            let target = cal.date(bySettingHour: Self.peakEndUTC, minute: 0, second: 0, of: now)!
            return (target, true)
        }

        // Currently off-peak → find next weekday peak start
        let weekday = cal.component(.weekday, from: now)
        let hour = cal.component(.hour, from: now)

        if (2...6).contains(weekday) && hour < Self.peakStartUTC {
            let target = cal.date(bySettingHour: Self.peakStartUTC, minute: 0, second: 0, of: now)!
            return (target, false)
        }

        var next = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: now)!)
        for _ in 0..<7 {
            let wd = cal.component(.weekday, from: next)
            if (2...6).contains(wd) {
                let target = cal.date(bySettingHour: Self.peakStartUTC, minute: 0, second: 0, of: next)!
                return (target, false)
            }
            next = cal.date(byAdding: .day, value: 1, to: next)!
        }
        return nil
    }

    /// When the current zone started.
    func zoneStartDate(from now: Date = Date()) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let offPeak = isOffPeak(now: now)
        let weekday = cal.component(.weekday, from: now)
        let hour = cal.component(.hour, from: now)

        if !offPeak {
            return cal.date(bySettingHour: Self.peakStartUTC, minute: 0, second: 0, of: now)
        }

        if (2...6).contains(weekday) && hour >= Self.peakEndUTC {
            return cal.date(bySettingHour: Self.peakEndUTC, minute: 0, second: 0, of: now)
        }

        var scan = cal.startOfDay(for: now)
        if (2...6).contains(weekday) && hour < Self.peakStartUTC {
            scan = cal.date(byAdding: .day, value: -1, to: scan)!
        }
        for _ in 0..<7 {
            let wd = cal.component(.weekday, from: scan)
            if (2...6).contains(wd) {
                return cal.date(bySettingHour: Self.peakEndUTC, minute: 0, second: 0, of: scan)
            }
            scan = cal.date(byAdding: .day, value: -1, to: scan)!
        }
        return cal.startOfDay(for: now)
    }

    // MARK: - Schedule

    /// Returns today's off-peak/peak time blocks in local timezone.
    func todaySchedule(now: Date = Date()) -> [(start: Date, end: Date, isOffPeak: Bool)] {
        let localCal = Calendar.current
        let dayStart = localCal.startOfDay(for: now)
        let dayEnd = localCal.date(byAdding: .day, value: 1, to: dayStart)!

        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!

        var transitions: [Date] = [dayStart]
        let utcDayOfStart = utcCal.startOfDay(for: dayStart)

        for dayOffset in -1...1 {
            guard let utcDay = utcCal.date(byAdding: .day, value: dayOffset, to: utcDayOfStart) else { continue }
            let wd = utcCal.component(.weekday, from: utcDay)
            guard (2...6).contains(wd) else { continue }

            for hour in [Self.peakStartUTC, Self.peakEndUTC] {
                if let t = utcCal.date(bySettingHour: hour, minute: 0, second: 0, of: utcDay),
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

    /// Returns peak hours formatted in the user's local timezone.
    func peakHoursLocalString() -> String {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        var ref = Date()
        while utcCal.component(.weekday, from: ref) == 1 || utcCal.component(.weekday, from: ref) == 7 {
            ref = utcCal.date(byAdding: .day, value: 1, to: ref)!
        }
        let peakStart = utcCal.date(bySettingHour: Self.peakStartUTC, minute: 0, second: 0, of: ref)!
        let peakEnd = utcCal.date(bySettingHour: Self.peakEndUTC, minute: 0, second: 0, of: ref)!

        let fmt = DateFormatter()
        fmt.timeZone = TimeZone.current
        fmt.dateFormat = "h:mm a"
        return "\(fmt.string(from: peakStart)) \u{2013} \(fmt.string(from: peakEnd))"
    }

    // MARK: - Formatting

    /// Compact countdown: "2h 34m", "45m", "< 1m"
    func formatCountdown(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "< 1m"
    }

    /// For menu bar: shows "until H:MM a" when under 1 hour, otherwise compact countdown.
    func formatMenuBarCountdown(_ seconds: TimeInterval, targetDate: Date) -> String {
        if seconds < 3600 {
            let fmt = DateFormatter()
            fmt.timeZone = TimeZone.current
            fmt.dateFormat = "h:mm a"
            return "until \(fmt.string(from: targetDate))"
        }
        return formatCountdown(seconds)
    }

    // MARK: - App Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        updateStatus()
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }

    func updateStatus() {
        let now = Date()
        let offPeak = isOffPeak(now: now)

        // Update menu bar icon + attributed title
        if let button = statusItem.button {
            let (iconName, iconDesc, tintColor): (String, String, NSColor) = {
                if offPeak { return ("bolt.fill", "Off-peak", .systemGreen) }
                return ("bolt", "Peak hours", .systemOrange)
            }()

            let config = NSImage.SymbolConfiguration(paletteColors: [tintColor])
            button.image = NSImage(systemSymbolName: iconName, accessibilityDescription: iconDesc)?
                .withSymbolConfiguration(config)
            button.imagePosition = .imageLeading

            let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
            let textAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]

            if let next = nextTransition(from: now) {
                let remaining = next.date.timeIntervalSince(now)
                let countdownText = formatMenuBarCountdown(remaining, targetDate: next.date)
                let titleText = offPeak ? " Off-Peak \u{00B7} \(countdownText)" : " Peak \u{00B7} \(countdownText)"
                button.attributedTitle = NSAttributedString(string: titleText, attributes: textAttrs)

                let tipCountdown = formatCountdown(remaining)
                button.toolTip = offPeak
                    ? "Off-peak \u{2013} peak hours in \(tipCountdown)"
                    : "Peak hours \u{2013} off-peak in \(tipCountdown)"
            } else {
                let text = offPeak ? " Off-Peak" : " Peak"
                button.attributedTitle = NSAttributedString(string: text, attributes: textAttrs)
            }
        }

        // Advance warning: 5-minute heads-up before zone transition
        if let next = nextTransition(from: now) {
            let remaining = next.date.timeIntervalSince(now)
            if remaining <= 300 && remaining > 15 && !firedAdvanceWarning {
                let mins = Int(ceil(remaining / 60))
                let title = offPeak ? "Peak Hours Starting Soon" : "Peak Hours Ending Soon"
                let body = offPeak
                    ? "\(mins) min until peak hours. Send important prompts now!"
                    : "\(mins) min until off-peak. Normal rates resume soon."
                showNotification(title: title, body: body)
                firedAdvanceWarning = true
            }
        }

        // Zone transition notifications
        if let was = wasOffPeak, was != offPeak {
            let duration = nextTransition(from: now).map { $0.date.timeIntervalSince(now) }
            sendNotification(offPeak: offPeak, duration: duration)
            firedAdvanceWarning = false
        }

        wasOffPeak = offPeak
        buildMenu(offPeak: offPeak, now: now)
    }

    // MARK: - Notifications

    func sendNotification(offPeak: Bool, duration: TimeInterval?) {
        let title = offPeak ? "Peak Hours Ended" : "Peak Hours Started"
        var body = offPeak
            ? "Normal usage rates are back."
            : "Session limits burn faster now."
        if let d = duration, d > 0 {
            body += " Lasts \(formatCountdown(d))."
        }
        showNotification(title: title, body: body)
    }

    func showNotification(title: String, body: String) {
        let escapedTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
        let escapedBody = body.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "display notification \"\(escapedBody)\" with title \"\(escapedTitle)\" sound name \"Glass\""
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        try? proc.run()
    }

    // MARK: - Menu

    func buildMenu(offPeak: Bool, now: Date) {
        let menu = NSMenu()

        // ── Current Status ──
        let statusText = offPeak ? "Off-Peak" : "Peak Hours"
        let statusColor: NSColor = offPeak ? .systemGreen : .systemOrange
        addStyledItem(statusText, to: menu, color: statusColor, bold: true)

        let statusDetail = offPeak ? "Normal usage rates" : "Session limits burn faster"
        addStyledItem(statusDetail, to: menu, size: 11, color: .secondaryLabelColor)

        if let next = nextTransition(from: now) {
            let remaining = next.date.timeIntervalSince(now)
            let countdown = formatCountdown(remaining)
            let label = next.enteringOffPeak
                ? "Off-peak in \(countdown)"
                : "Peak in \(countdown)"
            addStyledItem(label, to: menu, size: 12)

            // Clickable transition time (copies to clipboard)
            let fmt = DateFormatter()
            fmt.timeZone = TimeZone.current
            fmt.dateFormat = "EEEE 'at' h:mm a"
            let timeStr = fmt.string(from: next.date)

            let timeItem = NSMenuItem(title: "", action: #selector(copyTransitionTime(_:)), keyEquivalent: "")
            timeItem.target = self
            timeItem.representedObject = timeStr
            timeItem.attributedTitle = NSAttributedString(string: "\(timeStr)  \u{2398}", attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ])
            menu.addItem(timeItem)
        }

        // Zone progress bar
        if let zoneStart = zoneStartDate(from: now), let next = nextTransition(from: now) {
            let total = next.date.timeIntervalSince(zoneStart)
            let elapsed = now.timeIntervalSince(zoneStart)
            if total > 0 {
                addProgressBar(
                    progress: CGFloat(elapsed / total),
                    color: offPeak ? .systemGreen : .systemOrange,
                    to: menu
                )
            }
        }

        // ── Open Claude ──
        menu.addItem(NSMenuItem.separator())
        let openItem = NSMenuItem(title: "Open Claude", action: #selector(openClaude), keyEquivalent: "o")
        openItem.keyEquivalentModifierMask = .command
        openItem.target = self
        menu.addItem(openItem)

        // ── Today's Schedule (visual timeline) ──
        menu.addItem(NSMenuItem.separator())

        let schedule = todaySchedule(now: now)
        let timeFmt = DateFormatter()
        timeFmt.timeZone = TimeZone.current
        timeFmt.dateFormat = "h:mm a"

        // Day header with peak hours
        let dayFmt = DateFormatter()
        dayFmt.timeZone = TimeZone.current
        dayFmt.dateFormat = "EEEE"
        let peakBlock = schedule.first(where: { !$0.isOffPeak })
        if let peak = peakBlock {
            let peakRange = "\(timeFmt.string(from: peak.start))\u{2013}\(timeFmt.string(from: peak.end))"
            addStyledItem("\(dayFmt.string(from: now)) \u{2014} peak: \(peakRange)", to: menu, size: 11, color: .secondaryLabelColor)
        } else {
            addStyledItem("\(dayFmt.string(from: now)) \u{2014} off-peak all day", to: menu, size: 11, color: .secondaryLabelColor)
        }

        // Timeline bar
        let localCal = Calendar.current
        let dayStart = localCal.startOfDay(for: now)
        let dayEnd = localCal.date(byAdding: .day, value: 1, to: dayStart)!
        let dayLen = dayEnd.timeIntervalSince(dayStart)

        let tlBlocks = schedule.map {
            DayTimelineView.Block(
                startFrac: CGFloat($0.start.timeIntervalSince(dayStart) / dayLen),
                endFrac: CGFloat($0.end.timeIntervalSince(dayStart) / dayLen),
                isOffPeak: $0.isOffPeak
            )
        }
        var tlLabels: [(frac: CGFloat, text: String)] = []
        for (i, block) in schedule.enumerated() where i > 0 {
            tlLabels.append((
                frac: CGFloat(block.start.timeIntervalSince(dayStart) / dayLen),
                text: timeFmt.string(from: block.start)
            ))
        }
        let timeline = DayTimelineView(
            blocks: tlBlocks,
            nowFrac: CGFloat(now.timeIntervalSince(dayStart) / dayLen),
            labels: tlLabels
        )
        let tlItem = NSMenuItem()
        tlItem.view = timeline
        menu.addItem(tlItem)

        // ── Peak Hours Info ──
        menu.addItem(NSMenuItem.separator())
        addSectionHeader("Peak Hours", to: menu)

        addStyledItem(
            "Peak: \(peakHoursLocalString()) weekdays",
            to: menu, size: 11, color: .secondaryLabelColor
        )

        let etFmt = DateFormatter()
        etFmt.timeZone = TimeZone(identifier: "America/New_York")
        etFmt.dateFormat = "h:mm a"
        addStyledItem("Eastern Time: \(etFmt.string(from: now))", to: menu, size: 11, color: .secondaryLabelColor)

        addStyledItem("Affects 5-hour session limits", to: menu, size: 11, color: .secondaryLabelColor)
        addStyledItem("Weekly limits unchanged", to: menu, size: 11, color: .secondaryLabelColor)

        // ── Footer ──
        menu.addItem(NSMenuItem.separator())
        let about = NSMenuItem(title: "About Claude Peak Monitor", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let quit = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // MARK: - Menu Helpers

    func addSectionHeader(_ title: String, to menu: NSMenu) {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.attributedTitle = NSAttributedString(string: title.uppercased(), attributes: [
            .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
            .foregroundColor: NSColor.tertiaryLabelColor
        ])
        item.isEnabled = false
        menu.addItem(item)
    }

    func addStyledItem(_ title: String, to menu: NSMenu, size: CGFloat = 13,
                       color: NSColor = .labelColor, bold: Bool = false) {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.systemFont(ofSize: size, weight: bold ? .semibold : .regular),
            .foregroundColor: color
        ])
        item.isEnabled = false
        menu.addItem(item)
    }

    func addProgressBar(progress: CGFloat, color: NSColor, to menu: NSMenu) {
        let view = ProgressBarView(progress: progress, color: color)
        let item = NSMenuItem()
        item.view = view
        menu.addItem(item)
    }

    // MARK: - Actions

    @objc func openClaude() {
        // Prefer native app if installed, otherwise open browser
        let claudeAppPath = "/Applications/Claude.app"
        if FileManager.default.fileExists(atPath: claudeAppPath) {
            NSWorkspace.shared.open(URL(fileURLWithPath: claudeAppPath))
        } else {
            NSWorkspace.shared.open(URL(string: "https://claude.ai")!)
        }
    }

    @objc func copyTransitionTime(_ sender: NSMenuItem) {
        if let text = sender.representedObject as? String {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
    }

    @objc func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Claude Peak Monitor"
        alert.informativeText = """
        Tracks Claude\u{2019}s peak hour throttling.

        Peak hours: \(peakHoursLocalString()) weekdays
        Off-peak: All other times + weekends
        Affects: 5-hour session limits (burn faster)
        Weekly limits: Unchanged
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let delegate = AppDelegate()
app.delegate = delegate
app.run()
