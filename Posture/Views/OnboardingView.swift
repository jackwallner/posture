import SwiftUI

/// Onboarding teaches what good posture actually is, standing and sitting,
/// before we ask AirPods to measure it. A steady mental model first means the
/// calibration reads that follow are honest ones. Tapping through to the end
/// flips the install state; the next gate (AirPods calibration) handles the
/// "do you actually have compatible AirPods" question with its own waiting /
/// unsupported UI.
struct OnboardingView: View {
    @Environment(GoalSettings.self) private var settings
    @State private var page = 0
    @State private var focus: PostureFocus = .both

    private let lastPage = 4

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                focusPage.tag(1)
                shapePage.tag(2)
                standingPage.tag(3)
                sittingPage.tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            // Shared bottom bar: primary CTA bottom-pinned above a fixed-height
            // legal-footer slot (invisible placeholder here) so its geometry is
            // byte-identical to the trial page's "Start … free trial" button.
            OnboardingBottomBar(
                primaryTitle: page < lastPage ? "Continue" : "Set up my baseline",
                primaryAction: {
                    if page < lastPage {
                        withAnimation { page += 1 }
                    } else {
                        settings.postureFocus = focus
                        settings.hasAirpods = true
                        settings.hasCompletedOnboarding = true
                    }
                },
                footer: OnboardingLegalFooter(isPlaceholder: true)
            ) {
                pageDots
                    .padding(.top, 4)
            }
        }
        .dawnBackground()
    }

    // MARK: - Pages

    private var welcomePage: some View {
        pageScaffold {
            Text("Welcome to Posture.")
                .font(Theme.font(size: 42, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text("A daily posture practice, coached by your AirPods. A few minutes held tall each day, with live feedback, that's how posture actually changes.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            VStack(spacing: 10) {
                pillarCard(index: "1", title: "Learn the shape", body: "First, what tall actually feels like, standing and sitting.", accent: Theme.lavender)
                pillarCard(index: "2", title: "Calibrate once", body: "Your AirPods record your aligned posture in a few steady seconds.", accent: Theme.sage)
                pillarCard(index: "3", title: "Practice daily", body: "One short session a day, starting at three minutes. Streaks and levels keep it growing.", accent: Theme.sand)
            }
            .padding(.top, 8)
        }
    }

    private var focusPage: some View {
        pageScaffold {
            Text("What do you want to fix?")
                .font(Theme.font(size: 36, weight: .semibold))
                .foregroundStyle(Theme.ink)

            Text("We'll capture both, but coaching leans where you need it.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            VStack(spacing: 10) {
                focusCard(.sitting, icon: "chair", title: "Sitting posture", body: "Desk slouch, laptop hunch, couch collapse.")
                focusCard(.standing, icon: "figure.stand", title: "Standing posture", body: "Forward head, rounded shoulders on your feet.")
                focusCard(.both, icon: "arrow.up.and.down.circle", title: "Both", body: "The full picture, sitting and standing.")
            }
            .padding(.top, 8)
        }
    }

    private func focusCard(_ value: PostureFocus, icon: String, title: String, body: String) -> some View {
        let selected = focus == value
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { focus = value }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(selected ? Theme.goodText : Theme.sageTint)
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(selected ? .white : Theme.goodText)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.font(.body, weight: .semibold))
                        .foregroundStyle(Theme.ink)
                    Text(body)
                        .font(Theme.font(.subheadline))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(selected ? Theme.goodText : Theme.ink3.opacity(0.4))
            }
            .padding(14)
            .dawnCard()
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(selected ? Theme.sage : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private var shapePage: some View {
        pageScaffold {
            Text("What good posture is.")
                .font(Theme.font(size: 36, weight: .semibold))
                .foregroundStyle(Theme.ink)

            PoseDiagram(pose: .stack, height: 132)

            Text("Tall posture is a stack, not a strain. Line these up and let everything else relax.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            VStack(spacing: 10) {
                cueCard(icon: "arrow.up", title: "Lengthen up", body: "Imagine a thread lifting the crown of your head toward the ceiling.")
                cueCard(icon: "ear", title: "Ears over shoulders", body: "Let your head float back over your spine, not out in front of it.")
                cueCard(icon: "figure.stand", title: "Shoulders over hips", body: "Roll your shoulders down and back. Chest open, chin level.")
            }
            .padding(.top, 8)
        }
    }

    private var standingPage: some View {
        pageScaffold {
            Text("Standing tall.")
                .font(Theme.font(size: 36, weight: .semibold))
                .foregroundStyle(Theme.ink)

            PoseDiagram(pose: .standing, height: 132)

            Text("Try it now. We'll capture this pose in a moment, so build it once here.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            VStack(spacing: 10) {
                cueCard(icon: "figure.walk", title: "Weight balanced", body: "Feet hip-width apart, weight even across both feet. Soft knees.")
                cueCard(icon: "arrow.up.and.down", title: "Stack up", body: "Hips over ankles, shoulders over hips, ears over shoulders.")
                cueCard(icon: "wind", title: "Breathe and settle", body: "Drop your shoulders on an exhale. This relaxed-tall is your baseline.")
            }
            .padding(.top, 8)
        }
    }

    private var sittingPage: some View {
        pageScaffold {
            Text("Sitting tall.")
                .font(Theme.font(size: 36, weight: .semibold))
                .foregroundStyle(Theme.ink)

            PoseDiagram(pose: .sitting, height: 132)

            Text("Where most of the slouching happens. Same long spine, different base.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            VStack(spacing: 10) {
                cueCard(icon: "chair", title: "Hips to the back", body: "Sit back so your hips fill the seat and your back has support.")
                cueCard(icon: "shoeprints.fill", title: "Feet flat", body: "Both feet on the floor, knees roughly level with your hips.")
                cueCard(icon: "arrow.up", title: "Grow tall", body: "Lengthen up through the crown, ears over shoulders, chin level.")
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Building blocks

    /// Center the page's content and give it the full viewport height, so a
    /// page that fits never scrolls. The ScrollView stays only as a backup for
    /// the largest text sizes / smallest devices - it's not the default reading
    /// mode. Tighter spacing than before keeps every page on one screen.
    private func pageScaffold<Content: View>(@ViewBuilder _ content: @escaping () -> Content) -> some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content()
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .center)
            }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0...lastPage, id: \.self) { i in
                Circle()
                    .fill(i == page ? Theme.sage : Theme.ink3.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
    }

    private func pillarCard(index: String, title: String, body: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 36, height: 36)
                Text(index)
                    .font(Theme.font(.subheadline, weight: .semibold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.font(.body, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .dawnCard()
    }

    private func cueCard(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.sageTint)
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.goodText)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.font(.body, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(Theme.font(.subheadline))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .dawnCard()
    }
}
