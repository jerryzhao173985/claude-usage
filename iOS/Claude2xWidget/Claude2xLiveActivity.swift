import ActivityKit
import WidgetKit
import SwiftUI

struct Claude2xLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: Claude2xActivityAttributes.self) { context in
            // ═══════════════════════════════════════
            //  LOCK SCREEN VIEW
            // ═══════════════════════════════════════
            VStack(spacing: 10) {
                // Row 1: Status + Countdown
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Image(systemName: context.state.isOffPeak ? "bolt.fill" : "bolt")
                                .font(.subheadline)
                            Text(context.state.isOffPeak ? "Off-Peak" : "Peak Hours")
                                .font(.headline)
                        }
                        .foregroundStyle(context.state.isOffPeak ? .green : .orange)

                        Text(context.state.isOffPeak
                             ? "Limits drain at normal speed"
                             : "Session limits drain faster")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let next = context.state.nextTransitionDate {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(next, style: .timer)
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold)
                                .monospacedDigit()
                                .foregroundStyle(context.state.isOffPeak ? .green : .orange)
                                .contentTransition(.numericText(countsDown: true))

                            Text(context.state.enteringOffPeak ? "until off-peak" : "until peak")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                // Row 2: Timeline bar with labels
                VStack(spacing: 3) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h: CGFloat = 8
                        let schedule = Claude2xLogic.todaySchedule(now: Date())
                        let localCal = Calendar.current
                        let dayStart = localCal.startOfDay(for: Date())
                        let dayEnd = localCal.date(byAdding: .day, value: 1, to: dayStart)!
                        let dayLen = dayEnd.timeIntervalSince(dayStart)
                        let nowFrac = CGFloat(Date().timeIntervalSince(dayStart) / dayLen)

                        ZStack(alignment: .leading) {
                            Canvas { ctx, size in
                                let clip = Path(roundedRect: CGRect(origin: .zero, size: CGSize(width: size.width, height: h)), cornerRadius: h / 2)
                                ctx.clip(to: clip)
                                ctx.fill(Path(CGRect(origin: .zero, size: CGSize(width: size.width, height: h))), with: .color(.gray.opacity(0.2)))
                                for block in schedule {
                                    let sf = CGFloat(block.start.timeIntervalSince(dayStart) / dayLen)
                                    let ef = CGFloat(block.end.timeIntervalSince(dayStart) / dayLen)
                                    ctx.fill(Path(CGRect(x: w * sf, y: 0, width: w * (ef - sf), height: h)),
                                             with: .color(block.isOffPeak ? .green.opacity(0.7) : .orange.opacity(0.7)))
                                }
                            }
                            .frame(height: h)

                            Circle().fill(.white).shadow(radius: 2)
                                .frame(width: 12, height: 12)
                                .offset(x: w * nowFrac - 6)
                        }
                    }
                    .frame(height: 12)

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
                    liveStatCell(
                        value: Claude2xLogic.formatCountdown(remainingOffPeakToday()),
                        label: "off-peak left",
                        color: .green
                    )
                    Divider().frame(height: 24)
                    liveStatCell(
                        value: context.state.isOffPeak ? "Normal" : "Faster",
                        label: "burn rate",
                        color: context.state.isOffPeak ? .green : .orange
                    )
                    Divider().frame(height: 24)
                    liveStatCell(
                        value: "Peak \(context.attributes.peakHoursLocal)",
                        label: "local hours",
                        color: .secondary
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .activityBackgroundTint(
                context.state.isOffPeak
                    ? Color(red: 0.04, green: 0.10, blue: 0.06)
                    : Color(red: 0.10, green: 0.07, blue: 0.04)
            )
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // ═══════════════════════════════════
                //  EXPANDED VIEW
                // ═══════════════════════════════════
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Image(systemName: context.state.isOffPeak ? "bolt.fill" : "bolt")
                            .font(.title2)
                            .foregroundStyle(context.state.isOffPeak ? .green : .orange)
                        Text(context.state.isOffPeak ? "OK" : "PK")
                            .font(.caption).fontWeight(.black)
                            .foregroundStyle(context.state.isOffPeak ? .green : .orange)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    if let next = context.state.nextTransitionDate {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(next, style: .timer)
                                .font(.system(.title3, design: .monospaced))
                                .fontWeight(.bold).monospacedDigit()
                            Text(context.state.enteringOffPeak ? "until off-peak" : "until peak")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.isOffPeak ? "Normal Usage" : "Usage Burns Faster")
                        .font(.caption).fontWeight(.semibold)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(value: context.state.zoneProgress)
                            .tint(context.state.isOffPeak ? .green : .orange)
                        HStack {
                            Text("Peak: \(context.attributes.peakHoursLocal)")
                                .font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("Weekdays only")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            // ═══════════════════════════════════
            //  COMPACT (pill)
            // ═══════════════════════════════════
            compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: context.state.isOffPeak ? "bolt.fill" : "bolt")
                        .foregroundStyle(context.state.isOffPeak ? .green : .orange)
                    Text(context.state.isOffPeak ? "OK" : "PK")
                        .font(.caption2).fontWeight(.black)
                        .foregroundStyle(context.state.isOffPeak ? .green : .orange)
                }
            } compactTrailing: {
                if let next = context.state.nextTransitionDate {
                    Text(next, style: .timer)
                        .monospacedDigit().font(.caption2).fontWeight(.semibold)
                        .frame(width: 48)
                }
            }
            // ═══════════════════════════════════
            //  MINIMAL
            // ═══════════════════════════════════
            minimal: {
                Image(systemName: context.state.isOffPeak ? "bolt.fill" : "bolt")
                    .foregroundStyle(context.state.isOffPeak ? .green : .orange)
            }
        }
    }

    // Helper: calculate remaining off-peak hours today
    private func remainingOffPeakToday() -> TimeInterval {
        let now = Date()
        let schedule = Claude2xLogic.todaySchedule(now: now)
        return schedule.filter(\.isOffPeak).reduce(0.0) { $0 + max(0, $1.end.timeIntervalSince(max(now, $1.start))) }
    }

    private func liveStatCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 7))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }
}
