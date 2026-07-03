import SwiftData
import SwiftUI

/// Running activity log for the AirPods monitor — answers "is it actually
/// working?" with a live freshness readout and a feed of what the monitor
/// has seen and done this session.
struct MonitoringLogView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AirpodsBackgroundMonitor.self) private var monitor: AirpodsBackgroundMonitor?

    @Query private var todaySlouches: [PosturePassiveSample]

    init() {
        let today = DateHelpers.startOfDay()
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        _todaySlouches = Query(filter: #Predicate<PosturePassiveSample> { sample in
            sample.timestamp >= today && sample.timestamp < tomorrow
        })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let monitor {
                        statusCard(monitor)
                        howItWorks
                        eventFeed(monitor)
                    } else {
                        Text("Monitoring isn't running.")
                            .font(Theme.displaySerif(22))
                            .foregroundStyle(Theme.ink)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .dawnBackground()
            .navigationTitle("Monitoring")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(Theme.ink3)
                    }
                    .accessibilityLabel("Close")
                }
            }
        }
        .preferredColorScheme(.light)
    }

    // MARK: - Status

    private func statusCard(_ monitor: AirpodsBackgroundMonitor) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(statusColor(monitor))
                    .frame(width: 8, height: 8)
                Text(statusLine(monitor))
                    .font(Theme.displaySerif(20))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 0)
            }

            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                VStack(alignment: .leading, spacing: 6) {
                    statRow(
                        label: "readings today",
                        value: monitor.samplesToday.formatted()
                    )
                    statRow(
                        label: "last reading",
                        value: lastReadingText(monitor, now: timeline.date)
                    )
                    statRow(
                        label: "slouches logged today",
                        value: "\(todaySlouches.count)"
                    )
                    if monitor.isConnected {
                        statRow(label: "right now", value: qualityWord(monitor.currentQuality))
                    }
                }
            }

            if let error = monitor.lastError {
                Text(error)
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Theme.clay)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard()
    }

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Theme.ink3)
            Spacer()
            Text(value)
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .foregroundStyle(Theme.ink)
        }
    }

    private func statusLine(_ monitor: AirpodsBackgroundMonitor) -> String {
        if !monitor.isMonitoring { return "monitoring is off" }
        if monitor.isConnected { return "listening through your AirPods" }
        return "Armed, waiting for AirPods"
    }

    private func statusColor(_ monitor: AirpodsBackgroundMonitor) -> Color {
        if !monitor.isMonitoring { return Theme.ink3 }
        return monitor.isConnected ? Theme.sage : Theme.sand
    }

    private func lastReadingText(_ monitor: AirpodsBackgroundMonitor, now: Date) -> String {
        guard let last = monitor.lastSampleAt else { return "–" }
        let ago = max(0, Int(now.timeIntervalSince(last)))
        if ago <= 2 { return "just now" }
        if ago < 60 { return "\(ago)s ago" }
        return "\(ago / 60)m \(ago % 60)s ago"
    }

    private func qualityWord(_ quality: PostureQuality) -> String {
        switch quality {
        case .good: return "aligned"
        case .borderline: return "drifting"
        case .bad: return "resting"
        }
    }

    // MARK: - How it works

    private var howItWorks: some View {
        Text("While your AirPods are linked they stream head motion many times a second, and each reading is scored against your calibration. A slouch held for three seconds gets one log entry and a gentle buzz, at most once a minute.")
            .font(.system(.footnote, design: .rounded))
            .foregroundStyle(Theme.ink2)
            .lineSpacing(2)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .fill(Theme.lavenderTint)
            )
    }

    // MARK: - Event feed

    private func eventFeed(_ monitor: AirpodsBackgroundMonitor) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Activity")
                .font(.system(.footnote, design: .rounded).weight(.semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.ink3)

            if monitor.events.isEmpty {
                Text("Nothing logged yet this session.")
                    .font(.system(.footnote, design: .rounded))
                    .foregroundStyle(Theme.ink2)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(monitor.events) { event in
                        eventRow(event)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .dawnCard()
    }

    private func eventRow(_ event: MonitorEvent) -> some View {
        let (text, color) = describe(event.kind)
        return HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
                .padding(.top, 4)
            Text(text)
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(Theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Text(timeString(event.timestamp))
                .font(.system(.caption2, design: .rounded))
                .foregroundStyle(Theme.ink3)
        }
    }

    private func describe(_ kind: MonitorEvent.Kind) -> (String, Color) {
        switch kind {
        case .armed(let background):
            return (background ? "Monitoring armed, runs in the background"
                               : "Monitoring armed, while the app is open", Theme.sage)
        case .stopped: return ("monitoring stopped", Theme.ink3)
        case .connected: return ("AirPods connected", Theme.sage)
        case .disconnected: return ("AirPods disconnected", Theme.sand)
        case .slouchLogged: return ("slouch logged · gentle nudge", Theme.clay)
        case .recovered: return ("back to aligned", Theme.sage)
        case .audioInterrupted: return ("Paused, another app took the audio session", Theme.sand)
        case .audioResumed: return ("listening again", Theme.sage)
        case .error(let message): return (message, Theme.clay)
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm:ss a"
        return formatter.string(from: date)
    }
}
