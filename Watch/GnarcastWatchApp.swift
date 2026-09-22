import SwiftUI

@main
struct GnarcastWatchApp: App {
    @StateObject private var model = Model()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            LiveView(model: model)
                .onChange(of: phase) { _, p in if p == .active { model.refresh() } }
                .task { model.refresh() }
                // The system clock sits over the top right corner of every watch app. This is the only
                // switch the SDK offers for it, and it is underscored, so it may simply do nothing.
                ._statusBarHidden(true)
        }
    }
}

// ---- the feed ---------------------------------------------------------------------------------------

/// Read when the app comes to the front. No timer, and nothing to sign in to: the hub serves the surf
/// feed publicly. The phone's page is the live view; this is the glance.
@MainActor
final class Model: ObservableObject {
    @Published var live: Live?
    @Published var failed = false
    @Published var loading = false

    func refresh() {
        loading = true
        Task {
            do { live = try await Hub.live(); failed = false }
            catch { failed = true }
            loading = false
        }
    }
}

// ---- the dial ---------------------------------------------------------------------------------------

/// THE FORECAST AROUND THE RIM, where a watch already puts hours: each of the next twelve hours is a
/// segment at its own clock position, coloured by its rating, with a tick at the time now. The middle
/// holds what is happening this minute, so the whole thing is one glance and never scrolls.
struct Dial: View {
    let hours: [Live.Hour]

    var body: some View {
        Canvas { ctx, size in
            let side = min(size.width, size.height)
            let centre = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = side / 2 - 4
            let width: CGFloat = 7
            for h in hours.prefix(12) {
                // 12 at the top, each hour 30 degrees round, with a gap left between segments.
                let slot = Double((h.h % 12 + 12) % 12)
                let start = Angle(degrees: slot * 30 - 90 - 13)
                let end = Angle(degrees: slot * 30 - 90 + 13)
                var arc = Path()
                arc.addArc(center: centre, radius: radius - width / 2, startAngle: start, endAngle: end, clockwise: false)
                ctx.stroke(arc, with: .color(Color(hex: h.color)), style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
            // Now: a tick inside the ring, at the fraction of the hour actually elapsed.
            let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
            let mins = Double((parts.hour ?? 0) % 12) * 60 + Double(parts.minute ?? 0)
            let a = Angle(degrees: mins / 720 * 360 - 90).radians
            let inner = radius - width - 3, outer = radius - width + 1
            var tick = Path()
            tick.move(to: CGPoint(x: centre.x + cos(a) * inner, y: centre.y + sin(a) * inner))
            tick.addLine(to: CGPoint(x: centre.x + cos(a) * outer, y: centre.y + sin(a) * outer))
            ctx.stroke(tick, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        }
    }
}

// ---- the glance -------------------------------------------------------------------------------------

struct LiveView: View {
    @ObservedObject var model: Model

    var body: some View {
        ZStack {
            if let l = model.live {
                Dial(hours: l.hours)
                middle(l)
            } else if model.loading {
                ProgressView()
            } else {
                Image(systemName: "wifi.exclamationmark").font(.title2).foregroundStyle(.secondary)
            }
        }
        .ignoresSafeArea()
        .onTapGesture { model.refresh() }
    }

    /// The middle: the wind now, then the sea under it. What is MEASURED is big; the forecast for the
    /// same thing sits under it, dimmer and named, so the two can never be mistaken for each other.
    @ViewBuilder private func middle(_ l: Live) -> some View {
        VStack(spacing: 1) {
            if let w = l.wind {
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(trim(w.kts)).font(.system(size: 34, weight: .bold, design: .rounded))
                    VStack(alignment: .leading, spacing: -2) {
                        Text("kt").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                        Text(w.compass ?? "").font(.system(size: 13, weight: .bold))
                    }
                }
                Text(w.type ?? "").font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: w.type_color))
                if let g = w.gust { Text("gust \(trim(g))").font(.system(size: 10)).foregroundStyle(.secondary) }
                if let f = w.forecast {
                    Text("forecast \(trim(f.kts)) \(f.compass ?? "")")
                        .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
                }
                // Only when it is old enough to matter: the station goes quiet for hours at a time.
                if let age = w.age_min, age > 30 {
                    Text(age >= 120 ? "\(age / 60)h old" : "\(age)m old")
                        .font(.system(size: 9, weight: .semibold)).foregroundStyle(.orange)
                }
            }
            if let s = l.sea {
                Divider().padding(.horizontal, 30).padding(.vertical, 1)
                // Periods and the water rounded whole: a tenth of a second is not a decision, and the
                // line has to fit across the ring's narrower lower half.
                Text("\(trim(s.wvht_ft)) ft @ \(whole(s.dpd_s))s \(s.mwd_compass ?? "")")
                    .font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
                Text("swell \(trim(s.swh_ft)) @ \(whole(s.swp_s))s · \(whole(s.water_f))°")
                    .font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.6)
            }
        }
        // Inside the ring: the dial owns the rim, and a line that runs under it is unreadable on both.
        .frame(maxWidth: 118)
    }
}
