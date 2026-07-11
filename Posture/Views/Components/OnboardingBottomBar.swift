import SwiftUI

/// The shared bottom action bar for the onboarding card flow **and** the
/// onboarding trial page.
///
/// Rev A (OT710) contract: the primary CTA must occupy byte-identical geometry
/// (x, y, width, height) on every onboarding page and on the trial page so the
/// user's thumb never moves as the label switches from "Continue" to "Start …
/// free trial". This is guaranteed structurally:
///
/// - The primary is bottom-pinned above a **fixed-height legal-footer slot**
///   rendered on *every* page. On the trial page it holds the real
///   Terms/Privacy/Restore links; on the onboarding cards it renders the exact
///   same view, hidden (`opacity 0` + no hit testing + AX hidden), so its
///   height is identical to the pixel.
/// - All page-specific, variable-height content (page dots, soft exit,
///   disclosure, error text) lives in the `above` slot, where it expands
///   upward into the flexible region and can never move the button.
///
/// Both `OnboardingView` and `OnboardingTrialView` use the same button style
/// (`.daylight(.primary)` → maxWidth-infinity, height 56, `Theme.ctaRadius`),
/// the same horizontal inset (24) and bottom padding (28), so width, height and
/// radius already match; this bar makes the y-position match too.
struct OnboardingBottomBar<Above: View>: View {
    let primaryTitle: String
    var isBusy: Bool = false
    var isDisabled: Bool = false
    let primaryAction: () -> Void
    /// The legal footer. Pass `OnboardingLegalFooter(isPlaceholder: true)` on
    /// the onboarding cards so the reserved slot is invisible but identical in
    /// height; pass a live footer on the trial page.
    let footer: OnboardingLegalFooter
    @ViewBuilder var above: () -> Above

    var body: some View {
        VStack(spacing: 0) {
            above()

            Button(action: primaryAction) {
                ZStack {
                    Text(primaryTitle)
                        .frame(maxWidth: .infinity)
                        .opacity(isBusy ? 0 : 1)
                    if isBusy {
                        ProgressView().tint(Theme.ink)
                    }
                }
            }
            .buttonStyle(.daylight(.primary))
            .disabled(isDisabled)
            .padding(.top, 16)

            footer
                .padding(.top, 12)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 28)
    }
}

/// The Terms / Privacy / Restore row that anchors the bottom bar. The same view
/// is rendered on every onboarding page so the reserved footer slot is exactly
/// the same height; `isPlaceholder` hides it on the non-trial cards.
struct OnboardingLegalFooter: View {
    var isPlaceholder: Bool = false
    var isRestoring: Bool = false
    var onRestore: () -> Void = {}

    var body: some View {
        HStack(spacing: 14) {
            Button(action: onRestore) {
                Text(isRestoring ? "Restoring…" : "Restore Purchases")
                    .font(Theme.font(.caption2, weight: .semibold))
                    .foregroundStyle(Theme.ink2)
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)

            HStack(spacing: 4) {
                Link("Terms of Use", destination: PaywallLinks.standardEULA)
                Text("·")
                Link("Privacy Policy", destination: PaywallLinks.privacyPolicy)
            }
            .font(Theme.font(.caption2, weight: .semibold))
            .foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .opacity(isPlaceholder ? 0 : 1)
        .allowsHitTesting(!isPlaceholder)
        .accessibilityHidden(isPlaceholder)
    }
}
