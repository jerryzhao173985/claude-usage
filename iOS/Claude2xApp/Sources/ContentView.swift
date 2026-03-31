import SwiftUI

struct ContentView: View {
    // Refresh every 60s for stats — countdown uses Text(date, style: .timer) which auto-updates
    @State private var now = Date()
    @State private var glowPhase = false
    @State private var showCityPicker = false
    @EnvironmentObject var liveActivity: LiveActivityManager
    @StateObject private var location = LocationManager.shared
    let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    let precisionTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private var offPeak: Bool { Claude2xLogic.isOffPeak(now: now) }
    private var transition: (date: Date, enteringOffPeak: Bool)? { Claude2xLogic.nextTransition(from: now) }
    private var accentColor: Color { offPeak ? .green : .orange }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: offPeak
                    ? [Color(red: 0.03, green: 0.09, blue: 0.06), Color(red: 0.06, green: 0.15, blue: 0.10)]
                    : [Color(red: 0.10, green: 0.06, blue: 0.03), Color(red: 0.15, green: 0.10, blue: 0.06)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.5), value: offPeak)

            ScrollView {
                VStack(spacing: 24) {
                    statusSection
                    countdownSection
                    nextZonePreview
                    timelineSection
                    todayStatsSection
                    peakInfoSection
                    liveActivityToggle
                    locationCard
                    openClaudeButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 40)
            }
        }
        .onReceive(timer) { _ in
            let newNow = Date()
            let wasOffPeak = Claude2xLogic.isOffPeak(now: now)
            let nowOffPeak = Claude2xLogic.isOffPeak(now: newNow)
            now = newNow
            if wasOffPeak != nowOffPeak {
                Task { await liveActivity.updateNow() }
            }
        }
        // Near-transition precision: check every 5s when within 2 min
        .onReceive(precisionTimer) { _ in
            if let next = Claude2xLogic.nextTransition() {
                let remaining = next.date.timeIntervalSince(Date())
                if remaining > 0 && remaining <= 120 {
                    now = Date() // Force refresh near transition
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) { glowPhase = true }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(spacing: 8) {
            Text(offPeak ? "Off-Peak" : "Peak")
                .font(.system(size: 72, weight: .black))
                .foregroundStyle(accentColor)
                .shadow(color: accentColor.opacity(glowPhase ? 0.4 : 0.15), radius: glowPhase ? 30 : 15)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(offPeak ? "Normal usage rates" : "Usage burns faster right now")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("Peak: \(location.peakHoursString()) weekdays")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Countdown

    private var countdownSection: some View {
        Group {
            if let next = transition {
                VStack(spacing: 6) {
                    Text(next.enteringOffPeak ? "PEAK ENDS IN" : "PEAK STARTS IN")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .tracking(2)

                    Text(next.date, style: .timer)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(accentColor)
                        .contentTransition(.numericText())
                }
            }
        }
    }

    // MARK: - Next Zone Preview

    private var nextZonePreview: some View {
        Group {
            if let next = transition {
                HStack(spacing: 4) {
                    Image(systemName: next.enteringOffPeak ? "bolt.fill" : "bolt")
                        .font(.caption2)
                        .foregroundStyle(next.enteringOffPeak ? .green : .orange)
                    Text(next.enteringOffPeak
                         ? "Off-peak resumes at \(location.formatTime(next.date))"
                         : "Peak starts at \(location.formatTime(next.date))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }
        }
    }

    // MARK: - Timeline

    private var timelineSection: some View {
        let schedule = Claude2xLogic.todaySchedule(now: now)
        let localCal = Calendar.current
        let dayStart = localCal.startOfDay(for: now)
        let dayEnd = localCal.date(byAdding: .day, value: 1, to: dayStart)!
        let dayLen = dayEnd.timeIntervalSince(dayStart)
        let nowFrac = CGFloat(now.timeIntervalSince(dayStart) / dayLen)
        let dayFmt: DateFormatter = {
            let f = DateFormatter(); f.dateFormat = "EEEE"; f.timeZone = location.activeTimezone; return f
        }()
        let timeFmt: DateFormatter = {
            let f = DateFormatter(); f.dateFormat = "h:mm a"; f.timeZone = location.activeTimezone; return f
        }()

        return VStack(spacing: 10) {
            HStack {
                Text("TODAY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .tracking(1.5)
                Spacer()
                if let peak = schedule.first(where: { !$0.isOffPeak }) {
                    Text("\(dayFmt.string(from: now)) \u{00B7} peak \(timeFmt.string(from: peak.start))\u{2013}\(timeFmt.string(from: peak.end))")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                } else {
                    Text("\(dayFmt.string(from: now)) \u{00B7} off-peak all day")
                        .font(.system(size: 10))
                        .foregroundStyle(.green.opacity(0.7))
                }
            }

            GeometryReader { geo in
                let w = geo.size.width
                let h: CGFloat = 12
                ZStack(alignment: .leading) {
                    Canvas { ctx, size in
                        let clip = Path(roundedRect: CGRect(origin: .zero, size: CGSize(width: size.width, height: h)), cornerRadius: h / 2)
                        ctx.clip(to: clip)
                        ctx.fill(Path(CGRect(origin: .zero, size: CGSize(width: size.width, height: h))), with: .color(.gray.opacity(0.15)))
                        for block in schedule {
                            let sf = CGFloat(block.start.timeIntervalSince(dayStart) / dayLen)
                            let ef = CGFloat(block.end.timeIntervalSince(dayStart) / dayLen)
                            ctx.fill(Path(CGRect(x: w * sf, y: 0, width: w * (ef - sf), height: h)),
                                     with: .color(block.isOffPeak ? .green.opacity(0.7) : .orange.opacity(0.7)))
                        }
                    }
                    .frame(height: h)
                    Circle().fill(.white).shadow(color: .black.opacity(0.5), radius: 4, y: 1)
                        .frame(width: 16, height: 16).offset(x: w * nowFrac - 8)
                }
            }
            .frame(height: 16)

            GeometryReader { geo in
                let w = geo.size.width
                Text("12 AM").font(.system(size: 8, design: .monospaced)).foregroundStyle(.quaternary)
                    .position(x: 18, y: 6)
                Text("12 AM").font(.system(size: 8, design: .monospaced)).foregroundStyle(.quaternary)
                    .position(x: w - 18, y: 6)
                ForEach(Array(schedule.enumerated().dropFirst()), id: \.offset) { _, block in
                    let frac = CGFloat(block.start.timeIntervalSince(dayStart) / dayLen)
                    Text(timeFmt.string(from: block.start))
                        .font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                        .position(x: w * frac, y: 6)
                }
            }
            .frame(height: 14)

            HStack(spacing: 16) {
                Label("Off-peak", systemImage: "circle.fill").font(.caption2).foregroundStyle(.green)
                Label("Peak", systemImage: "circle.fill").font(.caption2).foregroundStyle(.orange)
                Spacer()
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Today Stats

    private var todayStatsSection: some View {
        let schedule = Claude2xLogic.todaySchedule(now: now)
        let totalOffPeak = schedule.filter(\.isOffPeak).reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        let totalPeak = schedule.filter { !$0.isOffPeak }.reduce(0.0) { $0 + $1.end.timeIntervalSince($1.start) }
        let remainingOffPeak = schedule.filter(\.isOffPeak).reduce(0.0) { $0 + max(0, $1.end.timeIntervalSince(max(now, $1.start))) }
        let totalOffPeakH = Int(totalOffPeak / 3600)
        let totalPeakH = Int(totalPeak / 3600)
        let remH = Int(remainingOffPeak / 3600)
        let remM = Int(remainingOffPeak.truncatingRemainder(dividingBy: 3600) / 60)

        return VStack(spacing: 10) {
            HStack {
                Text("TODAY\u{2019}S SCHEDULE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.tertiary)
                    .tracking(1.5)
                Spacer()
            }
            HStack(spacing: 0) {
                statCard(value: "\(totalOffPeakH)h", label: "Off-peak total", color: .green)
                Divider().frame(height: 36).padding(.horizontal, 8)
                statCard(value: remH > 0 ? "\(remH)h \(remM)m" : "\(remM)m", label: "Off-peak left", color: .green)
                Divider().frame(height: 36).padding(.horizontal, 8)
                statCard(value: "\(totalPeakH)h", label: "Peak hours", color: .orange)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold, design: .monospaced)).foregroundStyle(color)
            Text(label).font(.system(size: 9)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Peak Info

    private var peakInfoSection: some View {
        let etFmt: DateFormatter = {
            let f = DateFormatter()
            f.timeZone = TimeZone(identifier: "America/New_York")
            f.dateFormat = "h:mm a"
            return f
        }()

        return VStack(spacing: 10) {
            HStack {
                Text("PEAK HOURS INFO")
                    .font(.system(size: 10, weight: .bold)).foregroundStyle(.tertiary).tracking(1.5)
                Spacer()
            }

            infoRow("Peak hours", location.peakHoursString() + " weekdays")
            infoRow("Eastern Time", etFmt.string(from: now))
            infoRow("Weekends", "Off-peak all day")
            infoRow("Affects", "5-hour session limits")
            infoRow("Weekly limits", "Unchanged")
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.caption).foregroundStyle(.primary)
        }
    }

    // MARK: - Live Activity Toggle

    private var liveActivityToggle: some View {
        Button {
            Task { await liveActivity.toggle() }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: liveActivity.isRunning ? "livephoto" : "livephoto.slash")
                    .font(.body)
                    .foregroundStyle(liveActivity.isRunning ? .green : .secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(liveActivity.isRunning ? "Live Activity Running" : "Live Activity Off")
                        .font(.caption)
                        .foregroundStyle(.primary)
                    if let err = liveActivity.errorMessage {
                        Text(err).font(.caption2).foregroundStyle(.red)
                    } else {
                        Text(liveActivity.isRunning ? "Lock Screen & Dynamic Island" : "Tap to start")
                            .font(.caption2).foregroundStyle(.tertiary)
                    }
                }
                Spacer()
                Image(systemName: liveActivity.isRunning ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(liveActivity.isRunning ? .green : .secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Location Card

    private var locationCard: some View {
        let tz = location.activeTimezone
        let utcOffset = tz.secondsFromGMT() / 3600
        let utcMin = abs(tz.secondsFromGMT() % 3600) / 60
        let offsetStr = utcMin > 0
            ? "UTC\(utcOffset >= 0 ? "+" : "")\(utcOffset):\(String(format: "%02d", utcMin))"
            : "UTC\(utcOffset >= 0 ? "+" : "")\(utcOffset)"
        let tzAbbr = tz.abbreviation() ?? ""

        return Button { showCityPicker = true } label: {
            HStack(spacing: 10) {
                Image(systemName: location.isAutoDetect ? "location.fill" : "mappin.circle.fill")
                    .font(.body)
                    .foregroundStyle(location.isAutoDetect ? .cyan : .purple)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(location.displayCityName)
                            .font(.caption).fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text("\(tzAbbr) \u{00B7} \(offsetStr)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text("Peak \(location.peakHoursString())")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCityPicker) {
            cityPickerSheet
        }
        .onAppear { location.requestLocation() }
    }

    // MARK: - City Picker Sheet

    private var cityPickerSheet: some View {
        NavigationStack {
            List {
                // Auto-detect option
                Section {
                    Button {
                        location.resetToAutoDetect()
                        showCityPicker = false
                    } label: {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.cyan)
                            VStack(alignment: .leading) {
                                Text("Auto-Detect")
                                    .foregroundStyle(.primary)
                                Text(location.detectedCity.isEmpty
                                     ? "Uses device timezone"
                                     : "Detected: \(location.detectedCity)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if location.isAutoDetect {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }

                // Popular cities
                Section("Popular Cities") {
                    ForEach(CityOption.popular) { city in
                        Button {
                            location.selectCity(city)
                            showCityPicker = false
                        } label: {
                            let tz = TimeZone(identifier: city.tzId) ?? .current
                            let offset = tz.secondsFromGMT() / 3600
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(city.label)
                                        .foregroundStyle(.primary)
                                    Text("UTC\(offset >= 0 ? "+" : "")\(offset)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if location.selectedCityName == city.label {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showCityPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Open Claude

    private var openClaudeButton: some View {
        Link(destination: URL(string: "claude://")!) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                Text("Open Claude")
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(accentColor.opacity(0.2))
            .foregroundStyle(accentColor)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(accentColor.opacity(0.2), lineWidth: 1))
        }
    }

}
