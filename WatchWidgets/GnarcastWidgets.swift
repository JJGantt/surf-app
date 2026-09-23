import SwiftUI
import WidgetKit
import AppIntents

// TWO SURFACES FROM ONE EXTENSION, and they are not the same kind of thing.
//
// A CONTROL (Control Center, the Smart Stack, an Ultra's Action button) is drawn by the SYSTEM from a
// Label — a symbol and some text, and nothing else. It cannot show a gauge, a colour band or a
// number of ours. So the control's only job is to open the app.
//
// A COMPLICATION is a view of our own, on the watch face, which is where the actual reading goes: the
// rating as colour and the height as a figure, legible without opening anything.

// ---- the control ------------------------------------------------------------------------------

struct OpenGnarcastIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Gnarcast"
    static var openAppWhenRun = true
    func perform() async throws -> some IntentResult { .result() }
}

@available(watchOS 26.0, *)
struct GnarcastControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "com.jaredgantt.surf.watchkitapp.open") {
            ControlWidgetButton(action: OpenGnarcastIntent()) {
                Label("Surf", systemImage: "water.waves")
            }
        }
        .displayName("Surf")
    }
}

// ---- the complication -------------------------------------------------------------------------

/// What the face shows: the hour happening now. Nil while nothing has been read yet — a complication
/// that invents a reading is worse than one that admits it has none.
struct SurfEntry: TimelineEntry {
    let date: Date
    let ft: Double?
    let rating: String?
    let color: Color
    let wind: Double?
}

struct SurfProvider: TimelineProvider {
    func placeholder(in context: Context) -> SurfEntry {
        SurfEntry(date: .now, ft: 2.4, rating: "Fair", color: .green, wind: 8)
    }

    func getSnapshot(in context: Context, completion: @escaping (SurfEntry) -> Void) {
        Task { completion(await read()) }
    }

    /// REFRESHED HOURLY, and that is a budget rather than a choice: watchOS grants a complication a
    /// small number of background refreshes a day, so asking every few minutes gets the later ones
    /// refused and leaves the face staler than asking less often would have. The forecast moves on a
    /// six-hour capture anyway.
    func getTimeline(in context: Context, completion: @escaping (Timeline<SurfEntry>) -> Void) {
        Task {
            let entry = await read()
            completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(3600))))
        }
    }

    private func read() async -> SurfEntry {
        guard let live = try? await Hub.live(),
              let day = live.days.first(where: { $0.today }) ?? live.days.first else {
            return SurfEntry(date: .now, ft: nil, rating: nil, color: .gray, wind: nil)
        }
        // The hour the face is standing in. Past 6pm the ring has no hour left, so the last one drawn
        // is the honest answer rather than tomorrow's first.
        let h = min(17, max(6, Int(live.now_hour ?? 12)))
        let hour = day.hours.first(where: { $0.h == h }) ?? day.hours.last
        return SurfEntry(date: .now, ft: hour?.ft_exact, rating: hour?.rating,
                         color: Color(hex: hour?.color), wind: hour?.wind_kts)
    }
}

struct SurfFace: View {
    @Environment(\.widgetFamily) private var family
    let entry: SurfEntry

    private var height: String { entry.ft.map { String(format: "%.1f", $0) } ?? "—" }

    var body: some View {
        switch family {
        case .accessoryCorner:
            Text(height)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(entry.color)
                .widgetCurvesContent()
                .widgetLabel { Text(entry.rating ?? "") }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text("\(height) ft").font(.system(size: 16, weight: .bold, design: .rounded))
                    if let w = entry.wind {
                        Text("\(Int(w.rounded())) kt").font(.system(size: 12)).foregroundStyle(.secondary)
                    }
                }
                Text(entry.rating ?? "—").font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(entry.color).lineLimit(1).minimumScaleFactor(0.7)
            }
        case .accessoryInline:
            Text("\(height) ft \(entry.rating ?? "")")
        default:
            // THE RATING IS THE RING and the height is the figure inside it, which is the same
            // grammar as the app's own face — a glance at the wrist should not have to be relearned.
            ZStack {
                Circle().stroke(entry.color.opacity(0.35), lineWidth: 4)
                Circle().trim(from: 0, to: 0.75).rotation(.degrees(135))
                    .stroke(entry.color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                Text(height).font(.system(size: 15, weight: .bold, design: .rounded))
            }
        }
    }
}

struct SurfComplication: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SurfComplication", provider: SurfProvider()) { entry in
            SurfFace(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Surf")
        .description("Mayport Poles")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct GnarcastWidgets: WidgetBundle {
    var body: some Widget {
        SurfComplication()
        if #available(watchOS 26.0, *) { GnarcastControl() }
    }
}
