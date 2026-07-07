import SwiftUI

/// Focused trial pitch when a user flips a locked Posture+ toggle — mirrors the
/// Vitals trial sheet: drifting glow, sparkle field, headline shimmer, hero pulse.
struct TrialOfferSheet: View {
    let focus: PosturePlusFeature?
    let offerLabel: String?
    let priceLabel: String?
    let directPurchase: Bool
    let isPurchasing: Bool
    let errorMessage: String?
    let onStartTrial: () -> Void
    let onSeeAllPlans: () -> Void
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateGlow = false
    @State private var shimmerPhase: CGFloat = -1

    private var headline: String {
        if let focus { return focus.intentHeadline }
        if let offerLabel { return "\(offerLabel.capitalized), on us." }
        return "Try Posture+ free."
    }

    private var subheadline: String {
        if let focus {
            if offerLabel != nil {
                return "\(focus.intentSubheadline) Free for 7 days. Cancel anytime."
            }
            return focus.intentSubheadline
        }
        return offerLabel != nil
            ? "The full ladder, walks, trends, and all-day monitoring. No charge until your trial ends."
            : "The full ladder, walks, trends, and all-day monitoring."
    }

    private var bulletFeatures: [PosturePlusFeature] {
        if let focus { return [focus] + focus.companionFeatures }
        return [.alwaysOnWatch, .airpodsBackground]
    }

    private var glowAnimation: Animation {
        .easeInOut(duration: 2.2).repeatForever(autoreverses: true)
    }

    private var shimmerAnimation: Animation {
        .linear(duration: 2.6).repeatForever(autoreverses: false).delay(0.4)
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Theme.sage, Theme.lavender.opacity(0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// A brighter, higher-contrast gradient for the primary CTA - the muted
    /// hero gradient read as low-energy on the button. Vivid green into the
    /// ritual lavender pops against the pale sheet and says "tap me".
    private var ctaGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.216, green: 0.792, blue: 0.545), // vivid green
                Color(red: 0.416, green: 0.671, blue: 0.898)  // bright sky-blue
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            Circle()
                .fill(Theme.sage.opacity(0.2))
                .frame(width: 220, height: 220)
                .blur(radius: 36)
                .offset(x: animateGlow ? 96 : -96, y: animateGlow ? -220 : -180)
                .animation(glowAnimation, value: animateGlow)
            Circle()
                .fill(Theme.lavender.opacity(0.18))
                .frame(width: 180, height: 180)
                .blur(radius: 34)
                .offset(x: animateGlow ? -110 : 110, y: animateGlow ? 250 : 210)
                .animation(glowAnimation, value: animateGlow)
            if !reduceMotion {
                TrialSparkleField(phase: animateGlow ? 1 : 0)
                    .allowsHitTesting(false)
                    .opacity(0.55)
                    .animation(glowAnimation, value: animateGlow)
            }

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(heroGradient)
                        .frame(width: 60, height: 60)
                        .shadow(color: Theme.sage.opacity(0.4), radius: 12, x: 0, y: 4)
                        .scaleEffect(animateGlow ? 1.06 : 0.96)
                    Circle()
                        .stroke(.white.opacity(0.35), lineWidth: 1)
                        .frame(width: 50, height: 50)
                        .scaleEffect(animateGlow ? 1.03 : 0.98)
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(animateGlow ? 6 : -6))
                }
                .padding(.top, 4)
                .animation(glowAnimation, value: animateGlow)

                VStack(spacing: 4) {
                    Text(headline)
                        .font(Theme.display(24))
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .overlay(shimmerOverlay)
                        .mask(
                            Text(headline)
                                .font(Theme.display(24))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        )
                    Text(subheadline)
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.ink2)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)
                }

                VStack(spacing: 6) {
                    ForEach(bulletFeatures, id: \.self) { feature in
                        TrialBulletRow(
                            icon: feature.icon,
                            tint: feature.tint,
                            title: feature.title,
                            detail: feature.detail,
                            highlighted: feature == focus,
                            compact: focus != nil && feature != focus
                        )
                    }
                }

                Group {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Theme.font(.footnote))
                            .foregroundStyle(Theme.badText)
                            .multilineTextAlignment(.center)
                            .transition(.opacity)
                    }
                }
                .animation(.easeInOut(duration: 0.18), value: errorMessage)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.horizontal, 24)
            .padding(.top, 6)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 8) {
                    if directPurchase, let priceLabel {
                        Text("Free during trial, then \(priceLabel). Auto-renews unless cancelled 24h before trial ends.")
                            .font(Theme.font(.caption2))
                            .foregroundStyle(Theme.ink2)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Button(action: onStartTrial) {
                        ZStack {
                            HStack(spacing: 8) {
                                Text("Start My Free Trial")
                                    .font(Theme.font(.headline, weight: .bold))
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .opacity(isPurchasing ? 0 : 1)
                            if isPurchasing {
                                ProgressView().tint(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ctaGradient, in: Capsule())
                        .overlay(
                            Capsule()
                                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: Theme.sage.opacity(0.55), radius: 16, x: 0, y: 6)
                        .scaleEffect(reduceMotion ? 1 : (animateGlow ? 1.02 : 0.99))
                        .animation(glowAnimation, value: animateGlow)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing)

                    if directPurchase {
                        Button(action: onSeeAllPlans) {
                            Text("See all plans")
                                .font(Theme.font(.subheadline, weight: .semibold))
                                .foregroundStyle(Theme.goodText)
                        }
                        .buttonStyle(.plain)
                        .disabled(isPurchasing)
                    }

                    Button(action: onDismiss) {
                        Text("Not now")
                            .font(Theme.font(.subheadline, weight: .semibold))
                            .foregroundStyle(Theme.ink2)
                    }
                    .buttonStyle(.plain)
                    .disabled(isPurchasing)

                    HStack(spacing: 4) {
                        Link("Terms", destination: PaywallLinks.standardEULA)
                        Text("·")
                        Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
                    }
                    .font(Theme.font(.caption2))
                    .foregroundStyle(Theme.ink3)
                }
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 12)
                .background(.ultraThinMaterial)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            guard !reduceMotion else { return }
            animateGlow = true
            shimmerPhase = 1.4
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .white.opacity(0.55), location: 0.5),
                    .init(color: .clear, location: 1.0)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.5)
            .offset(x: shimmerPhase * width)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
            .animation(shimmerAnimation, value: shimmerPhase)
        }
    }
}

private struct TrialBulletRow: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String
    var highlighted: Bool = false
    var compact: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: compact ? 10 : 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.18))
                    .frame(width: compact ? 28 : 34, height: compact ? 28 : 34)
                Image(systemName: icon)
                    .font(.system(size: compact ? 13 : 15, weight: .semibold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.font(compact ? .footnote : .subheadline, weight: .semibold))
                    .foregroundStyle(Theme.ink)
                if !compact {
                    Text(detail)
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, compact ? 10 : 12)
        .padding(.vertical, compact ? 7 : 10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(highlighted ? tint.opacity(0.12) : Theme.paper2.opacity(0.55))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(tint.opacity(highlighted ? 0.45 : 0.18), lineWidth: highlighted ? 1.5 : 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(detail)")
    }
}

/// Ambient shine particles behind the hero — same lifecycle as Vitals' SparkleField.
private struct TrialSparkleField: View {
    let phase: CGFloat

    private struct Sparkle: Identifiable {
        let id: Int
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let driftX: CGFloat
        let driftY: CGFloat
        let opacity: Double
        let phaseOffset: CGFloat
    }

    private static let sparkles: [Sparkle] = (0..<14).map { i in
        let seed = Double(i) * 12.9898
        let r1 = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
        let r2 = (sin(seed + 1) * 43758.5453).truncatingRemainder(dividingBy: 1)
        let r3 = (sin(seed + 2) * 43758.5453).truncatingRemainder(dividingBy: 1)
        let r4 = (sin(seed + 3) * 43758.5453).truncatingRemainder(dividingBy: 1)
        return Sparkle(
            id: i,
            x: CGFloat(abs(r1)) * 320 - 160,
            y: CGFloat(abs(r2)) * 460 - 230,
            size: 2 + CGFloat(abs(r3)) * 3,
            driftX: CGFloat(r4) * 12,
            driftY: CGFloat(r3 - 0.5) * 18,
            opacity: 0.35 + abs(r2) * 0.5,
            phaseOffset: CGFloat(abs(r1))
        )
    }

    var body: some View {
        ZStack {
            ForEach(Self.sparkles) { sparkle in
                Circle()
                    .fill(.white)
                    .frame(width: sparkle.size, height: sparkle.size)
                    .opacity(sparkle.opacity * (0.4 + 0.6 * Double(abs(sin(.pi * (phase + sparkle.phaseOffset))))))
                    .offset(x: sparkle.x + sparkle.driftX * phase,
                            y: sparkle.y + sparkle.driftY * phase)
                    .blur(radius: 0.4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
