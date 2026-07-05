import Foundation
import os

/// Lightweight structured event logger. Writes to unified logging with a dedicated
/// subsystem so events are visible in Console.app and accessible for debugging.
/// Replace with a real SDK (Firebase, Mixpanel) when ready.
enum AnalyticsService {
    private static let log = Logger(subsystem: "com.jackwallner.posture", category: "analytics")

    /// Log a structured event with optional numeric properties.
    static func track(_ event: String, properties: [String: LosslessStringConvertible] = [:]) {
        let props = properties.isEmpty ? "" : " " + properties.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        log.notice("[\(event, privacy: .public)]\(props, privacy: .public)")
    }

    // MARK: - Event helpers

    static func sessionStarted(source: PostureSource, targetSeconds: Int) {
        track("session_started", properties: ["source": source.rawValue, "target": targetSeconds])
    }

    static func sessionCompleted(score: Int, duration: Int, source: PostureSource) {
        track("session_completed", properties: ["score": score, "duration": duration, "source": source.rawValue])
    }

    static func sessionPaused() {
        track("session_paused")
    }

    static func sessionResumed() {
        track("session_resumed")
    }

    static func sessionCancelled() {
        track("session_cancelled")
    }

    static func chinTuckWarmupCompleted(reps: Int) {
        track("chin_tuck_reps_completed", properties: ["reps": reps])
    }

    static func chinTuckWarmupSkipped(repsCompleted: Int) {
        track("chin_tuck_warmup_skipped", properties: ["reps": repsCompleted])
    }

    static func calibrateStarted(mode: String) {
        track("calibrate_started", properties: ["mode": mode])
    }

    static func calibrateCompleted() {
        track("calibrate_completed")
    }

    static func streakMilestone(streak: Int) {
        track("streak_milestone", properties: ["streak": streak])
    }

    static func acknowledgmentRecorded(method: AcknowledgmentMethod, quality: PostureQuality?) {
        var props: [String: LosslessStringConvertible] = ["method": method.rawValue]
        if let q = quality { props["quality"] = q.rawValue }
        track("acknowledgment_recorded", properties: props)
    }

    static func remindersScheduled(count: Int) {
        track("reminders_scheduled", properties: ["count": count])
    }

    static func paywallShown() {
        track("paywall_shown")
    }

    static func purchaseAttempted(plan: String) {
        track("purchase_attempted", properties: ["plan": plan])
    }

    static func purchaseCompleted(plan: String) {
        track("purchase_completed", properties: ["plan": plan])
    }
}
