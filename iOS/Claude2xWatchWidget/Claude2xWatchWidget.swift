import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct WatchEntry: TimelineEntry {
    let date: Date
    let isOffPeak: Bool
    let nextTransitionDate: Date?
    let enteringOffPeak: Bool
    let zoneProgress: Double
    let relevance: TimelineEntryRelevance?
}

// MARK: - Timeline Provider

struct WatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchEntry {
        makeEntry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchEntry>) -> Void) {
        var entries: [WatchEntry] = []
        var date = Date()
        let horizon = date.addingTimeInterval(86400)

        entries.append(makeEntry(for: date))

        // Pre-compute entries at each transition for Smart Stack updates
        while date < horizon {
            guard let next = Claude2xLogic.nextTransition(from: date) else { break }
            if next.date < horizon {
                entries.append(makeEntry(for: next.date))
                entries.append(makeEntry(for: next.date.addingTimeInterval(1)))
            }
            date = next.date.addingTimeInterval(1)
        }

        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func makeEntry(for date: Date) -> WatchEntry {
        let transition = Claude2xLogic.nextTransition(from: date)
        let isOffPeak = Claude2xLogic.isOffPeak(now: date)

        // Smart Stack relevance: higher score during peak (user needs the warning)
        let score: Float = isOffPeak ? 5.0 : 10.0
        let duration: TimeInterval = transition.map { $0.date.timeIntervalSince(date) } ?? 3600

        return WatchEntry(
            date: date,
            isOffPeak: isOffPeak,
            nextTransitionDate: transition?.date,
            enteringOffPeak: transition?.enteringOffPeak ?? false,
            zoneProgress: Claude2xLogic.zoneProgress(now: date),
            relevance: TimelineEntryRelevance(score: score, duration: duration)
        )
    }
}

// MARK: - Circular Complication (Gauge)

struct WatchCircularView: View {
    var entry: WatchEntry
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        Gauge(value: entry.zoneProgress) {
            Image(systemName: "bolt.fill")
        } currentValueLabel: {
            Text(entry.isOffPeak ? "OK" : "PK")
                .font(.system(size: 14, weight: .black))
                .widgetAccentable()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(entry.isOffPeak ? .green : .orange)
    }
}

// MARK: - Corner Complication (Gauge + Label)

struct WatchCornerView: View {
    var entry: WatchEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Text(entry.isOffPeak ? "OK" : "PK")
                .font(.system(size: 20, weight: .black))
                .widgetAccentable()
        }
        .widgetLabel {
            ProgressView(value: entry.zoneProgress) {
                Text(entry.isOffPeak ? "Off-Peak" : "Peak")
            }
            .tint(entry.isOffPeak ? .green : .orange)
        }
    }
}

// MARK: - Rectangular Complication (Smart Stack card)

struct WatchRectangularView: View {
    var entry: WatchEntry
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: entry.isOffPeak ? "bolt.fill" : "bolt")
                Text(entry.isOffPeak ? "Off-Peak" : "Peak Hours")
                    .fontWeight(.bold)
            }
            .font(.caption)
            .widgetAccentable()

            if let next = entry.nextTransitionDate {
                // Auto-updating countdown
                HStack(spacing: 0) {
                    Text(entry.enteringOffPeak ? "Off-peak in " : "Peak in ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(next, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Zone progress bar
            Gauge(value: entry.zoneProgress) {
                EmptyView()
            }
            .gaugeStyle(.accessoryLinear)
            .tint(entry.isOffPeak ? .green : .orange)
        }
    }
}

// MARK: - Inline Complication

struct WatchInlineView: View {
    var entry: WatchEntry

    var body: some View {
        if let next = entry.nextTransitionDate {
            let zone = entry.isOffPeak ? "OK" : "PK"
            let remaining = Claude2xLogic.formatCountdown(next.timeIntervalSince(entry.date))
            let nextLabel = entry.enteringOffPeak ? "off-peak" : "peak"
            Label("\(zone) \u{00B7} \(nextLabel) in \(remaining)", systemImage: "bolt.fill")
        } else {
            Label("Off-Peak", systemImage: "bolt.fill")
        }
    }
}

// MARK: - Widget Configuration

struct Claude2xWatchComplication: Widget {
    let kind = "Claude2xWatch"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchProvider()) { entry in
            WatchEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Claude Peak Hours")
        .description("Shows whether Claude is in peak or off-peak hours.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline,
            .accessoryCorner
        ])
    }
}

struct WatchEntryView: View {
    var entry: WatchEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            WatchCircularView(entry: entry)
        case .accessoryCorner:
            WatchCornerView(entry: entry)
        case .accessoryRectangular:
            WatchRectangularView(entry: entry)
        case .accessoryInline:
            WatchInlineView(entry: entry)
        default:
            WatchCircularView(entry: entry)
        }
    }
}

// MARK: - Entry Point

@main
struct Claude2xWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        Claude2xWatchComplication()
    }
}
