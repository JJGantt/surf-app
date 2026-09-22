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

/// THE DAY AROUND THE SCREEN'S OWN EDGE. The watch is a rounded square, not a circle, so the band is
/// twelve stretches of that border rather than a ring drawn inside it. It is not a clock either: the
/// whole way round is 6am to 6pm — 6am at the BOTTOM, up the left side, noon at the TOP, down the
/// right to 6pm back at the bottom — because those twelve hours are the day worth surfing. A mark
/// shows the time now while it is inside that window. The middle is left for the live readings, and
/// nothing scrolls.
///
/// TWO BANDS, the same pair the heat map draws: the rating outside, the wave HEIGHT just inside it on
/// the heat map's own blue scale, so a colour means the same size in both places (the hub sends both,
/// `color` and `size_color`).
struct EdgeDial: View {
    let day: Live.Day
    var inset: CGFloat = 3
    var width: CGFloat = 7
    var sizeWidth: CGFloat = 4
    var between: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: inset + width / 2, dy: inset + width / 2)
            let radius = min(rect.width, rect.height) * 0.30
            let ring = Self.border(rect, radius)
            let inner = rect.insetBy(dx: width / 2 + between + sizeWidth / 2, dy: width / 2 + between + sizeWidth / 2)
            let sizeRing = Self.border(inner, max(2, radius - width / 2 - between - sizeWidth / 2))
            Canvas { ctx, _ in
                let gap = 0.005          // a hair between hours, so twelve stretches read as twelve
                for h in day.hours where h.h >= 6 && h.h < 18 {
                    let slot = CGFloat(h.h - 6)
                    let seg = ring.trimmedPath(from: slot / 12 + gap, to: (slot + 1) / 12 - gap)
                    ctx.stroke(seg, with: .color(Color(hex: h.color)),
                               style: StrokeStyle(lineWidth: width, lineCap: .butt))
                    if let sc = h.size_color {
                        let s = sizeRing.trimmedPath(from: slot / 12 + gap, to: (slot + 1) / 12 - gap)
                        ctx.stroke(s, with: .color(Color(hex: sc)), style: StrokeStyle(lineWidth: sizeWidth, lineCap: .butt))
                    }
                }
                guard day.today else { return }
                let parts = Calendar.current.dateComponents([.hour, .minute], from: Date())
                let hour = Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
                guard hour >= 6, hour < 18 else { return }
                let f = CGFloat((hour - 6) / 12)
                let notch = ring.trimmedPath(from: max(0, f - 0.003), to: min(1, f + 0.003))
                ctx.stroke(notch, with: .color(.white), style: StrokeStyle(lineWidth: width + 5, lineCap: .butt))
            }
        }
    }

    /// The border drawn from BOTTOM CENTRE, clockwise — so 6am starts at the bottom and noon lands at
    /// the top. The corner radius is the screen's, near enough that the band keeps the same distance
    /// from the bezel along the straights and round the corners.
    static func border(_ r: CGRect, _ radius: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.midX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + radius, y: r.maxY))
        p.addArc(center: CGPoint(x: r.minX + radius, y: r.maxY - radius), radius: radius,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: r.minX, y: r.minY + radius))
        p.addArc(center: CGPoint(x: r.minX + radius, y: r.minY + radius), radius: radius,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX - radius, y: r.minY))
        p.addArc(center: CGPoint(x: r.maxX - radius, y: r.minY + radius), radius: radius,
                 startAngle: .degrees(270), endAngle: .degrees(360), clockwise: false)
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - radius))
        p.addArc(center: CGPoint(x: r.maxX - radius, y: r.maxY - radius), radius: radius,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.closeSubpath()
        return p
    }
}

// ---- the glance -------------------------------------------------------------------------------------

struct LiveView: View {
    @ObservedObject var model: Model
    /// WET MODE: the screen stops answering touches, so a wave running over it cannot press anything,
    /// while DOUBLE TAP still works — Apple's own Water Lock disables that too. Turned on by holding
    /// the screen, off by double tap (or another long press, for a watch without the gesture).
    ///
    /// It cannot stop watchOS's OWN gestures: a wet screen can still pull down Notification Centre or
    /// swipe the app away, and only Water Lock blocks those. Use both — Water Lock for the paddle out,
    /// this for when the answer has to be one gesture away.
    @State private var wet = false

    var body: some View {
        ZStack {
            Group {
                if let l = model.live {
                    if let d = l.day { EdgeDial(day: d) }
                    middle(l)
                } else if model.loading {
                    ProgressView()
                } else {
                    Image(systemName: "wifi.exclamationmark").font(.title2).foregroundStyle(.secondary)
                }
            }
            .allowsHitTesting(!wet)
            if wet {
                VStack {
                    Image(systemName: "drop.fill").font(.system(size: 11)).foregroundStyle(.cyan)
                    Spacer()
                }
                .padding(.top, 2)
                .allowsHitTesting(false)
            }
            // THE DOUBLE-TAP TARGET, one point across and all but invisible: the gesture needs a
            // primary action to fire, and water cannot press what has no area. It refreshes normally,
            // and leaves wet mode when wet mode is on.
            Button { wet ? (wet = false) : model.refresh() } label: { Color.clear.frame(width: 1, height: 1) }
                .buttonStyle(.plain)
                .handGestureShortcut(.primaryAction)
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        // A tap is ignored in wet mode — that is the whole point of it. The long press stays, so a
        // watch with no double tap is never stuck in it.
        .onTapGesture { if !wet { model.refresh() } }
        .onLongPressGesture(minimumDuration: 0.6) { wet.toggle() }
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
        // Inside the band: the dial owns the edge, and a line that runs under it is unreadable on both.
        .padding(.horizontal, 26)
    }
}
