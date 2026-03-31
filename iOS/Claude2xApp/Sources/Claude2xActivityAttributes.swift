import ActivityKit
import Foundation

public struct Claude2xActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var isOffPeak: Bool
        public var nextTransitionDate: Date?
        public var enteringOffPeak: Bool
        public var zoneProgress: Double

        public init(isOffPeak: Bool, nextTransitionDate: Date?, enteringOffPeak: Bool, zoneProgress: Double) {
            self.isOffPeak = isOffPeak
            self.nextTransitionDate = nextTransitionDate
            self.enteringOffPeak = enteringOffPeak
            self.zoneProgress = zoneProgress
        }
    }

    // Static — never changes during the activity's lifetime
    public var peakHoursLocal: String

    public init(peakHoursLocal: String) {
        self.peakHoursLocal = peakHoursLocal
    }
}
