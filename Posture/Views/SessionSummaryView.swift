import SwiftUI

/// The receipt for a finished practice session: what you held, whether it
/// passed, what it did for your streak and level.
struct SessionSummaryView: View {
    let result: PracticeSessionController.Result
    let onDone: () -> Void

    var body: some View {
        ZStack {
            tint.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 22) {
                Spacer()

                VStack(alignment: .leading, spacing: 14) {
                    Text(eyebrow)
                        .font(.caption.weight(.semibold))
                        .tracking(0.8)
                        .foregroundStyle(accent)
                    HStack(alignment: .firstTextBaseline, spacing: 0) {
                        Text(headline)
                            .font(Theme.display(56))
                            .foregroundStyle(Theme.ink)
                        Text(".")
                            .font(Theme.display(56))
                            .foregroundStyle(accent)
                    }
                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                scoreRow

                if !result.timeline.isEmpty {
                    timelineStrip
                }

                receiptLines

                Spacer()

                Button(action: onDone) { Text("Done").frame(maxWidth: .infinity) }
                    .buttonStyle(.daylight(.primary))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Sections

    private var isWalk: Bool { result.kind == .walk }

    private var scoreRow: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(result.alignedPercent)%")
                    .font(.system(size: 34, weight: .regular, design: .rounded))
                    .foregroundStyle(accent)
                Text("aligned")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .dawnCard()

            VStack(alignment: .leading, spacing: 2) {
                Text(isWalk ? minutesLabel : "\(targetLabel)%")
                    .font(.system(size: 34, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(isWalk ? "held tall" : "target")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .dawnCard()
        }
    }

    /// One bar per segment (10s of practice, minute of walk), colored by how
    /// tall it was held.
    private var timelineStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(isWalk ? "The walk, minute by minute" : "The session, ten seconds at a time")
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(Theme.ink3)
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(result.timeline.enumerated()), id: \.offset) { _, fraction in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(barColor(fraction))
                        .frame(height: 12 + 24 * fraction)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 40, alignment: .bottom)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard()
    }

    @ViewBuilder
    private var receiptLines: some View {
        VStack(alignment: .leading, spacing: 8) {
            if result.completed, result.streakDays > 0 {
                receiptLine(icon: "flame.fill", color: Theme.sand,
                            text: "Day \(result.streakDays) of your streak.")
            }
            if isWalk {
                // Walks carry no level stakes — the streak line is the receipt.
            } else if result.leveledUp {
                receiptLine(icon: "chevron.up.2", color: Theme.sage,
                            text: "Level \(result.newLevel) unlocked — tomorrow's practice grows a little.")
            } else if result.passed {
                receiptLine(icon: "checkmark.circle.fill", color: Theme.sage,
                            text: "Target met. That counts toward Level \(result.newLevel + 1).")
            } else if result.completed {
                receiptLine(icon: "circle.dashed", color: Theme.ink3,
                            text: "Finished, under target. Streak safe. The level waits for a taller day.")
            }
            ForEach(result.newAchievementTitles, id: \.self) { title in
                receiptLine(icon: "rosette", color: Theme.lavender,
                            text: "New badge: \(title)")
            }
        }
    }

    private func receiptLine(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color)
            Text(text)
                .font(.system(.footnote, design: .rounded).weight(.medium))
                .foregroundStyle(Theme.ink2)
        }
    }

    // MARK: - Copy

    private var headline: String {
        if isWalk { return result.completed ? "Walked tall" : "Walk ended" }
        if !result.completed { return "Ended early" }
        if result.leveledUp { return "Level up" }
        if result.passed { return "Held tall" }
        return "Done"
    }

    private var subtitle: String {
        if isWalk {
            if !result.completed {
                return "The minutes you walked still count in today's timeline."
            }
            return "You held tall for \(result.alignedPercent)% of the walk (after finding your stride)."
        }
        if !result.completed {
            return "The minutes you held still count in today's timeline. Come back for the full practice."
        }
        if result.passed {
            return "You stayed aligned \(result.alignedPercent)% of the session — over the \(targetLabel)% bar."
        }
        return "You finished the full practice. \(result.alignedPercent)% aligned today; the bar was \(targetLabel)%."
    }

    private var eyebrow: String {
        if isWalk { return result.completed ? "walk complete" : "walk ended" }
        return result.completed ? "practice complete" : "practice ended"
    }

    private var accent: Color {
        if !result.completed { return Theme.ink3 }
        if isWalk { return result.alignedPercent >= 60 ? Theme.sage : Theme.sand }
        return result.passed ? Theme.sage : Theme.sand
    }

    private var tint: Color {
        if !result.completed { return Theme.paper2 }
        if isWalk { return result.alignedPercent >= 60 ? Theme.sageTint : Theme.sandTint }
        return result.passed ? Theme.sageTint : Theme.sandTint
    }

    private var minutesLabel: String {
        let total = result.goodSeconds + result.borderlineSeconds + result.badSeconds
        let minutes = max(1, Int((Double(total) / 60).rounded()))
        return "\(minutes)m"
    }

    private var targetLabel: Int {
        // Result carries the target implicitly via pass/fail; recompute the
        // level's bar for display.
        PracticeProgression.targetPercent(forLevel: result.level)
    }

    private func barColor(_ fraction: Double) -> Color {
        switch fraction {
        case 0.75...: return Theme.sage
        case 0.45..<0.75: return Theme.sand
        default: return Theme.clay
        }
    }
}
