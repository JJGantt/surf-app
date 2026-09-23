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
/// right to 6pm back at the bottom — because those twelve hours are the day worth surfing.
///
/// Outside in: the RATING band, the wave HEIGHT band on the heat map's own blue, then two numbers an
/// hour — the height that breaks, exact, and the wind, bare because its colour is its direction. A
/// spoke marks the hour in question: now, or whatever the crown has scrubbed to.
struct EdgeDial: View {
    let day: Live.Day
    var at: Double?
    var numbers: Bool
    var inset: CGFloat = 3
    var width: CGFloat = 4          // the rating band
    var sizeWidth: CGFloat = 4      // wave height
    var between: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size).insetBy(dx: inset + width / 2, dy: inset + width / 2)
            let radius = min(rect.width, rect.height) * 0.30
            let ring = Self.border(rect, radius)
            let inner = rect.insetBy(dx: width / 2 + between + sizeWidth / 2, dy: width / 2 + between + sizeWidth / 2)
            let sizeRing = Self.border(inner, max(2, radius - width / 2 - between - sizeWidth / 2))
            // Where the numbers sit: inside both bands, far enough in that nothing touches them.
            let numRect = inner.insetBy(dx: sizeWidth / 2 + 13, dy: sizeWidth / 2 + 13)
            let numberRing = Self.border(numRect, max(2, radius - width - between - sizeWidth - 13))
            Canvas { ctx, _ in
                // EACH HOUR IS CENTRED ON ITS OWN MARK: 6am sits at the bottom, 3pm a quarter of the
                // way back up the right, and the segment straddles it by half an hour either side. Laid
                // out as blocks BETWEEN the marks instead, the 3pm number would sit at half past three
                // while the spoke — which is the real clock — pointed at three.
                let gap = 0.004          // a hair between hours, so twelve stretches read as twelve
                for h in day.hours where h.h >= 6 && h.h < 18 {
                    let slot = CGFloat(h.h - 6)
                    let from = (slot - 0.5) / 12, to = (slot + 0.5) / 12
                    for (a, b) in Self.wrapped(from + gap, to - gap) {
                        ctx.stroke(ring.trimmedPath(from: a, to: b), with: .color(Color(hex: h.color)),
                                   style: StrokeStyle(lineWidth: width, lineCap: .butt))
                        if let sc = h.size_color {
                            ctx.stroke(sizeRing.trimmedPath(from: a, to: b), with: .color(Color(hex: sc)),
                                       style: StrokeStyle(lineWidth: sizeWidth, lineCap: .butt))
                        }
                    }
                }

                // The hour in question: a spoke from just outside the rating band inward past the
                // numbers, drawn BEFORE them so a number is never covered by it.
                if let hour = at, hour >= 6, hour < 18 {
                    let f = CGFloat((hour - 6) / 12)
                    let onRing = ring.trimmedPath(from: max(0, f - 0.0005), to: min(1, f + 0.0005))
                    if let p = onRing.currentPoint {
                        let centre = CGPoint(x: rect.midX, y: rect.midY)
                        let v = CGPoint(x: p.x - centre.x, y: p.y - centre.y)
                        var spoke = Path()
                        spoke.move(to: CGPoint(x: centre.x + v.x * 1.04, y: centre.y + v.y * 1.04))
                        spoke.addLine(to: CGPoint(x: centre.x + v.x * 0.58, y: centre.y + v.y * 0.58))
                        ctx.stroke(spoke, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                }

                guard numbers else { return }
                for h in day.hours where h.h >= 6 && h.h < 18 {
                    let mid = CGFloat(h.h - 6) / 12
                    let p = numberRing.trimmedPath(from: max(0, mid - 0.0005), to: min(1, mid + 0.0005))
                    guard let point = p.currentPoint else { continue }
                    if let ft = h.ft_exact {
                        ctx.draw(Text(String(format: "%.1f", ft)).font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.85)),
                                 at: CGPoint(x: point.x, y: point.y - 6))
                    }
                    if let kt = h.wind_kts {
                        ctx.draw(Text(String(Int(kt.rounded()))).font(.system(size: 10, weight: .bold))
                                    .foregroundColor(Color(hex: h.wind_color)),
                                 at: CGPoint(x: point.x, y: point.y + 6))
                    }
                }
            }
        }
    }

    /// A span that may run off either end of the path, as the 6am segment does — half of it belongs to
    /// the last of the ring and half to the first.
    static func wrapped(_ from: CGFloat, _ to: CGFloat) -> [(CGFloat, CGFloat)] {
        if from < 0 { return [(0, max(0, to)), (1 + from, 1)] }
        if to > 1 { return [(min(1, from), 1), (0, to - 1)] }
        return [(from, to)]
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

/// TWO GESTURES, TWO INDEPENDENT THINGS. The CROWN picks the DAY: the ring round the edge redraws
/// for it and the middle says what that day is. A horizontal SWIPE picks what the middle says —
/// the live readings, or the whole forecast as a grid. Neither touches the other, so you can be on
/// Thursday in either pane and on either pane for any day.
struct LiveView: View {
    @ObservedObject var model: Model
    @State private var crown: Double = 0
    @State private var day = 0
    /// 0 the live readings, 1 the grid of every day.
    @State private var pane = 0
    /// The numbers round the edge, on by default; a long press puts them away for the bands alone.
    @AppStorage("showNumbers") private var showNumbers = true

    private var nowHour: Double {
        let p = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(p.hour ?? 0) + Double(p.minute ?? 0) / 60
    }

    var body: some View {
        let days = model.live?.days ?? []
        let i = min(day, max(0, days.count - 1))
        ZStack {
            if let l = model.live, !days.isEmpty {
                // NO SPOKE ACROSS ANY HOUR IS WHAT SAYS THE RING IS NOT TODAY'S. Nothing writes it in
                // words, and a label is the wrong instrument for it whatever it says: a word anywhere
                // near the middle is read as qualifying those numbers. A clock hand pointing at no
                // hour already means these are not the hours you are in.
                EdgeDial(day: days[i], at: days[i].today ? nowHour : nil, numbers: showNumbers)
                if pane == 1 {
                    grid(days, selected: i)
                } else if days[i].today {
                    middle(l)
                } else {
                    // A day that has not happened has nothing measured in it, so the live block is
                    // not an option: what stands in its place is that day's own forecast.
                    summary(days[i])
                }
            } else if model.loading {
                ProgressView()
            } else {
                Image(systemName: "wifi.exclamationmark").font(.title2).foregroundStyle(.secondary)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .focusable()
        .digitalCrownRotation($crown, from: 0, through: Double(max(1, days.count - 1)), by: 1,
                              sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { _, v in day = Int(v.rounded()) }
        // A swipe, not a TabView: the crown is already bound here, and watchOS's paging styles want
        // it for themselves.
        .gesture(DragGesture(minimumDistance: 18).onEnded { g in
            guard abs(g.translation.width) > abs(g.translation.height),
                  abs(g.translation.width) > 28 else { return }
            withAnimation(.easeOut(duration: 0.18)) { pane = g.translation.width < 0 ? 1 : 0 }
        })
        // Back to today, because opening the app asks about now. The crown goes with it or the next
        // click resumes from wherever it was left days ago.
        .onTapGesture { day = 0; crown = 0; model.refresh() }
        .onChange(of: model.live?.generated_at) { _, _ in day = 0; crown = 0 }
        .onLongPressGesture(minimumDuration: 0.5) { showNumbers.toggle() }
    }

    /// A DAY THAT IS NOT TODAY, in the live block's place: how big, how good, and the wind, all of it
    /// the forecast's. The day is named because the ring cannot say which day it is drawing.
    @ViewBuilder private func summary(_ d: Live.Day) -> some View {
        let hs = d.hours
        let lo = hs.compactMap(\.ft_exact).min(), hi = hs.compactMap(\.ft_exact).max()
        let best = hs.max(by: { rank($0.rating) < rank($1.rating) })
        let midday = hs.first(where: { $0.h == 12 }) ?? hs.first
        VStack(spacing: 2) {
            Text(Self.weekday(d.date)).font(.system(size: 13, weight: .heavy)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(lo == nil ? "—" : (lo == hi ? trim(lo) : "\(trim(lo))-\(trim(hi))"))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text("ft").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
            if let b = best {
                Text(b.rating).font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: b.color))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            if let m = midday, let kt = m.wind_kts {
                Text("\(Int(kt.rounded())) kt").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: m.wind_color))
            }
            if let f = d.water_f {
                Text("\(whole(f))°").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: d.water_color))
            }
        }
        .padding(.horizontal, 30)
    }

    /// EVERY DAY AT ONCE: the rating grid, the height grid under it on the heat map's blue, and the
    /// water across the same columns. A day is a COLUMN and an hour a row, 6am at the top, which is
    /// the hub's own heat map turned to fit a square screen.
    ///
    /// The day the ring is on is marked by a line straight down its column, through all three — that
    /// mark is the only thing tying this pane to the crown, since the ring itself is hidden behind
    /// the numbers out at the edge.
    @ViewBuilder private func grid(_ days: [Live.Day], selected: Int) -> some View {
        Canvas { ctx, size in
            let n = max(1, days.count), gap: CGFloat = 1
            let cw = (size.width - CGFloat(n - 1) * gap) / CGFloat(n)
            let waterH: CGFloat = 20, between: CGFloat = 4
            let bandH = (size.height - waterH - between * 2) / 2
            let ch = bandH / 12
            let x = { (i: Int) in CGFloat(i) * (cw + gap) }
            for (i, d) in days.enumerated() {
                for h in d.hours where h.h >= 6 && h.h < 18 {
                    let y = CGFloat(h.h - 6) * ch
                    ctx.fill(Path(CGRect(x: x(i), y: y, width: cw, height: ch)),
                             with: .color(Color(hex: h.color)))
                    if let sc = h.size_color {
                        ctx.fill(Path(CGRect(x: x(i), y: bandH + between + y, width: cw, height: ch)),
                                 with: .color(Color(hex: sc)))
                    }
                }
            }
            // THE WATER, one point a day over the same columns, each segment in its own day's colour
            // so the line reads warm or cold without a scale beside it. It stops where the marine
            // model does, a few days short of the surf forecast.
            let top = bandH * 2 + between * 2
            let vals = days.map(\.water_f)
            let known = vals.compactMap { $0 }
            if known.count > 1 {
                let lo = known.min()!, hi = known.max()!, span = max(0.1, hi - lo)
                let py = { (v: Double) in top + waterH - 3 - CGFloat((v - lo) / span) * (waterH - 6) }
                for i in 0..<(days.count - 1) {
                    guard let a = vals[i], let b = vals[i + 1] else { continue }
                    var p = Path()
                    p.move(to: CGPoint(x: x(i) + cw / 2, y: py(a)))
                    p.addLine(to: CGPoint(x: x(i + 1) + cw / 2, y: py(b)))
                    ctx.stroke(p, with: .color(Color(hex: days[i].water_color)),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
            }
            // The crown's day, straight down the middle of its column and through everything.
            if days.indices.contains(selected) {
                var p = Path()
                p.move(to: CGPoint(x: x(selected) + cw / 2, y: 0))
                p.addLine(to: CGPoint(x: x(selected) + cw / 2, y: size.height))
                ctx.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: 1.5))
            }
        }
        .frame(width: 118, height: 116)
    }

    /// Surfline's own order, worst to best, for picking a day's best hour.
    private func rank(_ r: String) -> Int {
        ["VERY_POOR", "POOR", "POOR_TO_FAIR", "FAIR", "FAIR_TO_GOOD", "GOOD", "GOOD_TO_EPIC", "EPIC"]
            .firstIndex(of: r) ?? 0
    }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    private static let weekdayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE"; return f
    }()
    static func weekday(_ date: String) -> String {
        guard let d = dayFmt.date(from: date) else { return date }
        return weekdayFmt.string(from: d).uppercased()
    }

    /// The middle: the wind now, then the sea under it. What is MEASURED is big, and it says as little
    /// as it can. The direction is an ARROW pointing where the wind BLOWS, coloured green offshore,
    /// amber cross, red onshore — so there is no word for it and no compass point to turn around in
    /// your head. Age is a bare `4h`, shown only when the HUB calls the reading stale (`stale` in the
    /// feed, judged against the reporting station's own cadence) and nothing at all otherwise.
    @ViewBuilder private func middle(_ l: Live) -> some View {
        VStack(spacing: 2) {
            // The wind is the NUMBER, and the two things that qualify it stack beside it: the arrow
            // over its age. No `kt` and no gust — the big figure on a surf face is knots, and a line
            // of units under it costs a row of a screen that has none to spare.
            if let w = l.wind {
                HStack(alignment: .center, spacing: 6) {
                    Text(trim(w.kts)).font(.system(size: 36, weight: .bold, design: .rounded))
                    VStack(spacing: 1) {
                        if let to = w.dir_to {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .bold))
                                .rotationEffect(.degrees(to))
                                .foregroundStyle(Color(hex: w.type_color))
                        }
                        if w.stale == true, let age = w.age_min {
                            Text(age >= 120 ? "\(age / 60)h" : "\(age)m")
                                .font(.system(size: 10, weight: .semibold)).foregroundStyle(.orange)
                        }
                    }
                }
            }
            if let s = l.sea {
                Divider().padding(.horizontal, 30).padding(.vertical, 1)
                // THE SAME SIZE, both of them. The sea is how big and the swell is how good — two
                // questions, not a headline and a footnote — and the swell is only dimmer because the
                // sea is the number that becomes the wave. Periods whole: a tenth of a second is not a
                // decision, and the line has to fit across the ring's narrower lower half.
                Text("sea \(trim(s.wvht_ft)) @ \(whole(s.dpd_s))s")
                    .font(.system(size: 12, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.6)
                Text("swell \(trim(s.swh_ft)) @ \(whole(s.swp_s))s")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                // The water reads at the same size as the sea and the swell, because it is the third
                // thing worth knowing and not a caption on them. Its COLOUR is the wetsuit scale the
                // hub computes (`waterColor` in server.js), cold blue to warm orange, so the number
                // says how warm before it is read.
                if let w = s.water_f {
                    Text("\(whole(w))°").font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: s.water_color))
                }
            }
        }
        // Inside the bands: the dial owns the edge, and a line that runs under it is unreadable on both.
        .padding(.horizontal, 26)
    }
}
