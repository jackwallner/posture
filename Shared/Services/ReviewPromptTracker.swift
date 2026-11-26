import Foundation

extension Notification.Name {
    /// Posted after a satisfaction moment. The host may call the system rating
    /// prompt after a short delay, with no question in front of it.
    static let posturePositiveMomentForReview = Notification.Name("com.jackwallner.posture.positiveMomentForReview")
}

/// What the user did about a review. Only opening the review page ends the
/// passive asks: someone who sent feedback can still rate.
enum ReviewPromptOutcome: String, Sendable {
    /// Opened the App Store write-review page from Settings.
    case openedWriteReview
    /// Sent feedback by mail. Never stops the asks.
    case submittedFeedback
}

/// The good results that may ask for a rating. Nothing else asks: not a
/// launch, a tab, a count of opens or a screen appearing.
enum ReviewMomentKind: String, Sendable {
    /// A check-in scored aligned, right after the user sees it. Reached from
    /// the first check-in of a typical user's day.
    case goodCheckIn = "good_check_in"
    /// A 7, 14, 30, 60 or 100 day streak day reached by a check-in.
    case streakMilestone = "streak_milestone"
    /// A bounded practice session finished at or above its aligned-% target:
    /// the core action done well.
    case practicePassed = "practice_passed"
}

/// Which results count as a good moment. Pure, so a bad result is proved not
/// to ask.
enum ReviewMoment {
    nonisolated static func checkIn(
        quality: PostureQuality?,
        streakBefore: Int,
        streakAfter: Int
    ) -> ReviewMomentKind? {
        if quality == .good { return .goodCheckIn }
        if streakAfter > streakBefore, StreakService.streakMilestoneDays.contains(streakAfter) {
            return .streakMilestone
        }
        return nil
    }

    /// `passed` is the session's own verdict: completed at the ladder's length
    /// with the aligned-% target met. A walk, a partial, a custom length or a
    /// miss never asks.
    nonisolated static func practice(
        kind: PostureSessionKind,
        completed: Bool,
        passed: Bool
    ) -> ReviewMomentKind? {
        kind == .practice && completed && passed ? .practicePassed : nil
    }
}

/// Persists launch counts, positive moments, and review-prompt eligibility in the app group.
@MainActor
enum ReviewPromptTracker {
    private static let defaults = UserDefaults(suiteName: postureAppGroupID) ?? .standard

    private static let launchCountKey = "reviewPrompt.appLaunchCount"
    private static let firstOpenKey = "reviewPrompt.firstAppOpenDate"
    private static let lastShownKey = "reviewPrompt.lastShownDate"
    private static let outcomeKey = "reviewPrompt.outcome"
    private static let positiveMomentCountKey = "reviewPrompt.positiveMomentCount"
    private static let pendingPositiveMomentKey = "reviewPrompt.pendingPositiveMoment"
    private static let pendingMomentKindKey = "reviewPrompt.pendingMomentKind"

    /// Ask early. Most installs are gone within a week, so the only tenure
    /// gate is "not the first session": a second cold start.
    static let minimumLaunchCount = 2
    /// Days between our calls. Apple shows the prompt at most three times a
    /// year per device and decides each time, so this paces the asks.
    static let cooldownDays = 30

    static var appLaunchCount: Int {
        get { max(defaults.integer(forKey: launchCountKey), 0) }
        set { defaults.set(newValue, forKey: launchCountKey) }
    }

    static var firstAppOpenDate: Date? {
        get { defaults.object(forKey: firstOpenKey) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: firstOpenKey)
            } else {
                defaults.removeObject(forKey: firstOpenKey)
            }
        }
    }

    static var lastShownDate: Date? {
        get { defaults.object(forKey: lastShownKey) as? Date }
        set {
            if let date = newValue {
                defaults.set(date, forKey: lastShownKey)
            } else {
                defaults.removeObject(forKey: lastShownKey)
            }
        }
    }

    static var outcome: ReviewPromptOutcome? {
        get {
            guard let raw = defaults.string(forKey: outcomeKey) else { return nil }
            return ReviewPromptOutcome(rawValue: raw)
        }
        set {
            if let value = newValue {
                defaults.set(value.rawValue, forKey: outcomeKey)
            } else {
                defaults.removeObject(forKey: outcomeKey)
            }
        }
    }

    static var positiveMomentCount: Int {
        get { max(defaults.integer(forKey: positiveMomentCountKey), 0) }
        set { defaults.set(newValue, forKey: positiveMomentCountKey) }
    }

    static var hasPendingPositiveMoment: Bool {
        get { defaults.bool(forKey: pendingPositiveMomentKey) }
        set { defaults.set(newValue, forKey: pendingPositiveMomentKey) }
    }

    /// The kind of the pending moment, for the `rating_asked` log.
    static var pendingMomentKind: ReviewMomentKind? {
        defaults.string(forKey: pendingMomentKindKey).flatMap(ReviewMomentKind.init(rawValue:))
    }

    private static var isUITest: Bool {
        #if DEBUG
        return LaunchArguments.contains("UITEST_FRESH")
        #else
        return false
        #endif
    }

    static func recordAppLaunch(now: Date = .now) {
        if firstAppOpenDate == nil {
            firstAppOpenDate = now
        }
        appLaunchCount += 1
        // A moment is only good right after the result. One left from an
        // earlier launch must not ask at an unrelated time.
        consumePendingPositiveMoment()
    }

    static func recordPositiveMoment(_ kind: ReviewMomentKind = .goodCheckIn) {
        positiveMomentCount += 1
        hasPendingPositiveMoment = true
        defaults.set(kind.rawValue, forKey: pendingMomentKindKey)
    }

    static func consumePendingPositiveMoment() {
        hasPendingPositiveMoment = false
        defaults.removeObject(forKey: pendingMomentKindKey)
    }

    static func passivePromptAllowed(now: Date = .now) -> Bool {
        guard outcome != .openedWriteReview else { return false }
        guard let last = lastShownDate else { return true }
        let cooldown = TimeInterval(cooldownDays) * 86_400
        return now.timeIntervalSince(last) >= cooldown
    }

    static func canRequestReview(hasCompletedSetup: Bool, now: Date = .now) -> Bool {
        guard !isUITest else { return false }
        guard hasCompletedSetup else { return false }
        guard passivePromptAllowed(now: now) else { return false }
        return appLaunchCount >= minimumLaunchCount
    }

    /// A positive moment is pending and the gates allow an ask. A blocked ask
    /// leaves the moment pending so the next one can ask.
    static func shouldRequestAfterPositiveMoment(
        hasCompletedSetup: Bool,
        now: Date = .now
    ) -> Bool {
        guard hasPendingPositiveMoment else { return false }
        return canRequestReview(hasCompletedSetup: hasCompletedSetup, now: now)
    }

    /// Stamps the cooldown when the system prompt is called (Apple decides
    /// whether it shows), and consumes the moment.
    static func markShown(now: Date = .now) {
        lastShownDate = now
        consumePendingPositiveMoment()
    }

    static func markOpenedWriteReview() {
        outcome = .openedWriteReview
        markShown()
    }

    /// Never overwrites `.openedWriteReview`: feedback sent after the review
    /// page must not reopen the asks that page ended.
    static func markFeedbackSubmitted() {
        if outcome != .openedWriteReview {
            outcome = .submittedFeedback
        }
    }

    /// The Send Feedback row's result: only a mail compose that actually
    /// opened counts as feedback sent.
    static func recordFeedbackMailOpened(_ opened: Bool) {
        guard opened else { return }
        markFeedbackSubmitted()
    }
}
