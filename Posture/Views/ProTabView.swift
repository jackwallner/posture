import SwiftUI

/// The Posture+ tab for non-subscribers — the paywall itself, not a pitch page.
/// Disappears the moment a purchase lands.
struct ProTabView: View {
    var body: some View {
        PaywallView(displayCloseButton: false, paywallImpressionId: "posture_pro_tab")
    }
}
