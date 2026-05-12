import SwiftUI
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptions = SubscriptionService.shared
    @State private var restoreAttempted: Bool = false

    var body: some View {
        #if canImport(RevenueCatUI)
        if subscriptions.isConfigured {
            RevenueCatUI.PaywallView(displayCloseButton: true)
                .onPurchaseCompleted { _ in
                    Task { await subscriptions.refresh() }
                    dismiss()
                }
                .onRestoreCompleted { _ in
                    Task { await subscriptions.refresh() }
                    dismiss()
                }
        } else {
            placeholderPaywall
        }
        #else
        placeholderPaywall
        #endif
    }

    private var placeholderPaywall: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 24)

                Image(systemName: "crown.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.brandGradient)

                Text("Posture Pro")
                    .font(Theme.bigNumber(34))

                Text("Always-on protection against tech neck.")
                    .font(.headline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 14) {
                    BenefitRow(icon: "applewatch.radiowaves.left.and.right",
                               title: "Always-on Watch monitoring",
                               detail: "Continuous wrist tracking + haptic nudges.")
                    BenefitRow(icon: "chart.bar.xaxis",
                               title: "All-day timeline + heatmap",
                               detail: "See exactly when your posture slips.")
                    BenefitRow(icon: "camera.fill",
                               title: "Before/after photo analysis",
                               detail: "Track measurable head-forward angle change.")
                    BenefitRow(icon: "infinity",
                               title: "Unlimited history",
                               detail: "Free is 7 days; Pro keeps everything.")
                }
                .padding(.horizontal, 24)

                VStack(spacing: 8) {
                    Text("$4.99 / month · $29.99 / year · $79.99 lifetime")
                        .font(.caption)
                        .foregroundStyle(Theme.textTertiary)
                }

                Button {
                    restoreAttempted = true
                    Task { await subscriptions.refresh() }
                } label: {
                    Text("Restore Purchases")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.cardSurface, in: .rect(cornerRadius: 14))
                        .foregroundStyle(Theme.brandPrimary)
                }
                .padding(.horizontal, 32)

                if restoreAttempted && !subscriptions.isProSubscriber {
                    Text("No purchases found to restore.")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }

                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.cardSurface, in: .rect(cornerRadius: 14))
                        .foregroundStyle(Theme.textPrimary)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }
}

private struct BenefitRow: View {
    let icon: String
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Theme.brandPrimary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }
}
