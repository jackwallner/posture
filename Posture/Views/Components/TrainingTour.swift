import SwiftUI

/// First-run guided tour of the monitoring loop, shown once right after the
/// paywall. Spotlight coachmarks anchored to the real Today cards (same
/// pattern as Fitness Streaks), ending in a *live* step: slouch on purpose,
/// feel the nudge, understand the product in one physical moment.
struct TrainingTourStep {
    let anchorID: String?
    let title: String
    let body: String
    /// The interactive slouch step — its panel reacts to the live monitor.
    var isLiveSlouchStep = false
}

private struct TrainingTourAnchorKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] { [:] }
    static func reduce(value: inout [String: Anchor<CGRect>],
                       nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue()) { _, new in new }
    }
}

extension View {
    func trainingTourAnchor(_ id: String) -> some View {
        anchorPreference(key: TrainingTourAnchorKey.self, value: .bounds) { [id: $0] }
    }

    func trainingTourOverlay(
        steps: [TrainingTourStep],
        index: Binding<Int>,
        isActive: Bool,
        liveQuality: PostureQuality?,
        onFinish: @escaping () -> Void
    ) -> some View {
        overlayPreferenceValue(TrainingTourAnchorKey.self) { anchors in
            // The GeometryReader itself spans the full screen so anchor rects
            // resolve in the same space the dim layer draws in. Ignoring the
            // safe area any deeper shifts the spotlight cutout by the inset.
            GeometryReader { proxy in
                if isActive, steps.indices.contains(index.wrappedValue) {
                    TrainingTourPresenter(
                        anchors: anchors,
                        proxy: proxy,
                        steps: steps,
                        index: index,
                        liveQuality: liveQuality,
                        onFinish: onFinish
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(isActive)
        }
    }
}

private struct TrainingTourPresenter: View {
    let anchors: [String: Anchor<CGRect>]
    let proxy: GeometryProxy
    let steps: [TrainingTourStep]
    @Binding var index: Int
    let liveQuality: PostureQuality?
    var onFinish: () -> Void

    /// Sticky: once the user has slouched during the live step, the success
    /// state stays even after they straighten back up.
    @State private var slouchFelt = false

    private static let panelWidth: CGFloat = 330
    private static let estimatedPanelHeight: CGFloat = 200
    private static let spotlightInset: CGFloat = -8

    var body: some View {
        let step = steps[index]
        let spotlight: CGRect? = step.anchorID
            .flatMap { anchors[$0] }
            .map { proxy[$0].insetBy(dx: Self.spotlightInset, dy: Self.spotlightInset) }

        ZStack {
            dimmedBackground(spotlight: spotlight)
            spotlightBorder(spotlight: spotlight)
            calloutPanel(step: step, spotlight: spotlight)
        }
        .animation(.easeInOut(duration: 0.22), value: index)
        .onChange(of: liveQuality) { _, quality in
            if steps[index].isLiveSlouchStep, quality == .bad {
                withAnimation(.easeInOut(duration: 0.3)) { slouchFelt = true }
            }
        }
    }

    private func dimmedBackground(spotlight: CGRect?) -> some View {
        let frame = proxy.frame(in: .local)
        return ZStack {
            if let s = spotlight {
                Path { p in
                    p.addRect(frame)
                    p.addRoundedRect(
                        in: s,
                        cornerSize: CGSize(width: Theme.cardRadius, height: Theme.cardRadius)
                    )
                }
                .fill(Theme.ink.opacity(0.55), style: FillStyle(eoFill: true))
            } else {
                Theme.ink.opacity(0.55)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
    }

    @ViewBuilder
    private func spotlightBorder(spotlight: CGRect?) -> some View {
        if let s = spotlight {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .stroke(Theme.sage, lineWidth: 2)
                .frame(width: s.width, height: s.height)
                .position(x: s.midX, y: s.midY)
                .allowsHitTesting(false)
        }
    }

    private func calloutPanel(step: TrainingTourStep, spotlight: CGRect?) -> some View {
        let frame = proxy.frame(in: .local)
        let width = min(frame.width - 28, Self.panelWidth)
        let position = panelPosition(spotlight: spotlight, frame: frame)

        return panelContent(step: step)
            .frame(width: width)
            .position(position)
    }

    private func panelPosition(spotlight: CGRect?, frame: CGRect) -> CGPoint {
        let panelHeight = Self.estimatedPanelHeight
        guard let s = spotlight else {
            return CGPoint(x: frame.midX, y: frame.midY)
        }
        let topGap = s.minY - frame.minY
        let bottomGap = frame.maxY - s.maxY
        let needed = panelHeight + 28

        if bottomGap >= needed {
            return CGPoint(x: frame.midX, y: s.maxY + 16 + panelHeight / 2)
        }
        if topGap >= needed {
            return CGPoint(x: frame.midX, y: s.minY - 16 - panelHeight / 2)
        }
        if bottomGap >= topGap {
            let y = min(frame.maxY - panelHeight / 2 - 24, s.maxY + 16 + panelHeight / 2)
            return CGPoint(x: frame.midX, y: y)
        }
        let y = max(frame.minY + panelHeight / 2 + 24, s.minY - 16 - panelHeight / 2)
        return CGPoint(x: frame.midX, y: y)
    }

    private func panelContent(step: TrainingTourStep) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Step \(index + 1) of \(steps.count)")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(Theme.ink3)
                Spacer()
                Button { onFinish() } label: {
                    Text("Skip")
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.ink3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Skip tour")
            }

            if step.isLiveSlouchStep {
                liveSlouchContent(step: step)
            } else {
                Text(step.title)
                    .font(Theme.display(20))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(step.body)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.ink2)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                if index > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) { index = max(0, index - 1) }
                    } label: {
                        Text("Back")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(Theme.ink2)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button { advance() } label: {
                    Text(nextLabel(step: step))
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(Theme.paper2)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 20)
                        .background(Theme.sage, in: Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Theme.paper2)
                .shadow(color: Theme.ink.opacity(0.18), radius: 24, y: 8)
        )
    }

    @ViewBuilder
    private func liveSlouchContent(step: TrainingTourStep) -> some View {
        if slouchFelt {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.sage)
                Text("Felt it?")
                    .font(Theme.display(20))
                    .foregroundStyle(Theme.ink)
            }
            Text("That gentle buzz is the whole product. Straighten up and Posture goes quiet again. It only nudges after ~25 seconds of real slouching, never for a glance at your keyboard.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        } else if liveQuality != nil {
            Text(step.title)
                .font(Theme.display(20))
                .foregroundStyle(Theme.ink)
            Text(step.body)
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ProgressView().tint(Theme.sage)
                Text("Watching for your slouch…")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(Theme.ink3)
            }
        } else {
            Text(step.title)
                .font(Theme.display(20))
                .foregroundStyle(Theme.ink)
            Text("Pop your AirPods in first, then try it. You can also come back to this any time from Settings.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func nextLabel(step: TrainingTourStep) -> String {
        if index == steps.count - 1 { return "Done" }
        if step.isLiveSlouchStep && !slouchFelt && liveQuality != nil { return "Skip this" }
        return "Next"
    }

    private func advance() {
        if index >= steps.count - 1 {
            onFinish()
        } else {
            withAnimation(.easeInOut(duration: 0.22)) { index += 1 }
        }
    }
}
