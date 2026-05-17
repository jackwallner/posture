import SwiftUI
#if HAS_REVENUECAT
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
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("POSTURE+")
                        .font(.caption.weight(.semibold))
                        .tracking(2)
                        .foregroundStyle(Theme.ink3)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.ink3)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }

                Text("The long way is\nthe only way.")
                    .font(Theme.displaySerif(34))
                    .foregroundStyle(Theme.ink)

                Text("Posture+ adds the parts of the practice you only see after a few weeks.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.ink2)

                YourJulyPostcard()

                VStack(alignment: .leading, spacing: 0) {
                    includedRow("24-hour rhythm — when you slip, hour by hour")
                    includedRow("Quiet AirPods background monitoring")
                    includedRow("Every month kept — free shows a week", isLast: true)
                }
                .padding(.top, 4)

                if let error = purchaseError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Theme.clay)
                }

                Button {
                    guard !isPurchasing else { return }
                    isPurchasing = true
                    purchaseError = nil
                    Task { await purchaseYearly(); isPurchasing = false }
                } label: {
                    HStack(spacing: 8) {
                        if isPurchasing { ProgressView().tint(Theme.paper) }
                        Text("try 7 days · then $29.99 / year")
                    }
                }
                .buttonStyle(.plain)
                .daylightCTA(.primary)
                .disabled(isPurchasing)
                .padding(.top, 4)

                HStack(spacing: 14) {
                    Text("or $4.99 / month")
                        .font(.caption)
                        .foregroundStyle(Theme.ink3)
                    Spacer()
                    Button("restore") {
                        restoreAttempted = true
                        purchaseError = nil
                        Task {
                            #if HAS_REVENUECAT
                            do {
                                try await Purchases.shared.restorePurchases()
                                await subscriptions.refresh()
                            } catch {
                                purchaseError = "Could not restore purchases. Please try again."
                            }
                            #endif
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.ink2)
                    Text("·").foregroundStyle(Theme.ink3)
                    Button("maybe later") { dismiss() }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.ink2)
                }
                .buttonStyle(.plain)

                if restoreAttempted && !subscriptions.isProSubscriber {
                    Text("No purchases found to restore.")
                        .font(.caption)
                        .foregroundStyle(Theme.ink3)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .background(Theme.paper.ignoresSafeArea())
        .onAppear { AnalyticsService.paywallShown() }
    }

    private func includedRow(_ text: String, isLast: Bool = false) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Text("·")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.sage)
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 14)
            if !isLast { Divider().background(Theme.paper3) }
        }
    }

    private func purchaseMonthly() async {
        AnalyticsService.purchaseAttempted(plan: "monthly")
        #if HAS_REVENUECAT
        do {
            guard let offerings = try? await Purchases.shared.offerings(),
                  let monthly = offerings.current?.monthly
            else {
                purchaseError = "Subscription plans aren't available right now. Try again later."
                return
            }
            let result = try await Purchases.shared.purchase(package: monthly)
            if result.userCancelled { purchaseError = nil; return }
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
        #if HAS_REVENUECAT
        do {
            guard let offerings = try? await Purchases.shared.offerings(),
                  let yearly = offerings.current?.annual
            else {
                purchaseError = "Subscription plans aren't available right now. Try again later."
                return
            }
            let result = try await Purchases.shared.purchase(package: yearly)
            if result.userCancelled { purchaseError = nil; return }
            AnalyticsService.purchaseCompleted(plan: "yearly")
            await subscriptions.refresh()
            dismiss()
        } catch {
            purchaseError = "Purchase didn't complete. Please try again."
        }
        #endif
    }
}

/// A synthetic 30-day "preview" of a Pro month — deliberately not real
/// data (avoids any before/after medical-claim reading). A 14-day
/// contiguous stretch is outlined.
private struct YourJulyPostcard: View {
    // Deterministic synthetic month: mostly aligned with a few dips.
    private let bars: [PostureQuality] = {
        var out: [PostureQuality] = []
        for i in 0..<30 {
            switch i {
            case 3, 9, 21: out.append(.bad)
            case 1, 7, 14, 24, 27: out.append(.borderline)
            default: out.append(.good)
            }
        }
        return out
    }()

    private let stretchRange = 10...23  // the "14 day stretch"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("YOUR JULY · A PREVIEW")
                    .font(.caption.weight(.semibold))
                    .tracking(2)
                    .foregroundStyle(Theme.ink3)
                Spacer()
                Text("84% aligned")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.sage)
            }

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<30, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.qualityColor(bars[i]))
                        .frame(maxWidth: .infinity)
                        .frame(height: barHeight(bars[i]))
                }
            }
            .frame(height: 56)
            .overlay(alignment: .leading) { stretchOutline }

            HStack {
                Text("JUL 1").font(.caption2).foregroundStyle(Theme.ink3)
                Spacer()
                Text("14 DAY STRETCH").font(.caption2.weight(.semibold)).foregroundStyle(Theme.ink2)
                Spacer()
                Text("JUL 30").font(.caption2).foregroundStyle(Theme.ink3)
            }
        }
        .padding(16)
        .background(Theme.paper2, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.paper3, lineWidth: 1))
    }

    private var stretchOutline: some View {
        GeometryReader { geo in
            let barW = geo.size.width / 30
            let x = barW * CGFloat(stretchRange.lowerBound)
            let w = barW * CGFloat(stretchRange.count)
            RoundedRectangle(cornerRadius: 4)
                .stroke(Theme.ink, lineWidth: 1.5)
                .frame(width: w, height: geo.size.height + 6)
                .offset(x: x - 3, y: -3)
        }
    }

    private func barHeight(_ q: PostureQuality) -> CGFloat {
        switch q {
        case .good: return 56
        case .borderline: return 38
        case .bad: return 22
        }
    }
}
