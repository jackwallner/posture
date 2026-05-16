import SwiftUI
#if canImport(RevenueCat)
import RevenueCat
#endif
#if canImport(RevenueCatUI)
import RevenueCatUI
#endif

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptions = SubscriptionService.shared
    @State private var restoreAttempted: Bool = false
    @State private var isPurchasing: Bool = false
    @State private var purchaseError: String?

    private var priceText: String {
        guard subscriptions.isConfigured else {
            return "$4.99 / month · $29.99 / year · $79.99 lifetime"
        }
        // In production, pull from RevenueCat offerings
        return "Monthly or annual — cancel anytime"
    }

    var body: some View {
        #if canImport(RevenueCatUI)
        if subscriptions.isConfigured {
            RevenueCatUI.PaywallView(displayCloseButton: true)
                .onAppear { AnalyticsService.paywallShown() }
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

                if let error = purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.bad)
                        .padding(.horizontal, 32)
                }

                purchaseButton("Subscribe Monthly · $4.99") {
                    await purchaseMonthly()
                }
                .padding(.horizontal, 32)

                purchaseButton("Subscribe Yearly · $29.99") {
                    await purchaseYearly()
                }
                .padding(.horizontal, 32)

                Text("Free trial included with annual. Cancel anytime.")
                    .font(.caption2)
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.horizontal, 32)

                Button {
                    restoreAttempted = true
                    purchaseError = nil
                    Task {
                        do {
                            #if canImport(RevenueCat)
                            try await Purchases.shared.restorePurchases()
                            await subscriptions.refresh()
                            #endif
                        } catch {
                            purchaseError = "Could not restore purchases. Please try again."
                        }
                    }
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
                    Text("Maybe Later")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.bottom, 32)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .onAppear { AnalyticsService.paywallShown() }
    }

    private func purchaseButton(_ label: String, action: @escaping () async -> Void) -> some View {
        Button {
            guard !isPurchasing else { return }
            isPurchasing = true
            purchaseError = nil
            Task {
                await action()
                isPurchasing = false
            }
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .tint(.white)
                }
                Text(label)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.brandGradient, in: .rect(cornerRadius: 14))
            .foregroundStyle(.white)
        }
        .disabled(isPurchasing)
    }

    private func purchaseMonthly() async {
        AnalyticsService.purchaseAttempted(plan: "monthly")
        #if canImport(RevenueCat)
        do {
            guard let offerings = try? await Purchases.shared.offerings(),
                  let monthly = offerings.current?.monthly
            else {
                purchaseError = "Subscription plans aren't available right now. Try again later."
                return
            }
            let result = try await Purchases.shared.purchase(package: monthly)
            if result.userCancelled {
                purchaseError = nil
                return
            }
            AnalyticsService.purchaseCompleted(plan: "monthly")
            await subscriptions.refresh()
            dismiss()
        } catch {
            purchaseError = "Purchase didn't complete. Please try again."
        }
        #endif
    }

    private func purchaseYearly() async {
        AnalyticsService.purchaseAttempted(plan: "yearly")
        #if canImport(RevenueCat)
        do {
            guard let offerings = try? await Purchases.shared.offerings(),
                  let yearly = offerings.current?.annual
            else {
                purchaseError = "Subscription plans aren't available right now. Try again later."
                return
            }
            let result = try await Purchases.shared.purchase(package: yearly)
            if result.userCancelled {
                purchaseError = nil
                return
            }
            AnalyticsService.purchaseCompleted(plan: "yearly")
            await subscriptions.refresh()
            dismiss()
        } catch {
            purchaseError = "Purchase didn't complete. Please try again."
        }
        #endif
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
