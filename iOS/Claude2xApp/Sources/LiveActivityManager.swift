import ActivityKit
import Foundation

@MainActor
class LiveActivityManager: ObservableObject {
    static let shared = LiveActivityManager()

    @Published var currentActivity: Activity<Claude2xActivityAttributes>?
    @Published var errorMessage: String?
    @Published var isRunning: Bool = false

    private var updateTimer: Timer?

    var activitiesEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Starts the Live Activity — must be called from foreground
    func start() async {
        guard activitiesEnabled else {
            errorMessage = "Live Activities disabled in Settings"
            return
        }

        // End existing activities first
        await endAll()

        let attributes = Claude2xActivityAttributes(
            peakHoursLocal: Claude2xLogic.peakHoursLocalString()
        )
        let state = makeState()
        let staleDate = Claude2xLogic.nextTransition()?.date

        do {
            let activity = try Activity<Claude2xActivityAttributes>.request(
                attributes: attributes,
                content: ActivityContent(
                    state: state,
                    staleDate: staleDate,
                    relevanceScore: state.isOffPeak ? 50 : 100
                ),
                pushType: nil
            )
            currentActivity = activity
            isRunning = true
            errorMessage = nil
            startUpdateTimer()
        } catch {
            errorMessage = error.localizedDescription
            isRunning = false
        }
    }

    /// Updates the Live Activity state
    func updateNow() async {
        if currentActivity == nil {
            currentActivity = Activity<Claude2xActivityAttributes>.activities.first
        }
        guard let activity = currentActivity else {
            isRunning = false
            return
        }

        let state = makeState()
        let staleDate = Claude2xLogic.nextTransition()?.date

        await activity.update(
            ActivityContent(
                state: state,
                staleDate: staleDate,
                relevanceScore: state.isOffPeak ? 50 : 100
            )
        )
        isRunning = true
    }

    /// Ends all Live Activities
    func endAll() async {
        for activity in Activity<Claude2xActivityAttributes>.activities {
            await activity.end(
                ActivityContent(state: makeState(), staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        currentActivity = nil
        isRunning = false
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Restarts the activity (toggle)
    func toggle() async {
        if isRunning {
            await endAll()
        } else {
            await start()
        }
    }

    private func startUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkAndUpdate()
            }
        }
    }

    /// Checks if zone changed and updates only when needed
    private func checkAndUpdate() async {
        guard let activity = currentActivity else {
            isRunning = false
            return
        }
        let currentState = activity.content.state
        let newState = makeState()
        if currentState.isOffPeak != newState.isOffPeak || currentState.enteringOffPeak != newState.enteringOffPeak {
            await activity.update(
                ActivityContent(
                    state: newState,
                    staleDate: Claude2xLogic.nextTransition()?.date,
                    relevanceScore: newState.isOffPeak ? 50 : 100
                )
            )
        }
    }

    private func makeState() -> Claude2xActivityAttributes.ContentState {
        let now = Date()
        let transition = Claude2xLogic.nextTransition(from: now)
        return Claude2xActivityAttributes.ContentState(
            isOffPeak: Claude2xLogic.isOffPeak(now: now),
            nextTransitionDate: transition?.date,
            enteringOffPeak: transition?.enteringOffPeak ?? false,
            zoneProgress: Claude2xLogic.zoneProgress(now: now)
        )
    }
}
