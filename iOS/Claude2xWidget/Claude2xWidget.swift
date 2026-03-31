import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct Claude2xEntry: TimelineEntry {
    let date: Date
    let isOffPeak: Bool
    let nextTransitionDate: Date?
    let enteringOffPeak: Bool
    let zoneProgress: Double
    let schedule: [(start: Date, end: Date, isOffPeak: Bool)]
    let relevance: TimelineEntryRelevance?
}

// MARK: - Timeline Provider

struct Claude2xProvider: TimelineProvider {
    func placeholder(in context: Context) -> Claude2xEntry {
        makeEntry(for: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (Claude2xEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Claude2xEntry>) -> Void) {
        var entries: [Claude2xEntry] = []
        var date = Date()
        let horizon = date.addingTimeInterval(86400)

        entries.append(makeEntry(for: date))

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

    private func makeEntry(for date: Date) -> Claude2xEntry {
        let transition = Claude2xLogic.nextTransition(from: date)
        let isOffPeak = Claude2xLogic.isOffPeak(now: date)
        // Higher relevance during peak (user needs the warning)
        let score: Float = isOffPeak ? 5.0 : 10.0
        let duration: TimeInterval = transition.map { $0.date.timeIntervalSince(date) } ?? 3600

        return Claude2xEntry(
            date: date,
            isOffPeak: isOffPeak,
            nextTransitionDate: transition?.date,
            enteringOffPeak: transition?.enteringOffPeak ?? false,
            zoneProgress: Claude2xLogic.zoneProgress(now: date),
            schedule: Claude2xLogic.todaySchedule(now: date),
            relevance: TimelineEntryRelevance(score: score, duration: duration)
        )
    }
}

// MARK: - Home Screen Small Widget

struct SmallWidgetView: View {
    var entry: Claude2xEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: entry.isOffPeak ? "bolt.fill" : "bolt")
                    .foregroundStyle(entry.isOffPeak ? .green : .orange)
                Text(entry.isOffPeak ? "Off-Peak" : "Peak")
                    .font(.caption2).fontWeight(.bold)
                    .foregroundStyle(entry.isOffPeak ? .green : .orange)
                Spacer()
            }

            Spacer(minLength: 4)

            // Status
            Text(entry.isOffPeak ? "OK" : "PK")
                .font(.system(size: 34, weight: .black))
                .foregroundStyle(entry.isOffPeak ? .green : .orange)

            // Countdown
            if let next = entry.nextTransitionDate {
                Text(next, style: .timer)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 4)

            // Timeline bar
            widgetTimeline
                .padding(.bottom, 2)

            // Footer
            HStack {
                Text(entry.isOffPeak ? "Off-peak" : "Peak")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(entry.isOffPeak ? .green : .orange)
                Spacer()
                Text(entry.isOffPeak ? "normal rates" : "burns faster")
                    .font(.system(size: 8)).foregroundStyle(.tertiary)
            }
        }
    }

    private var widgetTimeline: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 6
            let localCal = Calendar.current
            let dayStart = localCal.startOfDay(for: entry.date)
            let dayEnd = localCal.date(byAdding: .day, value: 1, to: dayStart)!
            let dayLen = dayEnd.timeIntervalSince(dayStart)
            let nowFrac = CGFloat(entry.date.timeIntervalSince(dayStart) / dayLen)

            ZStack(alignment: .leading) {
                Canvas { ctx, size in
                    let clip = Path(roundedRect: CGRect(origin: .zero, size: CGSize(width: size.width, height: h)), cornerRadius: h / 2)
                    ctx.clip(to: clip)
                    ctx.fill(Path(CGRect(origin: .zero, size: CGSize(width: size.width, height: h))), with: .color(.gray.opacity(0.2)))
                    for block in entry.schedule {
                        let sf = CGFloat(block.start.timeIntervalSince(dayStart) / dayLen)
                        let ef = CGFloat(block.end.timeIntervalSince(dayStart) / dayLen)
                        ctx.fill(Path(CGRect(x: w * sf, y: 0, width: w * (ef - sf), height: h)),
                                 with: .color(block.isOffPeak ? .green.opacity(0.7) : .orange.opacity(0.7)))
                    }
                }
                .frame(height: h)
                Circle().fill(.white).shadow(radius: 1.5)
                    .frame(width: 8, height: 8).offset(x: w * nowFrac - 4)
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Home Screen Medium Widget

struct MediumWidgetView: View {
    var entry: Claude2xEntry

    var body: some View {
        VStack(spacing: 8) {
            // Row 1: Status + Countdown
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: entry.isOffPeak ? "bolt.fill" : "bolt")
                            .foregroundStyle(entry.isOffPeak ? .green : .orange)
                        Text(entry.isOffPeak ? "Off-Peak" : "Peak Hours")
                            .font(.caption).fontWeight(.semibold)
                            .foregroundStyle(entry.isOffPeak ? .green : .orange)
                    }
                    Text(entry.isOffPeak ? "Normal usage rates" : "Usage burns faster")
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    if let next = entry.nextTransitionDate {
                        Text(next, style: .timer)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(entry.isOffPeak ? .green : .orange)
                            .monospacedDigit()
                    }
                    Text(entry.enteringOffPeak ? "until off-peak" : "until peak")
                        .font(.system(size: 9)).foregroundStyle(.tertiary)
                }
            }

            // Row 2: Timeline bar
            VStack(spacing: 2) {
                mediumTimeline
                HStack {
                    Text("12 AM").font(.system(size: 7, design: .monospaced)).foregroundStyle(.quaternary)
                    Spacer()
                    Text("12 PM").font(.system(size: 7, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    Text("6 PM").font(.system(size: 7, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                    Spacer()
                    Text("12 AM").font(.system(size: 7, design: .monospaced)).foregroundStyle(.quaternary)
                }
            }

            // Row 3: Stats
            HStack(spacing: 0) {
                widgetStat(value: remainingOffPeakStr(), label: "off-peak left", color: .green)
                Divider().frame(height: 20)
                widgetStat(value: "Weekdays", label: "peak only", color: .blue)
                Divider().frame(height: 20)
                widgetStat(value: "Peak", label: Claude2xLogic.peakHoursLocalString(), color: .orange)
            }
        }
    }

    private func remainingOffPeakStr() -> String {
        let remaining = entry.schedule.filter(\.isOffPeak).reduce(0.0) {
            $0 + max(0, $1.end.timeIntervalSince(max(entry.date, $1.start)))
        }
        return Claude2xLogic.formatCountdown(remaining)
    }

    private func widgetStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.system(size: 7)).foregroundStyle(.tertiary)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var mediumTimeline: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h: CGFloat = 8
            let localCal = Calendar.current
            let dayStart = localCal.startOfDay(for: entry.date)
            let dayEnd = localCal.date(byAdding: .day, value: 1, to: dayStart)!
            let dayLen = dayEnd.timeIntervalSince(dayStart)
            let nowFrac = CGFloat(entry.date.timeIntervalSince(dayStart) / dayLen)

            ZStack(alignment: .leading) {
                Canvas { ctx, size in
                    let clip = Path(roundedRect: CGRect(origin: .zero, size: CGSize(width: size.width, height: h)), cornerRadius: h / 2)
                    ctx.clip(to: clip)
                    ctx.fill(Path(CGRect(origin: .zero, size: CGSize(width: size.width, height: h))), with: .color(.gray.opacity(0.15)))
                    for block in entry.schedule {
                        let sf = CGFloat(block.start.timeIntervalSince(dayStart) / dayLen)
                        let ef = CGFloat(block.end.timeIntervalSince(dayStart) / dayLen)
                        ctx.fill(Path(CGRect(x: w * sf, y: 0, width: w * (ef - sf), height: h)),
                                 with: .color(block.isOffPeak ? .green.opacity(0.7) : .orange.opacity(0.7)))
                    }
                }
                .frame(height: h)
                Circle().fill(.white).shadow(radius: 2)
                    .frame(width: 12, height: 12).offset(x: w * nowFrac - 6)
            }
        }
        .frame(height: 12)
    }
}

// MARK: - Lock Screen Circular

struct CircularWidgetView: View {
    var entry: Claude2xEntry

    var body: some View {
        Gauge(value: entry.zoneProgress) {
            Image(systemName: "bolt.fill")
        } currentValueLabel: {
            Text(entry.isOffPeak ? "OK" : "PK")
                .font(.system(.body, weight: .bold))
                .widgetAccentable()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(entry.isOffPeak ? .green : .orange)
    }
}

// MARK: - Lock Screen Rectangular

struct RectangularWidgetView: View {
    var entry: Claude2xEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: entry.isOffPeak ? "bolt.fill" : "bolt")
                Text(entry.isOffPeak ? "Off-Peak" : "Peak Hours").fontWeight(.semibold)
            }
            .font(.caption).widgetAccentable()

            if let next = entry.nextTransitionDate {
                HStack(spacing: 0) {
                    Text(entry.enteringOffPeak ? "Off-peak in " : "Peak in ")
                    Text(next, style: .relative)
                }
                .font(.caption2).foregroundStyle(.secondary)
            }

            Gauge(value: entry.zoneProgress) { EmptyView() }
                .gaugeStyle(.accessoryLinear)
                .tint(entry.isOffPeak ? .green : .orange)
        }
    }
}

// MARK: - Lock Screen Inline

struct InlineWidgetView: View {
    var entry: Claude2xEntry

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

// MARK: - Entry View — containerBackground per family

struct Claude2xWidgetEntryView: View {
    var entry: Claude2xEntry
    @Environment(\.widgetFamily) var family

    private var homeBackground: Color {
        entry.isOffPeak ? Color(red: 0.06, green: 0.14, blue: 0.08) : Color(red: 0.14, green: 0.10, blue: 0.04)
    }

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(entry: entry)
                .containerBackground(for: .widget) { homeBackground }
        case .systemMedium:
            MediumWidgetView(entry: entry)
                .containerBackground(for: .widget) { homeBackground }
        case .accessoryCircular:
            CircularWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        case .accessoryRectangular:
            RectangularWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        case .accessoryInline:
            InlineWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        default:
            SmallWidgetView(entry: entry)
                .containerBackground(for: .widget) { homeBackground }
        }
    }
}

// MARK: - Widget Configuration

struct Claude2xWidget: Widget {
    let kind = "Claude2xWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Claude2xProvider()) { entry in
            Claude2xWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Claude Peak Hours")
        .description("Shows whether Claude is in peak or off-peak hours.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
    }
}

@main
struct Claude2xWidgetBundle: WidgetBundle {
    var body: some Widget {
        Claude2xWidget()
        Claude2xLiveActivity()
    }
}
