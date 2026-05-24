import SwiftData
import SwiftUI
import WidgetKit

struct PostureWatchWidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
    let todayScore: Int?
}

struct PostureWatchProvider: TimelineProvider {
    func placeholder(in context: Context) -> PostureWatchWidgetEntry {
        PostureWatchWidgetEntry(date: .now, streak: 7, todayScore: 86)
    }

    func getSnapshot(in context: Context, completion: @escaping (PostureWatchWidgetEntry) -> Void) {
        completion(Self.load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PostureWatchWidgetEntry>) -> Void) {
        let entry = Self.load()
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: entry.date) ?? entry.date.addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }

    static func load() -> PostureWatchWidgetEntry {
        let schema = Schema([PostureSession.self, StreakState.self, Calibration.self, PosturePassiveSample.self, BeforeAfterPhoto.self, AcknowledgmentRecord.self])
        let url = (FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: postureAppGroupID)
            ?? FileManager.default.temporaryDirectory).appendingPathComponent("Posture.store")
        let config = ModelConfiguration("Posture", schema: schema, url: url, cloudKitDatabase: .none)
        guard let container = try? ModelContainer(for: schema, configurations: [config]) else {
            return PostureWatchWidgetEntry(date: .now, streak: 0, todayScore: nil)
        }
        let context = ModelContext(container)
        let streak = (try? context.fetch(FetchDescriptor<StreakState>()))?.first?.currentStreak ?? 0
        let startOfDay = Calendar.current.startOfDay(for: .now)
        let ackPredicate = #Predicate<AcknowledgmentRecord> { ack in
            ack.timestamp >= startOfDay && ack.qualityRaw != nil
        }
        let todayAcks = (try? context.fetch(FetchDescriptor<AcknowledgmentRecord>(predicate: ackPredicate))) ?? []
        let todayScore: Int? = todayAcks
            .compactMap { $0.quality.map(qualityScore) }
            .max()
        return PostureWatchWidgetEntry(date: .now, streak: streak, todayScore: todayScore)
    }

    static func qualityScore(_ q: PostureQuality) -> Int {
        switch q {
        case .good: return 85
        case .borderline: return 55
        case .bad: return 25
        }
    }
}

struct PostureWatchWidgetView: View {
    let entry: PostureWatchWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
        case .accessoryCorner:
            corner
        case .accessoryInline:
            inline
        case .accessoryRectangular:
            rectangular
        default:
            inline
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                Text("\(entry.streak)")
                    .font(.system(.title3, design: .rounded).weight(.bold))
            }
        }
    }

    private var corner: some View {
        Image(systemName: "flame.fill")
            .font(.title3)
            .widgetLabel("\(entry.streak) day\(entry.streak == 1 ? "" : "s")")
    }

    @ViewBuilder
    private var inline: some View {
        if let score = entry.todayScore {
            Text("Posture \(score) · \(entry.streak)d")
        } else {
            Text("Streak: \(entry.streak)d")
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                Text("\(entry.streak) day streak")
            }
            .font(.caption2.weight(.semibold))
            if let score = entry.todayScore {
                Text("Today: \(score)")
                    .font(.headline)
            } else {
                Text("Time to sit up")
                    .font(.headline)
            }
        }
    }
}

@main
struct PostureWatchWidget: Widget {
    let kind = "PostureWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PostureWatchProvider()) { entry in
            PostureWatchWidgetView(entry: entry)
                .containerBackground(Theme.dawnWash, for: .widget)
        }
        .configurationDisplayName("Posture Streak")
        .description("Your current streak and today's posture score.")
        .supportedFamilies(Self.supportedWidgetFamilies)
    }

    private static var supportedWidgetFamilies: [WidgetFamily] {
        var families: [WidgetFamily] = [.accessoryCircular, .accessoryInline, .accessoryRectangular]
        #if os(watchOS)
        families.append(.accessoryCorner)
        #endif
        return families
    }
}
