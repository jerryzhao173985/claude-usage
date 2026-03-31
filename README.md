# Claude Peak Monitor

Cross-platform Apple suite tracking Claude's peak hour throttling. During weekday peak hours (5 AM–11 AM PT / 1 PM–7 PM GMT), your 5-hour session limits burn faster. macOS menu bar + iOS app + watchOS app, with Home Screen widgets, Lock Screen widgets, Live Activity, Dynamic Island, and watch complications.

Zero external dependencies. Shared `Claude2xLogic` core across all platforms.

## Peak Hours Schedule

Peak (throttled): **5 AM–11 AM PT** / **1 PM–7 PM GMT** / **8 AM–2 PM ET** weekdays. Everything else is **off-peak** (normal usage).

### Timezone Conversion

| ET (US) | PT (US) | UTC | UK (GMT) | JP (JST) | Status |
|---------|---------|-----|----------|----------|--------|
| 8:00 AM | 5:00 AM | 12:00 | 1:00 PM | 9:00 PM | Peak starts (burns faster) |
| 2:00 PM | 11:00 AM | 18:00 | 7:00 PM | 3:00 AM+1 | Peak ends (normal usage) |

### UK Weekday

| Local Time | Duration | Zone |
|------------|----------|------|
| 12:00 AM – 1:00 PM | 13 hours | **Off-peak** |
| 1:00 PM – 7:00 PM | 6 hours | Peak (throttled) |
| 7:00 PM – 12:00 AM | 5 hours | **Off-peak** |

**18 hours of off-peak per weekday. 24 hours on weekends.**

### Weekend Continuous Block

| Timezone | Continuous Off-Peak Block | Duration |
|----------|--------------------------|----------|
| **UK (BST)** | **Friday 7:00 PM → Monday 1:00 PM** | **66 hours** |
| US Eastern | Friday 2:00 PM → Monday 8:00 AM | 66 hours |
| US Pacific | Friday 11:00 AM → Monday 5:00 AM | 66 hours |

Saturday and Sunday are fully off-peak, midnight to midnight.

### What Changed

- **Before (March 13–28 promotion):** Off-peak hours gave 2x bonus usage
- **Now (permanent):** Peak hours consume 5-hour session limits faster
- **Weekly limits:** Unchanged
- **Affects:** Free, Pro, Max, Team plans

## Platforms

| Platform | What | Install |
|----------|------|---------|
| **macOS** | Menu bar app with countdown, timeline, notifications | `swift build -c release && ./install.sh` |
| **iOS** | SwiftUI app + 5 widget types + Live Activity + Dynamic Island | Open `iOS/` in Xcode via `cd iOS && xcodegen generate` |
| **watchOS** | Standalone watch app + 4 complication types | Built alongside iOS (same Xcode project) |

### macOS Install

```bash
swift build -c release && ./install.sh
```

Requires macOS 13+, Swift 5.9+. Creates `.app` bundle in `/Applications/` with LaunchAgent for auto-start.

### iOS/watchOS Install

```bash
cd iOS
brew install xcodegen  # if not installed
xcodegen generate
open Claude2x.xcodeproj
# Build to device via Xcode (⌘R)
```

Or from CLI:
```bash
cd iOS && make run  # builds, installs on simulator, launches
```

## macOS Menu Bar App

Single-file AppKit app. No `@main` — bootstraps via `NSApplication.shared.run()` with `.accessory` activation policy (no dock icon).

**Menu bar:** Color-coded SF Symbol + monospaced digit countdown. Green bolt for off-peak, orange bolt for peak. Switches from `2h 34m` to `until 6:00 PM` when under 1 hour.

**Dropdown:** Status with countdown, click-to-copy transition time, zone progress bar, day timeline bar (green/orange segments with position marker), peak hours info, Open Claude button, about dialog.

**Notifications:** Zone transitions with duration, 5-minute advance warning. Uses `osascript` to bypass `UNUserNotificationCenter` permissions.

## iOS App

SwiftUI dark-themed app with live countdown, timeline bar, stats, and peak hours info.

**Features:**
- 72pt status text ("Off-Peak"/"Peak") with pulsing glow animation
- `Text(date, style: .timer)` countdown (auto-updates, zero CPU)
- Day timeline bar with Canvas rendering and position marker
- Today's schedule stats (off-peak total, remaining, peak duration)
- Peak hours info card (local peak hours, ET time, affects, weekly limits)
- Live Activity toggle with visible status/errors
- Location card with auto-detect (Core Location) or manual city picker (18 cities)
- Open Claude (detects `Claude.app`, falls back to `claude.ai`)
- Scheduled notifications via `UNCalendarNotificationTrigger` (7 days ahead)

### iOS Widgets (5 types)

| Family | What It Shows |
|--------|--------------|
| **Home Small** | Status + countdown + timeline bar + zone label |
| **Home Medium** | Status + countdown + full timeline bar with labels + stats row |
| **Lock Circular** | Gauge with zone progress, "OK"/"PK" center label |
| **Lock Rectangular** | Status + relative countdown + linear gauge |
| **Lock Inline** | `⚡ OK · peak in 2h 34m` |

### Live Activity + Dynamic Island

**Lock Screen banner:**
```
┌──────────────────────────────────────────────┐
│ ⚡ Peak Hours                  5:33:10       │
│ Session limits burn faster                   │
│ [===●=====|▓▓▓▓▓▓|=========]                │
│ 12 AM   12 PM   6 PM      12 AM             │
│  6h off-peak left │ Faster │ Peak 1–7 PM    │
└──────────────────────────────────────────────┘
```

**Dynamic Island compact:** `⚡ PK | 5:33:10`

**Dynamic Island expanded:** Status + countdown + progress bar + peak hours

**Minimal:** Colored bolt icon

### Location / Timezone

Auto-detects city via Core Location (`kCLLocationAccuracyReduced` for low power). Manual override with 18 popular cities (London, New York, LA, SF, Paris, Beijing, Tokyo, etc.). Selected timezone persisted via `@AppStorage`. All time displays adapt — core logic stays UTC.

## watchOS App

Standalone watch app (`WKWatchOnly = TRUE`). Shows status, countdown, timeline bar, and peak info. Timer at 60s (countdown auto-updates via `Text(date, style: .timer)`).

### Watch Complications (4 types)

| Family | What It Shows |
|--------|--------------|
| **Circular** | Capacity gauge with zone progress, tinted green/orange |
| **Corner** | Status text + curved progress arc via `widgetLabel` |
| **Rectangular** | Status + relative countdown + linear gauge (Smart Stack card) |
| **Inline** | `⚡ OK · peak in 2h 34m` |

`TimelineEntryRelevance` scores peak zones at 10.0 (vs 5.0 for off-peak) for Smart Stack priority — surfaces the warning when it matters most.

## Architecture

### Shared Core: `Claude2xLogic`

Pure struct, no UI framework dependency. Shared across all 4 targets (app, widget extension, watch app, watch widget) via XcodeGen `sources` directive.

```swift
struct Claude2xLogic {
    static let peakStartUTC = 12  // 8 AM ET = 5 AM PT = UTC 12
    static let peakEndUTC = 18    // 2 PM ET = 11 AM PT = UTC 18

    // O(1) — no scanning
    static func isOffPeak(now: Date) -> Bool {
        let weekday = utcCal.component(.weekday, from: now)  // Sun=1..Sat=7
        let hour = utcCal.component(.hour, from: now)
        if weekday == 1 || weekday == 7 { return true }
        return hour < peakStartUTC || hour >= peakEndUTC
    }

    static func nextTransition(from now: Date) -> (date: Date, enteringOffPeak: Bool)? {
        // In peak → returns peakEndUTC today
        // Before peak on weekday → returns peakStartUTC today
        // After peak or weekend → scans forward to next weekday peakStartUTC
    }
}
```

### Widget Timeline Strategy

Pre-computes entries at each transition for the next 24 hours. Since transitions only happen at UTC 12:00/18:00 on weekdays, this produces 2–4 entries per day. `Text(date, style: .timer)` handles per-second countdown rendering natively — zero widget refresh budget consumed for the countdown.

### Live Activity Architecture

```swift
struct Claude2xActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var isOffPeak: Bool
        var nextTransitionDate: Date?
        var enteringOffPeak: Bool
        var zoneProgress: Double
    }
    var peakHoursLocal: String
}
```

`LiveActivityManager` starts on app launch, updates every 5 minutes via smart diff (only pushes when zone state actually changes). `staleDate` set to next transition time. Relevance score is higher during peak (100 vs 50) to surface the activity when the user needs the warning.

### Performance: 3-Tier Refresh

| Layer | Frequency | What |
|-------|-----------|------|
| `Text(date, style: .timer)` | Every 1s | Countdown digits (SwiftUI native, zero CPU) |
| Precision timer | Every 5s | Only within 2 min of transition — ensures instant zone swap |
| Stats refresh | Every 60s | Updates remaining off-peak, timeline position |
| Live Activity | Every 5 min | Smart diff — only pushes on zone change |

Reduced from 60 view rebuilds/min to ~1. Device runs cool.

### Notifications (iOS/watchOS)

```swift
// Pre-schedules 7 days of transitions using exact calendar triggers
UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
```

Two categories:
- **Zone transition**: "✅ Peak Hours Ended" / "⚠️ Peak Hours Started" with duration
- **5-min warning**: "✅ Peak Ends in 5 Minutes" / "⚠️ Peak Starts in 5 Minutes"

All `.timeSensitive` — break through Focus/DND. At most ~28 of the 64-notification iOS budget (14 transitions × 2).

### Key Bug Fixes (Lessons Learned)

| Bug | Root Cause | Fix |
|-----|-----------|-----|
| Dark menu bar invisible text | `NSAttributedString` defaults to black without `.foregroundColor` | Always specify `.labelColor` |
| `attributedTitle` stale state | `NSButton` doesn't clear `attributedTitle` when `title` is set | Always use `attributedTitle` |
| Lock screen "Please adopt" | `containerBackground` applied twice (inner view + entry view) | Apply once per-family in switch |
| Live Activity silent failure | `endAll()` was fire-and-forget, new activity started before old ended | Make `start()` async, `await endAll()` |
| Phone overheating | 1-second timer rebuilt entire view hierarchy 60×/min | 60s timer + native `Text(date, style: .timer)` |
| Leaked timer in SwiftUI body | `Timer.publish(every: 5)` inline in body — recreated per render | Hoist to stored property |
| Duplicate ForEach IDs | 3 cities shared same timezone ID used as `Identifiable.id` | Separate `id` from `tzId` |

## Project Structure

```
├── Sources/Claude2xNotifier/
│   └── main.swift                    # macOS menu bar app
├── Package.swift                      # SPM manifest — macOS 13+
├── install.sh                         # Builds .app bundle + LaunchAgent + codesign
├── generate-icon.swift                # CoreGraphics icon renderer
├── README.md
│
└── iOS/
    ├── project.yml                    # XcodeGen spec (4 targets)
    ├── Makefile                       # make build / make run
    ├── generate-icon.swift            # iOS app icon
    │
    ├── Claude2xApp/                   # iOS app target
    │   ├── Sources/
    │   │   ├── Claude2xApp.swift      # @main + AppDelegate (notification handling)
    │   │   ├── ContentView.swift      # Main UI (status, countdown, timeline, stats)
    │   │   ├── Claude2xLogic.swift    # Shared core (UTC zone detection, O(1) transitions)
    │   │   ├── Claude2xActivityAttributes.swift  # Live Activity data model
    │   │   ├── LiveActivityManager.swift         # Start/update/end Live Activities
    │   │   ├── NotificationManager.swift         # Pre-scheduled UNCalendarNotifications
    │   │   └── LocationManager.swift             # Core Location + manual city picker
    │   ├── Info.plist
    │   └── Assets.xcassets/
    │
    ├── Claude2xWidget/                # iOS widget extension
    │   ├── Claude2xWidget.swift       # 5 widget families + provider
    │   ├── Claude2xLiveActivity.swift # Lock Screen + Dynamic Island views
    │   ├── Info.plist
    │   └── Assets.xcassets/
    │
    ├── Claude2xWatch/                 # watchOS app target
    │   ├── Sources/
    │   │   ├── Claude2xWatchApp.swift
    │   │   └── WatchContentView.swift
    │   ├── Info.plist
    │   └── Assets.xcassets/
    │
    └── Claude2xWatchWidget/           # watchOS widget extension
        ├── Claude2xWatchWidget.swift   # 4 complication families + provider
        ├── Info.plist
        └── Assets.xcassets/
```

## License

MIT
