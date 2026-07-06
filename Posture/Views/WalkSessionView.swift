import SwiftData
import SwiftUI

/// A walking posture session (Pro): pick a time or a distance, pocket the
/// phone, and AirPods track how tall you walk while the pedometer (and
/// optional GPS) track how far. Scoring auto-baselines to your own walking
/// posture in the first 30 seconds, and the clock only runs while you're
/// actually walking - standing still can't fake a good walk.
struct WalkSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(GoalSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss

    @State private var controller: PracticeSessionController?
    @State private var goalIsDistance = false
    @State private var targetMinutes = 20
    @State private var targetMeters: Double = 2000
    @State private var useGPS = false
    @State private var showingEndConfirm = false
    @State private var showingCustomTime = false
    @State private var showingCustomDistance = false
    @State private var customMinutes = 45

    private let minuteOptions = [10, 20, 30]

    private var metric: Bool { Locale.current.measurementSystem == .metric }
    private var distanceUnit: String { metric ? "km" : "mi" }
    /// Preset distances in the local unit, mapped to meters.
    private var distancePresets: [Double] {
        (metric ? [1.0, 2.0, 5.0] : [1.0, 2.0, 3.0]).map(displayToMeters)
    }

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
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    walkChip
                    Spacer()
                    closeButton
                }
                .padding(.top, 16)

                Text("Walk tall.")
                    .font(Theme.display(40))
                    .foregroundStyle(Theme.ink)
                    .padding(.top, 20)

                Text("AirPods in, phone in your pocket. Posture reads how tall you carry your head; your steps and distance track alongside. The first half minute sets your walking baseline.")
                    .font(Theme.font(.body))
                    .foregroundStyle(Theme.ink2)
                    .lineSpacing(3)
                    .padding(.top, 12)

                goalTypePicker
                    .padding(.top, 20)

                if goalIsDistance {
                    distanceChips
                        .padding(.top, 14)
                } else {
                    timeChips
                        .padding(.top, 14)
                }

                gpsToggle
                    .padding(.top, 18)

                if let error = controller.lastError {
                    Text(error)
                        .font(Theme.font(.footnote))
                        .foregroundStyle(Theme.clay)
                        .padding(.top, 12)
                }

                Button {
                    controller.start(config: .init(
                        kind: .walk,
                        targetSeconds: goalIsDistance ? 7200 : targetMinutes * 60,
                        targetPercent: 0,
                        level: 0,
                        goalIsDistance: goalIsDistance,
                        targetDistanceMeters: goalIsDistance ? targetMeters : 0,
                        useGPS: useGPS
                    ))
                } label: {
                    Text("Start walking")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.daylight(.primary))
                .padding(.top, 26)
                .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .dawnBackground()
        .sheet(isPresented: $showingCustomTime) {
            customTimeSheet.presentationDetents([.height(300)])
        }
        .sheet(isPresented: $showingCustomDistance) {
            customDistanceSheet.presentationDetents([.height(300)])
        }
    }

    private var goalTypePicker: some View {
        HStack(spacing: 10) {
            goalTab(title: "Time", isDistance: false)
            goalTab(title: "Distance", isDistance: true)
        }
    }

    private func goalTab(title: String, isDistance: Bool) -> some View {
        let selected = goalIsDistance == isDistance
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { goalIsDistance = isDistance }
        } label: {
            Text(title)
                .font(Theme.font(.subheadline, weight: .semibold))
                .foregroundStyle(selected ? Theme.sage : Theme.ink2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    selected ? Theme.sageTint : Theme.paper2,
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private var timeChips: some View {
        HStack(spacing: 10) {
            ForEach(minuteOptions, id: \.self) { minutes in
                chip(
                    label: "\(minutes) min",
                    selected: !isCustomTime && targetMinutes == minutes
                ) { targetMinutes = minutes }
            }
            chip(
                label: isCustomTime ? "\(targetMinutes) min" : "Custom",
                selected: isCustomTime
            ) {
                customMinutes = isCustomTime ? targetMinutes : customMinutes
                showingCustomTime = true
            }
        }
    }

    private var isCustomTime: Bool { !minuteOptions.contains(targetMinutes) }

    private var distanceChips: some View {
        HStack(spacing: 10) {
            ForEach(distancePresets, id: \.self) { meters in
                chip(
                    label: "\(distanceLabel(meters)) \(distanceUnit)",
                    selected: !isCustomDistance && abs(targetMeters - meters) < 1
                ) { targetMeters = meters }
            }
            chip(
                label: isCustomDistance ? "\(distanceLabel(targetMeters)) \(distanceUnit)" : "Custom",
                selected: isCustomDistance
            ) { showingCustomDistance = true }
        }
    }

    private var isCustomDistance: Bool {
        !distancePresets.contains { abs($0 - targetMeters) < 1 }
    }

    private func chip(label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.font(.subheadline, weight: .semibold))
                .foregroundStyle(selected ? Theme.sage : Theme.ink2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    selected ? Theme.sageTint : Theme.paper2,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var gpsToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) { useGPS.toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: useGPS ? "location.fill" : "location")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(useGPS ? Theme.sage : Theme.ink3)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Use GPS for accurate distance")
                        .font(Theme.font(.subheadline, weight: .medium))
                        .foregroundStyle(Theme.ink)
                    Text("Off uses a step-based estimate. GPS is more accurate outdoors and uses more battery.")
                        .font(Theme.font(.caption))
                        .foregroundStyle(Theme.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: $useGPS).labelsHidden().tint(Theme.sage)
            }
            .padding(16)
            .dawnCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    private var customTimeSheet: some View {
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
                showingCustomTime = false
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

    private var customDistanceSheet: some View {
        // Whole + tenth of a unit, 0.5 … 26.2 (a marathon's worth).
        let steps = Array(stride(from: 0.5, through: metric ? 42.0 : 26.2, by: 0.5))
        return VStack(spacing: 8) {
            Text("Walk distance")
                .font(Theme.display(20))
                .foregroundStyle(Theme.ink)
                .padding(.top, 18)
            Picker("Distance", selection: Binding(
                get: { (metric ? targetMeters / 1000 : targetMeters / 1609.34) },
                set: { targetMeters = displayToMeters($0) }
            )) {
                ForEach(steps, id: \.self) { d in
                    Text(String(format: "%.1f %@", d, distanceUnit)).tag(d)
                }
            }
            .pickerStyle(.wheel)
            Button {
                showingCustomDistance = false
            } label: {
                Text("Set \(distanceLabel(targetMeters)) \(distanceUnit)").frame(maxWidth: .infinity)
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
        let stationary = controller.phase == .running && !controller.isWalkingNow && !inWarmup(controller)
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
                    .trim(from: 0, to: controller.walkProgressFraction)
                    .stroke(paused || stationary ? Theme.ink3 : qualityColor(quality),
                            style: .init(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: controller.walkProgressFraction)
                VStack(spacing: 6) {
                    Text(centerValue(controller))
                        .font(Theme.font(size: 52, weight: .regular))
                        .foregroundStyle(Theme.ink)
                        .contentTransition(.numericText())
                        .monospacedDigit()
                    Text(centerUnit(controller))
                        .font(Theme.font(.footnote, weight: .semibold))
                        .foregroundStyle(Theme.ink3)
                    Text(stationary ? "keep walking" : (paused ? "paused" : qualityWord(quality)))
                        .font(Theme.display(19))
                        .foregroundStyle(stationary || paused ? Theme.ink3 : qualityColor(quality))
                        .padding(.top, 2)
                }
            }
            .frame(width: 240, height: 240)

            metricsRow(controller)
                .padding(.top, 22)

            Text(statusLine(controller, stationary: stationary))
                .font(Theme.font(.body))
                .foregroundStyle(Theme.ink2)
                .multilineTextAlignment(.center)
                .padding(.top, 18)
                .padding(.horizontal, 12)

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

    /// Steps + the metric the ring isn't already showing (distance for a time
    /// goal, elapsed time for a distance goal), plus a GPS badge.
    private func metricsRow(_ controller: PracticeSessionController) -> some View {
        HStack(spacing: 28) {
            metricStat(value: "\(controller.walkSteps)", label: "steps")
            if goalIsDistance {
                metricStat(value: timeLabel(Int(controller.elapsedSeconds)), label: "time")
            } else {
                metricStat(value: distanceLabel(controller.walkDistanceMeters), label: distanceUnit)
            }
            if controller.walkUsingGPS {
                metricStat(value: "GPS", label: "on", tint: Theme.sage)
            }
        }
    }

    private func metricStat(value: String, label: String, tint: Color = Theme.ink) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(Theme.font(.title3, weight: .semibold).monospacedDigit())
                .foregroundStyle(tint)
            Text(label)
                .font(Theme.font(.caption2, weight: .medium))
                .foregroundStyle(Theme.ink3)
        }
    }

    /// Big number in the ring: countdown for a time goal, distance for a
    /// distance goal.
    private func centerValue(_ controller: PracticeSessionController) -> String {
        goalIsDistance
            ? distanceLabel(controller.walkDistanceMeters)
            : timeLabel(controller.remainingSeconds)
    }

    private func centerUnit(_ controller: PracticeSessionController) -> String {
        goalIsDistance
            ? "of \(distanceLabel(targetMeters)) \(distanceUnit)"
            : "left"
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

    private func statusLine(_ controller: PracticeSessionController, stationary: Bool) -> String {
        if stationary {
            return "Paused, you've stopped moving. The walk picks back up when you start walking again."
        }
        switch controller.phase {
        case .waiting:
            return "Pop your AirPods in, the walk starts with your first reading."
        case .paused(.airpodsOut):
            return "AirPods are out. The clock is paused until they're back in."
        case .paused(.user):
            return "Paused."
        case .running:
            if inWarmup(controller) {
                return "Finding your stride and learning your walking posture."
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

    // MARK: - Units

    private func displayToMeters(_ display: Double) -> Double {
        metric ? display * 1000 : display * 1609.34
    }

    /// A distance in local units, 1 decimal (or 2 under 10 for short walks).
    private func distanceLabel(_ meters: Double) -> String {
        let d = metric ? meters / 1000 : meters / 1609.34
        return String(format: d < 10 ? "%.2f" : "%.1f", d)
    }
}
