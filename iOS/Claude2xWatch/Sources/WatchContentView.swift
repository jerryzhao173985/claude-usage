import SwiftUI

struct WatchContentView: View {
    @State private var now = Date()
    // Text(date, style: .timer) auto-updates countdown — only need 60s for stats
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private var offPeak: Bool { Claude2xLogic.isOffPeak(now: now) }
    private var transition: (date: Date, enteringOffPeak: Bool)? { Claude2xLogic.nextTransition(from: now) }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                statusView
                countdownView
                scheduleView
                infoView
            }
            .padding(.horizontal, 4)
        }
        .onReceive(timer) { _ in now = Date() }
    }

    // MARK: - Status

    private var statusView: some View {
        VStack(spacing: 2) {
            Text(offPeak ? "Off-Peak" : "Peak")
                .font(.system(size: 36, weight: .black))
                .foregroundStyle(offPeak ? .green : .orange)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(offPeak ? "Normal" : "Burns faster")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Countdown

    private var countdownView: some View {
        Group {
            if let next = transition {
                VStack(spacing: 2) {
                    Text(next.date, style: .timer)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(offPeak ? .green : .orange)

                    Text(next.enteringOffPeak ? "until off-peak" : "until peak")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Schedule

    private var scheduleView: some View {
        let schedule = Claude2xLogic.todaySchedule(now: now)
        let localCal = Calendar.current
        let dayStart = localCal.startOfDay(for: now)
        let dayEnd = localCal.date(byAdding: .day, value: 1, to: dayStart)!
        let dayLen = dayEnd.timeIntervalSince(dayStart)
        let nowFrac = CGFloat(now.timeIntervalSince(dayStart) / dayLen)

        return VStack(spacing: 4) {
            // Timeline bar
            GeometryReader { geo in
                let w = geo.size.width
                let h: CGFloat = 8

                ZStack(alignment: .leading) {
                    Canvas { ctx, size in
                        let clip = Path(roundedRect: CGRect(origin: .zero, size: CGSize(width: size.width, height: h)),
                                        cornerRadius: h / 2)
                        ctx.clip(to: clip)
                        ctx.fill(Path(CGRect(origin: .zero, size: CGSize(width: size.width, height: h))),
                                 with: .color(.gray.opacity(0.2)))
                        for block in schedule {
                            let sf = CGFloat(block.start.timeIntervalSince(dayStart) / dayLen)
                            let ef = CGFloat(block.end.timeIntervalSince(dayStart) / dayLen)
                            ctx.fill(Path(CGRect(x: w * sf, y: 0, width: w * (ef - sf), height: h)),
                                     with: .color(block.isOffPeak ? .green.opacity(0.7) : .orange.opacity(0.7)))
                        }
                    }
                    .frame(height: h)

                    Circle()
                        .fill(.white)
                        .shadow(radius: 2)
                        .frame(width: 10, height: 10)
                        .offset(x: w * nowFrac - 5)
                }
            }
            .frame(height: 12)

            // Peak hours
            if let peak = schedule.first(where: { !$0.isOffPeak }) {
                let fmt: DateFormatter = {
                    let f = DateFormatter(); f.dateFormat = "h:mm a"; return f
                }()
                Text("Peak \(fmt.string(from: peak.start))\u{2013}\(fmt.string(from: peak.end))")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            } else {
                Text("Off-peak all day")
                    .font(.system(size: 9))
                    .foregroundStyle(.green.opacity(0.7))
            }
        }
    }

    // MARK: - Info

    private var infoView: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Status")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(offPeak ? "Normal" : "Burns faster")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(offPeak ? .green : .orange)
            }

            HStack {
                Text("Affects")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("5h session limits")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.top, 4)
    }
}
