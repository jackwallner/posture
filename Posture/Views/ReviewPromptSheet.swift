import SwiftUI
import UIKit

@MainActor
final class ReviewPromptCoordinator: ObservableObject {
    static let shared = ReviewPromptCoordinator()

    enum Presentation {
        case enjoymentPrompt
        case feedbackOnly
    }

    @Published var pendingPresentation: Presentation?

    private init() {}

    func requestEnjoymentPrompt() {
        pendingPresentation = .enjoymentPrompt
    }

    func requestFeedback() {
        pendingPresentation = .feedbackOnly
    }

    func clear() {
        pendingPresentation = nil
    }
}

enum ReviewPromptDismissOutcome: Sendable {
    case notNow
    case feedbackSubmitted
    case openedWriteReview
    case enjoyedMaybeLater
}

struct ReviewPromptSheet: View {
    enum Step {
        case enjoyment
        case reviewPitch
        case feedback
    }

    let initialStep: Step
    let onFinish: (ReviewPromptDismissOutcome) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var step: Step
    @State private var feedbackText = ""
    @FocusState private var feedbackFocused: Bool

    init(initialStep: Step = .enjoyment, onFinish: @escaping (ReviewPromptDismissOutcome) -> Void) {
        self.initialStep = initialStep
        self.onFinish = onFinish
        _step = State(initialValue: initialStep)
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .enjoyment:
                    enjoymentContent
                case .reviewPitch:
                    reviewPitchContent
                case .feedback:
                    feedbackContent
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") {
                        handleNotNow()
                    }
                    .foregroundStyle(Theme.ink2)
                }
            }
        }
        .presentationDetents(step == .feedback ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .dawnBackground()
    }

    private var navigationTitle: String {
        switch step {
        case .enjoyment: "Enjoying Posture?"
        case .reviewPitch: "Support an indie app"
        case .feedback: "Help us improve"
        }
    }

    private var enjoymentContent: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.sageTint)
                    .frame(width: 64, height: 64)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.sage)
            }
            .padding(.top, 8)

            Text("If Posture is helping you sit taller through the day, a quick App Store rating helps more people find a gentle posture habit.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Button { step = .reviewPitch } label: {
                    Text("Yes, I'm enjoying it")
                }
                .buttonStyle(.plain)
                .daylightCTA(.primary)

                Button { step = .feedback } label: {
                    Text("Not really")
                }
                .buttonStyle(.plain)
                .daylightCTA(.ghost)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var reviewPitchContent: some View {
        VStack(spacing: 18) {
            Text("Posture is built by one indie developer — no ads, no accounts, and your camera frames never leave your phone.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Text("An honest review takes seconds and helps others discover a quiet daily posture ritual.")
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Theme.ink3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            VStack(spacing: 10) {
                Button {
                    ReviewPromptTracker.markOpenedWriteReview()
                    UIApplication.shared.open(AppStoreReviewLinks.writeReviewURL)
                    finish(.openedWriteReview)
                } label: {
                    Text("Rate on the App Store")
                }
                .buttonStyle(.plain)
                .daylightCTA(.primary)

                Button {
                    ReviewPromptTracker.markShown()
                    finish(.enjoyedMaybeLater)
                } label: {
                    Text("Maybe later")
                }
                .buttonStyle(.plain)
                .daylightCTA(.ghost)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var feedbackContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What would make Posture work better for you?")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $feedbackText)
                .font(.system(.body, design: .rounded))
                .frame(minHeight: 140)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Theme.paper3, in: RoundedRectangle(cornerRadius: 12))
                .focused($feedbackFocused)

            Text("Opens your mail app with a draft to the developer. No analytics — just your words.")
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(Theme.ink3)

            Button { sendFeedback() } label: {
                Text("Send feedback")
            }
            .buttonStyle(.plain)
            .daylightCTA(.primary)
            .disabled(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onAppear { feedbackFocused = true }
    }

    private func handleNotNow() {
        ReviewPromptTracker.markShown()
        finish(.notNow)
    }

    private func sendFeedback() {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = Self.feedbackMailURL(body: trimmed) else { return }
        ReviewPromptTracker.markFeedbackSubmitted()
        UIApplication.shared.open(url)
        finish(.feedbackSubmitted)
    }

    private func finish(_ outcome: ReviewPromptDismissOutcome) {
        onFinish(outcome)
        dismiss()
    }

    static func feedbackMailURL(body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "jackwallner@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Posture feedback"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
