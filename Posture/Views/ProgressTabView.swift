import SwiftData
import SwiftUI

/// The "Progress" tab: your climb across every practice level. Free members
/// see the shape of the ladder - the levels themselves and where they stand -
/// with each rung's details blurred; Posture+ shows the full picture: current
/// level, passes to the next, and what each level asks of you.
struct ProgressTabView: View {
    @Query private var sessions: [PostureSession]
    @State private var subscriptions = SubscriptionService.shared
    @State private var showingPaywall = false

    private var passedCount: Int {
        sessions.filter { $0.kind == .practice && $0.passed }.count
    }

    private var isPro: Bool { subscriptions.isProSubscriber }
    private var trueLevel: Int { PracticeProgression.level(passedSessions: passedCount) }
    private var effectiveLevel: Int {
        PracticeProgression.effectiveLevel(level: trueLevel, isPro: isPro)
    }

    /// Free users still see where the ladder goes - the rungs are the pitch -
    /// but the numbers on each rung are Posture+.
    private var revealsDetail: Bool { isPro }
    private var climbing: Bool { isPro || trueLevel < PracticeProgression.freeLevelCap }

    private let shownLevels = Array(1...12)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    ladder
                    if !isPro { proCTA }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .dawnBackground()
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPaywall) {
                PaywallView(paywallImpressionId: "posture_progress_tab")
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        let progress = PracticeProgression.progressInLevel(passedSessions: passedCount)
        let fraction = progress.needed > 0 ? Double(progress.done) / Double(progress.needed) : 1
        return VStack(alignment: .leading, spacing: 10) {
            Text("Your climb")
                .font(Theme.font(.caption, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.sage)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("Level \(effectiveLevel)")
                    .font(Theme.display(34))
                    .foregroundStyle(Theme.ink)
                if climbing {
                    Text("\(progress.done) of \(progress.needed) to Level \(effectiveLevel + 1)")
                        .font(Theme.font(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                }
            }

            if climbing {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.paper3)
                        Capsule()
                            .fill(Theme.sage)
                            .frame(width: max(8, geo.size.width * fraction))
                    }
                }
                .frame(height: 8)
            }

            Text(subtitle)
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var subtitle: String {
        if isPro {
            return "Every pass climbs the ladder. Each level adds a minute to the hold and lifts the aligned-% bar."
        }
        if trueLevel < PracticeProgression.freeLevelCap {
            return "The free ladder climbs to Level \(PracticeProgression.freeLevelCap). Posture+ opens every level above, and the numbers behind each one."
        }
        return "You're at the top of the free ladder. Posture+ opens every level above Level \(PracticeProgression.freeLevelCap)."
    }

    // MARK: - Ladder

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
        let passes = PracticeProgression.threshold(forLevel: level)
        let isCurrent = level == effectiveLevel
        let reached = level <= effectiveLevel
        let lockedForFree = !isPro && level > PracticeProgression.freeLevelCap

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Theme.sage : (reached ? Theme.sageTint : Theme.paper3))
                    .frame(width: 30, height: 30)
                Text("\(level)")
                    .font(Theme.font(.footnote, weight: .bold))
                    .foregroundStyle(isCurrent ? .white : (reached ? Theme.sage : Theme.ink3))
            }

            // The rung's numbers. Crisp for Posture+, blurred for free so the
            // ladder's shape sells the upgrade without giving the detail away.
            VStack(alignment: .leading, spacing: 1) {
                Text("\(minutes) \(minutes == 1 ? "minute" : "minutes") held tall")
                    .font(Theme.font(.subheadline).weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)
                Text("\(target)% aligned to pass · \(passes) total passes")
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink3)
            }
            .blur(radius: revealsDetail ? 0 : 5)
            .opacity(revealsDetail ? 1 : 0.7)
            .accessibilityHidden(!revealsDetail)

            Spacer()

            if isCurrent {
                Text("you")
                    .font(Theme.font(.caption2, weight: .bold))
                    .foregroundStyle(Theme.sage)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.sageTint, in: .capsule)
            } else if lockedForFree {
                Image(systemName: "lock.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isPro { showingPaywall = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rowAccessibility(level: level, minutes: minutes, target: target, isCurrent: isCurrent, locked: lockedForFree))
    }

    private func rowAccessibility(level: Int, minutes: Int, target: Int, isCurrent: Bool, locked: Bool) -> String {
        var parts = ["Level \(level)"]
        if isCurrent { parts.append("your current level") }
        if revealsDetail {
            parts.append("\(minutes) minute hold, \(target) percent to pass")
        } else if locked {
            parts.append("Posture plus. Details hidden.")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - CTA

    private var proCTA: some View {
        Button { showingPaywall = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("POSTURE+")
                    .font(Theme.font(.caption2, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.sage)
                Text("See the whole climb.")
                    .font(Theme.display(22))
                    .foregroundStyle(Theme.ink)
                Text("Unlock every level above \(PracticeProgression.freeLevelCap): longer holds, higher bars, and the training dose that rebuilds your default posture.")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("See plans →")
                    .font(Theme.font(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.sage)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sageTint, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
