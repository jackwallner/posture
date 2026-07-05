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

    private let lastPage = 3

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcomePage.tag(0)
                shapePage.tag(1)
                standingPage.tag(2)
                sittingPage.tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            pageDots
                .padding(.top, 4)

            Button {
                if page < lastPage {
                    withAnimation { page += 1 }
                } else {
                    settings.hasAirpods = true
                    settings.hasCompletedOnboarding = true
                }
            } label: {
                Text(page < lastPage ? "Continue" : "Set up my baseline")
            }
            .buttonStyle(.daylight(.primary))
            .padding(.horizontal, 24)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .dawnBackground()
    }

    // MARK: - Pages

    private var welcomePage: some View {
        pageScaffold {
            Text("Welcome to Posture.")
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)

            Text("A hands-free posture coach for AirPods. Your earbuds read your alignment all day, so you never have to glance at your phone to know how you're sitting.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            VStack(spacing: 14) {
                pillarCard(index: "1", title: "Learn the shape", body: "First, what tall actually feels like, standing and sitting.", accent: Theme.lavender)
                pillarCard(index: "2", title: "Calibrate once", body: "Your AirPods record your aligned posture in a few steady seconds.", accent: Theme.sage)
                pillarCard(index: "3", title: "Quiet nudges all day", body: "We notice when you drift and nudge you, gently. No screens, no scolding.", accent: Theme.sand)
            }
            .padding(.top, 8)
        }
    }

    private var shapePage: some View {
        pageScaffold {
            Text("What good posture is.")
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)

            PoseDiagram(pose: .stack, height: 170)

            Text("Tall posture is a stack, not a strain. Line these up and let everything else relax.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            VStack(spacing: 14) {
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
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)

            PoseDiagram(pose: .standing, height: 170)

            Text("Try it now. We'll capture this pose in a moment, so build it once here.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            VStack(spacing: 14) {
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
                .font(.system(size: 36, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.ink)

            PoseDiagram(pose: .sitting, height: 170)

            Text("Where most of the slouching happens. Same long spine, different base.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(Theme.ink)
                .lineSpacing(3)

            VStack(spacing: 14) {
                cueCard(icon: "chair", title: "Hips to the back", body: "Sit back so your hips fill the seat and your back has support.")
                cueCard(icon: "shoeprints.fill", title: "Feet flat", body: "Both feet on the floor, knees roughly level with your hips.")
                cueCard(icon: "arrow.up", title: "Grow tall", body: "Lengthen up through the crown, ears over shoulders, chin level.")
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Building blocks

    private func pageScaffold<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                content()
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
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
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
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
                    .foregroundStyle(Theme.sage)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.body, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(body)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .dawnCard()
    }
}
