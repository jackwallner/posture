import SwiftData
import SwiftUI

/// A walking posture session (Pro): pick a duration, pocket the phone, and
/// AirPods track how tall you walk. Scoring uses a rolling window median so
/// gait bob doesn't read as slouching, and the first 30 seconds don't count
/// while you find your stride.
struct WalkSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var controller: PracticeSessionController?
    @State private var targetMinutes = 20
    @State private var showingEndConfirm = false
    @State private var showingCustomPicker = false
    @State private var customMinutes = 45

    private let durationOptions = [10, 20, 30]
    private var isCustomSelected: Bool { !durationOptions.contains(targetMinutes) }

    var body: some View {
        Group {
            if let controller {
                content(controller)
            } else {
                Color.clear
            }
        }
        .onAppear {
            if controller == nil {
                controller = PracticeSessionController(context: context)
            }
        }
        .onDisappear {
            controller?.cancel()
        }
        .interactiveDismissDisabled(isLive)
    }

    private var isLive: Bool {
        guard let phase = controller?.phase else { return false }
        switch phase {
        case .running, .waiting, .paused, .reps: return true
        case .idle, .finished: return false
        }
    }

    @ViewBuilder
    private func content(_ controller: PracticeSessionController) -> some View {
        switch controller.phase {
        case .idle:
            preStartView(controller)
        // Walks never do the chin-tuck warm-up; .reps is unreachable here
        // but the switch must cover it.
        case .waiting, .running, .paused, .reps:
            liveView(controller)
        case .finished:
            if let result = controller.result {
                SessionSummaryView(result: result, onDone: { dismiss() })
            }
        }
    }

    // MARK: - Pre-start

    private func preStartView(_ controller: PracticeSessionController) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                walkChip
                Spacer()
                closeButton
            }
            .padding(.top, 16)

            Spacer()

            Text("Walk tall.")
                .font(Theme.display(40))
                .foregroundStyle(Theme.ink)

            Text("AirPods in, phone in your pocket. Posture reads how tall you carry your head while you walk. The first half minute doesn't count while you find your stride.")
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .lineSpacing(3)
                .padding(.top, 14)

            HStack(spacing: 10) {
                ForEach(durationOptions, id: \.self) { minutes in
                    Button {
                        targetMinutes = minutes
                    } label: {
                        Text("\(minutes) min")
                            .font(Theme.font(.subheadline, weight: .semibold))
                            .foregroundStyle(targetMinutes == minutes ? Theme.sage : Theme.ink2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                targetMinutes == minutes ? Theme.sageTint : Theme.paper2,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(minutes) minute walk")
                }
                Button {
                    customMinutes = isCustomSelected ? targetMinutes : customMinutes
                    showingCustomPicker = true
                } label: {
                    Text(isCustomSelected ? "\(targetMinutes) min" : "Custom")
                        .font(Theme.font(.subheadline, weight: .semibold))
                        .foregroundStyle(isCustomSelected ? Theme.sage : Theme.ink2)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            isCustomSelected ? Theme.sageTint : Theme.paper2,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Custom walk length")
            }
            .padding(.top, 24)

            if let error = controller.lastError {
                Text(error)
                    .font(Theme.font(.footnote))
                    .foregroundStyle(Theme.clay)
                    .padding(.top, 12)
            }

            Spacer()

            Button {
                controller.start(config: .init(
                    kind: .walk,
                    targetSeconds: targetMinutes * 60,
                    targetPercent: 0,
                    level: 0
                ))
            } label: {
                Text("Start walking")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.daylight(.primary))
            .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dawnBackground()
        .sheet(isPresented: $showingCustomPicker) {
            customDurationSheet
                .presentationDetents([.height(300)])
        }
    }

    /// Wheel picker for any walk length from a quick loop to a long hike.
    private var customDurationSheet: some View {
        VStack(spacing: 8) {
            Text("Walk length")
                .font(Theme.display(20))
                .foregroundStyle(Theme.ink)
                .padding(.top, 18)
            Picker("Minutes", selection: $customMinutes) {
                ForEach(Array(stride(from: 5, through: 120, by: 5)), id: \.self) { minutes in
                    Text("\(minutes) minutes").tag(minutes)
                }
            }
            .pickerStyle(.wheel)
            Button {
                targetMinutes = customMinutes
                showingCustomPicker = false
            } label: {
                Text("Set \(customMinutes) minutes").frame(maxWidth: .infinity)
            }
            .buttonStyle(.daylight(.primary))
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity)
        .dawnBackground()
    }

    // MARK: - Live

    private func liveView(_ controller: PracticeSessionController) -> some View {
        let quality = controller.currentQuality
        let paused = isPaused(controller.phase)
        return VStack(spacing: 0) {
            HStack {
                walkChip
                Spacer()
                Button {
                    if controller.elapsedSeconds >= 30 {
                        showingEndConfirm = true
                    } else {
                        controller.cancel()
                        dismiss()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(Theme.font(.body, weight: .medium))
                        .foregroundStyle(Theme.ink3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("End walk")
            }
            .padding(.top, 16)

            Spacer()

            ZStack {
                Circle()
                    .stroke(Theme.ringTrack, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: progress(controller))
                    .stroke(paused ? Theme.ink3 : qualityColor(quality),
                            style: .init(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: progress(controller))
                VStack(spacing: 6) {
                    Text(timeLabel(controller.remainingSeconds))
                        .font(Theme.font(size: 54, weight: .regular))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText(countsDown: true))
                        .animation(.easeOut(duration: 0.2), value: controller.remainingSeconds)
                    Text(paused ? "paused" : qualityWord(quality))
                        .font(Theme.display(19))
                        .foregroundStyle(paused ? Theme.ink3 : qualityColor(quality))
                    if !inWarmup(controller), controller.elapsedSeconds > 40 {
                        Text("\(Int((controller.alignedFractionSoFar * 100).rounded()))% tall")
                            .font(Theme.font(.caption, weight: .semibold))
                            .foregroundStyle(Theme.ink3)
                    }
                }
            }
            .frame(width: 240, height: 240)

            Text(statusLine(controller))
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .padding(.top, 24)

            Spacer()

            Text("Lock your phone and pocket it, the walk keeps tracking.")
                .font(Theme.font(.caption))
                .foregroundStyle(Theme.ink3)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 28)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dawnBackground()
        .confirmationDialog("End this walk?", isPresented: $showingEndConfirm) {
            Button("End walk", role: .destructive) { controller.endEarly() }
            Button("Keep walking", role: .cancel) { }
        } message: {
            Text("Ending early keeps the minutes you walked in today's timeline.")
        }
    }

    // MARK: - Bits

    private var walkChip: some View {
        HStack(spacing: 5) {
            Image(systemName: "figure.walk")
                .font(.system(size: 11, weight: .semibold))
            Text("Walk")
                .font(Theme.font(.footnote, weight: .semibold))
        }
        .foregroundStyle(Theme.sage)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.sageTint, in: .capsule)
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(Theme.font(.body, weight: .medium))
                .foregroundStyle(Theme.ink3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close")
    }

    private func inWarmup(_ controller: PracticeSessionController) -> Bool {
        controller.elapsedSeconds <= PostureScoring.Walk.warmupSeconds
    }

    private func isPaused(_ phase: PracticeSessionController.Phase) -> Bool {
        if case .paused = phase { return true }
        if case .waiting = phase { return true }
        return false
    }

    private func statusLine(_ controller: PracticeSessionController) -> String {
        switch controller.phase {
        case .waiting:
            return "Pop your AirPods in, the walk starts with your first reading."
        case .paused(.airpodsOut):
            return "AirPods are out. The clock is paused until they're back in."
        case .paused(.user):
            return "Paused."
        case .running:
            if inWarmup(controller) {
                return "Finding your stride, scoring starts in a moment."
            }
            switch controller.currentQuality {
            case .good: return "Walking tall. Eyes on the horizon."
            case .borderline: return "Drifting, lift your gaze off the pavement."
            case .bad: return "Head's down. Chin level, eyes forward."
            }
        default:
            return ""
        }
    }

    private func progress(_ controller: PracticeSessionController) -> Double {
        guard let target = controller.config?.targetSeconds, target > 0 else { return 0 }
        return min(controller.elapsedSeconds / Double(target), 1)
    }

    private func qualityColor(_ q: PostureQuality) -> Color {
        switch q {
        case .good: return Theme.sage
        case .borderline: return Theme.sand
        case .bad: return Theme.clay
        }
    }

    private func qualityWord(_ q: PostureQuality) -> String {
        switch q {
        case .good: return "Tall"
        case .borderline: return "Drifting"
        case .bad: return "Head down"
        }
    }

    private func timeLabel(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
