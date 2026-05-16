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
        let schema = Schema([PostureSession.self, StreakState.self, Calibration.self, PosturePassiveSample.self, BeforeAfterPhoto.self, AcknowledgmentRecord.self])
        let url = (FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: postureAppGroupID)
            ?? FileManager.default.temporaryDirectory).appendingPathComponent("Posture.store")
        let config = ModelConfiguration("Posture", schema: schema, url: url, cloudKitDatabase: .none)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return PostureWidgetEntry(date: .now, streak: 0, todayScore: nil, hasCalibrated: false)
        }
        let context = ModelContext(container)
        let streak = (try? context.fetch(FetchDescriptor<StreakState>()))?.first?.currentStreak ?? 0

        var sessionDescriptor = FetchDescriptor<PostureSession>(
            sortBy: [SortDescriptor(\PostureSession.startedAt, order: .reverse)]
        )
        sessionDescriptor.fetchLimit = 1
        let session = (try? context.fetch(sessionDescriptor))?.first
        let todayScore: Int? = (session != nil && Calendar.current.isDateInToday(session!.startedAt)) ? session!.score : nil

        let cal = (try? context.fetch(FetchDescriptor<Calibration>()))?.first
        let hasCalibrated = cal != nil

        return PostureWidgetEntry(date: .now, streak: streak, todayScore: todayScore, hasCalibrated: hasCalibrated)
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
        default:
            inline
        }
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
                Text("No session today")
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
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Posture Streak")
        .description("Your current streak and today's posture score.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryInline,
            .accessoryRectangular,
        ])
    }
}
