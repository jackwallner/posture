import SwiftData
import SwiftUI

/// Program map: path, now/next requirements, pips toward the next level.
struct ProgressTabView: View {
    @Environment(GoalSettings.self) private var settings
    @Query private var sessions: [PostureSession]
    @State private var subscriptions = SubscriptionService.shared
    @State private var showingPaywall = false
    @State private var showHowItWorks = false
    @State private var showFullProgram = false
    /// Selected posture ladder for `.both`-focus users.
    @State private var selectedMode: PostureMode = .standing

    private var trainsBothPostures: Bool { settings.postureFocus.trainsBoth }
    private var activeMode: PostureMode {
        trainsBothPostures ? selectedMode : settings.postureFocus.defaultMode
    }

    /// Passed practices for the active posture; pre-split rows (nil mode) are
    /// grandfathered into every ladder so no level is lost on migration.
    private var passedCount: Int {
        sessions.filter {
            $0.kind == .practice && $0.passed
                && ($0.postureMode == activeMode || $0.postureMode == nil)
        }.count
    }

    private var isPro: Bool { subscriptions.isProSubscriber }
    private var trueLevel: Int { PracticeProgression.level(passedSessions: passedCount) }
    private var effectiveLevel: Int {
        PracticeProgression.effectiveLevel(level: trueLevel, isPro: isPro)
    }

    private var progress: (done: Int, needed: Int) {
        PracticeProgression.progressInLevel(passedSessions: passedCount)
    }

    private var climbing: Bool { isPro || trueLevel < PracticeProgression.freeLevelCap }

    private func revealsDetail(for level: Int) -> Bool {
        isPro || level <= PracticeProgression.freeLevelCap
    }

    private let shownLevels = Array(1...12)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Posture+ is pitched at the very top, pinned above the scroll,
                // so a free user always sees the upgrade without scrolling.
                if !isPro { proBanner }
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if trainsBothPostures { modePicker }
                        programHeader
                        ProgressPathView(
                            currentLevel: effectiveLevel,
                            maxLevel: shownLevels.last!,
                            isPro: isPro,
                            onLockedTap: { showingPaywall = true }
                        )
                        if climbing, effectiveLevel < shownLevels.last! {
                            ProgramStageCompareView(
                                currentLevel: effectiveLevel,
                                nextLevel: effectiveLevel + 1
                            )
                            levelProgressBlock
                        } else if !isPro {
                            Text("Top of the free program. Posture+ opens every level above.")
                                .font(Theme.font(.footnote))
                                .foregroundStyle(Theme.ink2)
                                .padding(.horizontal, 4)
                        }
                        howItWorksAccordion
                        fullProgramAccordion
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .dawnBackground()
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingPaywall) {
                PaywallView(paywallImpressionId: "posture_progress_tab")
            }
        }
    }

    /// Slim, always-visible upgrade bar pinned to the top of the tab for free
    /// users - the omnipresent pitch, like the baseball app.
    private var proBanner: some View {
        Button { showingPaywall = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.goodText)
                    .frame(width: 32, height: 32)
                    .background(Theme.paper2, in: Circle())
                VStack(alignment: .leading, spacing: 1) {
                    Text("Unlock the full program")
                        .font(Theme.font(.subheadline, weight: .bold))
                        .foregroundStyle(Theme.ink)
                    Text("Every level above \(PracticeProgression.freeLevelCap), longer holds, higher targets.")
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.ink2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                Text("Posture+")
                    .font(Theme.font(.caption, weight: .bold))
                    .foregroundStyle(Theme.goodText)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.goodText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.sageTint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Unlock the full program with Posture+")
    }

    /// Standing | Sitting switch for `.both`-focus users - each posture has its
    /// own program ladder.
    private var modePicker: some View {
        HStack(spacing: 4) {
            ForEach(PostureMode.allCases, id: \.self) { m in
                let selected = activeMode == m
                Button {
                    withAnimation(.snappy(duration: 0.22)) { selectedMode = m }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: m.icon)
                            .font(.system(size: 11, weight: .semibold))
                        Text(m.label)
                            .font(Theme.font(.footnote, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .foregroundStyle(selected ? Theme.ink : Theme.ink2)
                    .background(selected ? Theme.sage : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(4)
        .background(Theme.paper3, in: Capsule())
        .accessibilityLabel("Choose posture program")
    }

    private var programHeader: some View {
        let minutes = PracticeProgression.sessionSeconds(forLevel: effectiveLevel) / 60
        let target = PracticeProgression.targetPercent(forLevel: effectiveLevel)
        return VStack(alignment: .leading, spacing: 4) {
            // Eyebrow stays generic; the Standing|Sitting toggle directly above
            // scopes which program this is (and keeps the copy stable).
            Text("Your program")
                .font(Theme.font(.caption2, weight: .semibold))
                .tracking(0.8)
                .foregroundStyle(Theme.goodText)
            Text("Level \(effectiveLevel)")
                .font(Theme.display(28))
                .foregroundStyle(Theme.ink)
            Text("Today's practice: hold tall for \(minutes) min. Score \(target)% aligned and it's a pass.")
                .font(Theme.font(.footnote, weight: .semibold))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("Passes move you up the ladder. Each level adds a minute and nudges the target up.")
                .font(Theme.font(.footnote))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var levelProgressBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                LevelPipsView(filled: progress.done, total: progress.needed, size: .regular)
                Text(PracticeProgressCopy.levelUpCaption(
                    done: progress.done,
                    needed: progress.needed,
                    nextLevel: effectiveLevel + 1
                ))
                .font(Theme.font(.footnote, weight: .semibold))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)
            }
            LevelPipsLegend()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard(cornerRadius: 14)
    }

    private var howItWorksAccordion: some View {
        DisclosureGroup(isExpanded: $showHowItWorks) {
            VStack(alignment: .leading, spacing: 8) {
                explainerLine(icon: "flame", text: "Finish the minutes and your streak day is safe, whatever the score.")
                explainerLine(icon: "checkmark.circle", text: "Score at or above the day's aligned-% target and the session is a pass. A pip fills in.")
                explainerLine(icon: "chevron.up.2", text: "Fill all the pips and you level up: one more minute, a slightly higher target.")
            }
            .padding(.top, 8)
        } label: {
            Text("How the program works")
                .font(Theme.font(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(16)
        .dawnCard(cornerRadius: 14)
    }

    private var fullProgramAccordion: some View {
        DisclosureGroup(isExpanded: $showFullProgram) {
            VStack(spacing: 0) {
                ForEach(shownLevels, id: \.self) { level in
                    ladderRow(level)
                    if level != shownLevels.last { Divider().background(Theme.paper3) }
                }
            }
            .padding(.top, 8)
        } label: {
            Text("Full program")
                .font(Theme.font(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.ink)
        }
        .padding(16)
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

    private func ladderRow(_ level: Int) -> some View {
        let minutes = PracticeProgression.sessionSeconds(forLevel: level) / 60
        let target = PracticeProgression.targetPercent(forLevel: level)
        let isCurrent = level == effectiveLevel
        let reached = level < effectiveLevel
        let lockedForFree = !isPro && level > PracticeProgression.freeLevelCap
        let showDetail = revealsDetail(for: level)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isCurrent ? Theme.goodText : (reached ? Theme.sageTint : Theme.paper3))
                    .frame(width: 26, height: 26)
                if reached {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.goodText)
                } else {
                    Text("\(level)")
                        .font(Theme.font(.caption2, weight: .bold))
                        .foregroundStyle(isCurrent ? .white : Theme.ink3)
                }
            }
            if showDetail {
                Text("\(minutes) min · \(target)% aligned")
                    .font(Theme.font(.footnote).weight(isCurrent ? .semibold : .regular))
                    .foregroundStyle(Theme.ink)
            } else {
                Text("Posture+")
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.ink3)
            }
            Spacer()
            if isCurrent {
                Text("now")
                    .font(Theme.font(.caption2, weight: .bold))
                    .foregroundStyle(Theme.goodText)
            } else if lockedForFree {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.ink3)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture { if !showDetail { showingPaywall = true } }
    }

}
