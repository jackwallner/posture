import SwiftData
import SwiftUI
import WidgetKit

struct PostureWidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let todayScore: Int?
    let hasCalibrated: Bool
}

struct PostureWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> PostureWidgetEntry {
        PostureWidgetEntry(date: .now, streak: 7, todayScore: 86, hasCalibrated: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (PostureWidgetEntry) -> Void) {
        completion(Self.load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PostureWidgetEntry>) -> Void) {
        let entry = Self.load()
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: entry.date) ?? entry.date.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    static func load() -> PostureWidgetEntry {
        // Must mirror DataService's schema exactly — this extension opens the
        // same App Group store, and a schema mismatch after the app migrates
        // it makes the container fail (blank widget).
        let schema = Schema([PostureSession.self, PosturePassiveSample.self, PostureMinuteSample.self, Calibration.self, StreakState.self, BeforeAfterPhoto.self, AcknowledgmentRecord.self])
        let url = (FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: postureAppGroupID)
            ?? FileManager.default.temporaryDirectory).appendingPathComponent("Posture.store")
        let config = ModelConfiguration("Posture", schema: schema, url: url, cloudKitDatabase: .none)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return PostureWidgetEntry(date: .now, streak: 0, todayScore: nil, hasCalibrated: false)
        }
        let context = ModelContext(container)
        let streak = StreakService.displayStreak(
            for: (try? context.fetch(FetchDescriptor<StreakState>()))?.first
        )

        // Today's best camera check-in (PostureSession is no longer written).
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let ackPredicate = #Predicate<AcknowledgmentRecord> { ack in
            ack.timestamp >= startOfDay && ack.qualityRaw != nil
        }
        let todayAcks = (try? context.fetch(FetchDescriptor<AcknowledgmentRecord>(predicate: ackPredicate))) ?? []
        let todayScore: Int? = todayAcks
            .compactMap { $0.quality.map(Self.qualityScore) }
            .max()

        let cal = (try? context.fetch(FetchDescriptor<Calibration>()))?.first
        let hasCalibrated = cal != nil

        return PostureWidgetEntry(date: .now, streak: streak, todayScore: todayScore, hasCalibrated: hasCalibrated)
    }

    static func qualityScore(_ q: PostureQuality) -> Int {
        switch q {
        case .good: return 85
        case .borderline: return 55
        case .bad: return 25
        }
    }
}

struct PostureLockScreenWidgetView: View {
    let entry: PostureWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryRectangular:
            rectangular
        case .accessoryInline:
            inline
        case .systemSmall:
            systemSmall
        default:
            inline
        }
    }

    private var systemSmall: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "figure.stand")
                    .font(.subheadline.weight(.semibold))
                Text("Posture")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .foregroundStyle(Theme.ink)
            Spacer(minLength: 0)
            if let score = entry.todayScore {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(score)")
                        .font(.system(.largeTitle, design: .rounded).weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text("/ 100")
                        .font(.caption)
                        .foregroundStyle(Theme.ink2)
                }
            } else {
                Text("No check-in yet today")
                    .font(.system(.subheadline, design: .rounded).weight(.medium))
                    .foregroundStyle(Theme.ink2)
            }
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                Text("\(entry.streak)-day streak")
                    .font(.system(.caption, design: .rounded))
            }
            .foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 1) {
                Image(systemName: "figure.stand")
                    .font(.caption.weight(.semibold))
                if let score = entry.todayScore {
                    Text("\(score)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                } else {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(entry.streak)")
                        .font(.system(.title3, design: .rounded).weight(.bold))
                }
            }
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let score = entry.todayScore {
            Text("Posture \(score) · \(entry.streak)d streak")
        } else {
            Text("Streak: \(entry.streak)d")
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "figure.stand")
                    .font(.caption.weight(.semibold))
                Text("Posture")
                    .font(.caption2.weight(.semibold))
            }
            if let score = entry.todayScore {
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text("\(score)")
                        .font(.system(.title, design: .rounded).weight(.bold))
                    Text("/ 100")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(entry.streak)-day streak")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)
            } else {
                Text("No check-in yet today")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("\(entry.streak)-day streak")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@main
struct PostureWidget: Widget {
    let kind = "PostureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PostureWidgetProvider()) { entry in
            PostureLockScreenWidgetView(entry: entry)
                .containerBackground(Theme.dawnWash, for: .widget)
        }
        .configurationDisplayName("Posture today")
        .description("Today's posture score, with your current streak.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular,
            .systemSmall,
        ])
    }
}
