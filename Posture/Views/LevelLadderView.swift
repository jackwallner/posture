import SwiftData
import SwiftUI

/// The level system, explained. Levels are earned by passing practices
/// (meeting the session's aligned-% target); each level makes the daily
/// hold a minute longer and the bar a notch higher. Free tier climbs to
/// level 2; the rest of the ladder is Posture+.
struct LevelLadderView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [PostureSession]
    @State private var subscriptions = SubscriptionService.shared
    @State private var showingPaywall = false

    private var passedCount: Int {
        sessions.filter { $0.kind == .practice && $0.passed }.count
    }

    private var trueLevel: Int {
        PracticeProgression.level(passedSessions: passedCount)
    }

    private var isPro: Bool { subscriptions.isProSubscriber }

    private var effectiveLevel: Int {
        PracticeProgression.effectiveLevel(level: trueLevel, isPro: isPro)
    }

    private let shownLevels = Array(1...12)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    howItWorks
                    ladder
                    whyItWorks
                    if !isPro {
                        proCTA
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .dawnBackground()
            .navigationTitle("Levels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(Theme.font(.footnote, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                    }
                    .accessibilityLabel("Close")
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView(paywallImpressionId: "posture_level_gate")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Level \(effectiveLevel)")
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.goodText)
            Text("Your practice grows with you.")
                .font(Theme.display(26))
                .foregroundStyle(Theme.ink)
            let progress = PracticeProgression.progressInLevel(passedSessions: passedCount)
            Text(isPro || trueLevel < PracticeProgression.freeLevelCap
                 ? PracticeProgressCopy.levelUpCaption(
                     done: progress.done, needed: progress.needed, nextLevel: trueLevel + 1
                   ) + "."
                 : "You've reached the top of the free ladder.")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
        }
    }

    private var howItWorks: some View {
        VStack(alignment: .leading, spacing: 8) {
            explainerLine(icon: "flame", text: "Finish the minutes and your streak day is safe, whatever the score.")
            explainerLine(icon: "checkmark.circle", text: "Score at or above the day's aligned-% target and the session is a pass.")
            explainerLine(icon: "chevron.up.2", text: "Passes add up to levels: one more minute, a slightly higher target each time.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard(cornerRadius: 14)
    }

    private func explainerLine(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.goodText)
                .frame(width: 22)
            Text(text)
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var ladder: some View {
        VStack(spacing: 0) {
            ForEach(shownLevels, id: \.self) { level in
                ladderRow(level)
                if level != shownLevels.last {
                    Divider().background(Theme.paper3)
                }
            }
        }
        .padding(.vertical, 4)
        .dawnCard(cornerRadius: 14)
    }

    private func ladderRow(_ level: Int) -> some View {
        let minutes = PracticeProgression.sessionSeconds(forLevel: level) / 60
        let target = PracticeProgression.targetPercent(forLevel: level)
        let locked = !isPro && level > PracticeProgression.freeLevelCap
        let isCurrent = level == effectiveLevel
        let reached = level <= effectiveLevel

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Theme.goodText : (reached ? Theme.sageTint : Theme.paper3))
                    .frame(width: 30, height: 30)
                if locked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                } else {
                    Text("\(level)")
                        .font(Theme.font(.footnote, weight: .bold))
                        .foregroundStyle(isCurrent ? .white : (reached ? Theme.goodText : Theme.ink3))
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("\(minutes) \(minutes == 1 ? "minute" : "minutes") held tall")
                    .font(Theme.font(.subheadline).weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(locked ? Theme.ink3 : Theme.ink)
                Text("\(target)% aligned to pass · \(PracticeProgression.threshold(forLevel: level)) total passes")
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
            if isCurrent {
                Text("you")
                    .font(Theme.font(.caption2, weight: .bold))
                    .foregroundStyle(Theme.goodText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.sageTint, in: .capsule)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if locked { showingPaywall = true }
        }
    }

    private var whyItWorks: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Why the ramp matters")
                .font(Theme.font(.footnote, weight: .semibold))
                .foregroundStyle(Theme.ink3)
            Text("Posture is endurance, not willpower. The muscles that hold your head tall respond to graded training the way any muscle does: a little longer, a little more often. Clinical studies of daily neck-and-posture training find measurable change in about six to eight weeks of consistent practice.")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            Text("Our best guess at the payoff: reach level 5 and you're holding 7 minutes at a 62% bar, the point where most people notice they sit taller without thinking about it. Reach level 10 and the 12-minute hold makes tall posture your default, not your effort.")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard(cornerRadius: 14)
    }

    private var proCTA: some View {
        Button { showingPaywall = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("POSTURE+")
                    .font(Theme.font(.caption2, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.goodText)
                Text("The free ladder ends at level \(PracticeProgression.freeLevelCap).")
                    .font(Theme.display(20))
                    .foregroundStyle(Theme.ink)
                Text("Posture+ unlocks every level above it: longer holds, higher bars, and the training dose that actually rebuilds your default posture.")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("See plans →")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.goodText)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sageTint, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
