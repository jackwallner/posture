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
    /// Mail refused to open (no mail client / no account). Offer the address.
    @State private var mailFailed = false
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
                    .foregroundStyle(Theme.goodText)
            }
            .padding(.top, 8)

            Text("If Posture is helping you sit taller through the day, a quick App Store rating helps more people find a gentle posture habit.")
                .font(Theme.font(.subheadline))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            VStack(spacing: 10) {
                Button { step = .reviewPitch } label: {
                    Text("Yes, I'm enjoying it")
                }
                .buttonStyle(.daylight(.primary))

                Button { step = .feedback } label: {
                    Text("Not really")
                }
                .buttonStyle(.daylight(.ghost))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var reviewPitchContent: some View {
        VStack(spacing: 18) {
            Text("Posture is built by one indie developer. No ads, no accounts, and nothing leaves your phone.")
                .font(Theme.font(.subheadline))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)

            Text("An honest review takes seconds and helps others discover a quiet daily posture ritual.")
                .font(Theme.font(.footnote))
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
                .buttonStyle(.daylight(.primary))

                Button {
                    ReviewPromptTracker.markShown()
                    finish(.enjoyedMaybeLater)
                } label: {
                    Text("Maybe later")
                }
                .buttonStyle(.daylight(.ghost))
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var feedbackContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What would make Posture work better for you?")
                .font(Theme.font(.subheadline))
                .foregroundStyle(Theme.ink2)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $feedbackText)
                .font(Theme.font(.body))
                .frame(minHeight: 140)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(Theme.paper3, in: RoundedRectangle(cornerRadius: 12))
                .focused($feedbackFocused)

            if mailFailed {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your mail app didn't open. Copy the address and send it from anywhere.")
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.badText)
                    Button {
                        UIPasteboard.general.string = Self.supportEmail
                    } label: {
                        Text("Copy \(Self.supportEmail)")
                            .font(Theme.font(.caption, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Opens your mail app with a draft to the developer. No analytics, just your words.")
                    .font(Theme.font(.caption))
                    .foregroundStyle(Theme.ink3)
            }

            Button { sendFeedback() } label: {
                Text("Send feedback")
            }
            .buttonStyle(.daylight(.primary))
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
        // Only claim the feedback landed if Mail actually opened. With no mail
        // client the sheet used to dismiss as "submitted" and drop the note.
        UIApplication.shared.open(url) { opened in
            guard opened else {
                mailFailed = true
                return
            }
            ReviewPromptTracker.markFeedbackSubmitted()
            finish(.feedbackSubmitted)
        }
    }

    private func finish(_ outcome: ReviewPromptDismissOutcome) {
        onFinish(outcome)
        dismiss()
    }

    static let supportEmail = "jackwallner+q@gmail.com"

    static func feedbackMailURL(body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Posture feedback"),
            URLQueryItem(name: "body", value: body),
        ]
        return components.url
    }
}
