import SwiftData
import SwiftUI

/// Keep data-dependent views and services behind a successful disk-store open.
struct StorageContainerView<Content: View>: View {
    @State private var result = DataService.containerResult
    @ViewBuilder var content: () -> Content

    var body: some View {
        switch result {
        case .success(let container):
            content()
                .modelContainer(container)
        case .failure:
            VStack(spacing: 16) {
                Text("Your history is unavailable")
                    .font(Theme.font(.headline, weight: .bold))
                Text("Posture couldn't open your saved data. Your files have been kept. Try again after unlocking your device or freeing up storage.")
                    .font(Theme.font(.body))
                Button("Try again") {
                    DataService.retry()
                    result = DataService.containerResult
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.sage)
            }
            .multilineTextAlignment(.center)
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(Theme.ink)
            .background(Theme.paper)
        }
    }
}
