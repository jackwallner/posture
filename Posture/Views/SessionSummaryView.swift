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
                Text("\(targetLabel)%")
                    .font(.system(size: 34, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("target")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .dawnCard()
        }
    }

    /// One bar per 10 seconds of practice, colored by how tall it was held.
    private var timelineStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("The session, ten seconds at a time")
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
            if result.leveledUp {
                receiptLine(icon: "chevron.up.2", color: Theme.sage,
                            text: "Level \(result.newLevel) unlocked — tomorrow's practice grows a little.")
            } else if result.passed {
                receiptLine(icon: "checkmark.circle.fill", color: Theme.sage,
                            text: "Target met. That counts toward Level \(result.newLevel + 1).")
            } else if result.completed {
                receiptLine(icon: "circle.dashed", color: Theme.ink3,
                            text: "Finished, under target. Streak safe — the level waits for a taller day.")
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
        if !result.completed { return "Ended early" }
        if result.leveledUp { return "Level up" }
        if result.passed { return "Held tall" }
        return "Done"
    }

    private var subtitle: String {
        if !result.completed {
            return "The minutes you held still count in today's timeline. Come back for the full practice."
        }
        if result.passed {
            return "You stayed aligned \(result.alignedPercent)% of the session — over the \(targetLabel)% bar."
        }
        return "You finished the full practice. \(result.alignedPercent)% aligned today; the bar was \(targetLabel)%."
    }

    private var eyebrow: String {
        result.completed ? "practice complete" : "practice ended"
    }

    private var accent: Color {
        if !result.completed { return Theme.ink3 }
        return result.passed ? Theme.sage : Theme.sand
    }

    private var tint: Color {
        if !result.completed { return Theme.paper2 }
        return result.passed ? Theme.sageTint : Theme.sandTint
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
