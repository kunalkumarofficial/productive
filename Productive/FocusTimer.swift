import Foundation
import Observation
import AppKit
import UserNotifications

/// Pomodoro-style timer. Remaining time is derived from a fixed end date, so
/// it stays accurate even if UI updates are delayed.
@MainActor
@Observable
final class FocusTimer {
    enum Phase: String {
        case work = "Focus"
        case shortBreak = "Short Break"
        case longBreak = "Long Break"
    }

    private(set) var phase: Phase = .work
    private(set) var isRunning = false
    private(set) var remainingSeconds: Int = 25 * 60
    /// Work sessions finished in the current long-break cycle.
    private(set) var completedInCycle = 0

    /// Called with the number of minutes when a work session completes.
    var onWorkSessionCompleted: ((Int) -> Void)?

    private var endDate: Date?
    private var ticker: Task<Void, Never>?
    private var hasRequestedNotificationPermission = false

    init() {
        remainingSeconds = duration(of: .work)
    }

    // MARK: - Settings

    private func settingsInt(_ key: String, fallback: Int) -> Int {
        let value = UserDefaults.standard.integer(forKey: key)
        return value > 0 ? value : fallback
    }

    var workMinutes: Int { settingsInt(SettingsKeys.workMinutes, fallback: 25) }
    var shortBreakMinutes: Int { settingsInt(SettingsKeys.shortBreakMinutes, fallback: 5) }
    var longBreakMinutes: Int { settingsInt(SettingsKeys.longBreakMinutes, fallback: 15) }
    var sessionsUntilLongBreak: Int { settingsInt(SettingsKeys.sessionsUntilLongBreak, fallback: 4) }

    func duration(of phase: Phase) -> Int {
        switch phase {
        case .work: return workMinutes * 60
        case .shortBreak: return shortBreakMinutes * 60
        case .longBreak: return longBreakMinutes * 60
        }
    }

    // MARK: - Derived display

    var totalSeconds: Int {
        max(duration(of: phase), 1)
    }

    var progress: Double {
        1.0 - Double(remainingSeconds) / Double(totalSeconds)
    }

    var timeString: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var menuTitle: String {
        "\(phase == .work ? "●" : "☕") \(timeString)"
    }

    // MARK: - Controls

    func toggle() {
        if isRunning { pause() } else { start() }
    }

    func start() {
        guard !isRunning else { return }
        if remainingSeconds <= 0 {
            remainingSeconds = duration(of: phase)
        }
        endDate = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        isRunning = true
        startTicker()
        requestNotificationPermissionIfNeeded()
    }

    func pause() {
        guard isRunning else { return }
        tickOnce()
        isRunning = false
        endDate = nil
        stopTicker()
    }

    /// Advances to the next phase without crediting the current one.
    func skip() {
        stopTicker()
        isRunning = false
        endDate = nil
        advancePhase(credit: false)
    }

    func reset() {
        stopTicker()
        isRunning = false
        endDate = nil
        phase = .work
        completedInCycle = 0
        remainingSeconds = duration(of: .work)
    }

    // MARK: - Ticking

    private func startTicker() {
        stopTicker()
        ticker = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                guard let self, !Task.isCancelled else { return }
                self.tickOnce()
            }
        }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private func tickOnce() {
        guard isRunning, let endDate else { return }
        let remaining = Int(endDate.timeIntervalSinceNow.rounded())
        remainingSeconds = max(0, remaining)
        if remainingSeconds <= 0 {
            phaseFinished()
        }
    }

    private func phaseFinished() {
        stopTicker()
        isRunning = false
        endDate = nil

        let finishedPhase = phase
        if finishedPhase == .work {
            completedInCycle += 1
            onWorkSessionCompleted?(workMinutes)
        }
        advancePhase(credit: true)
        notifyPhaseChange(finished: finishedPhase)

        if UserDefaults.standard.bool(forKey: SettingsKeys.autoStartNext) {
            start()
        }
    }

    private func advancePhase(credit: Bool) {
        switch phase {
        case .work:
            let interval = max(sessionsUntilLongBreak, 1)
            if credit && completedInCycle > 0 && completedInCycle % interval == 0 {
                phase = .longBreak
            } else {
                phase = .shortBreak
            }
        case .shortBreak, .longBreak:
            if phase == .longBreak {
                completedInCycle = 0
            }
            phase = .work
        }
        remainingSeconds = duration(of: phase)
    }

    // MARK: - Alerts

    private func notifyPhaseChange(finished: Phase) {
        if UserDefaults.standard.bool(forKey: SettingsKeys.soundEnabled) {
            NSSound(named: "Glass")?.play()
        }
        guard UserDefaults.standard.bool(forKey: SettingsKeys.notificationsEnabled) else { return }

        let content = UNMutableNotificationContent()
        switch finished {
        case .work:
            content.title = "Focus session complete"
            content.body = "Nice work — time for a \(phase == .longBreak ? "long" : "short") break."
        case .shortBreak, .longBreak:
            content.title = "Break over"
            content.body = "Ready for another focus session?"
        }
        content.sound = nil
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func requestNotificationPermissionIfNeeded() {
        guard !hasRequestedNotificationPermission else { return }
        hasRequestedNotificationPermission = true
        guard UserDefaults.standard.bool(forKey: SettingsKeys.notificationsEnabled) else { return }
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
            }
        }
    }
}
