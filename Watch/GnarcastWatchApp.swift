import SwiftUI
import WatchKit

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
/// stretches of that border rather than a ring drawn inside it. It is not a clock either: the whole
/// way round is 6am to 6pm — up the left side, noon at the TOP, down the right — because those are the
/// hours worth surfing.
///
/// IT IS A CLOCK FACE, and that fixes everything about the geometry. Twelve hours, so an hour is a
/// twelfth of the ring and every hour sits where a clock puts it: 6 at the BOTTOM, 9 at the LEFT, 12
/// at the TOP, 3 at the RIGHT. Any other number of slots and a position stops meaning a time.
///
/// 6am and 6pm therefore SHARE the bottom, exactly as they do on a clock, and that shared point is
/// the day's boundary — which is why it needs no contriving to land on the vertical.
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
                // ONE CONTINUOUS RIBBON. An hour still owns the arc from its own mark to the next,
                // but the colour does not step at the join — it holds flat across the middle of each
                // hour and crosses to the next one over a short fade centred on the boundary, so a
                // morning that improves reads as a sweep rather than twelve tiles. Both bands do it:
                // the rating's reds through greens and the height's blues alike.
                //
                // Drawn as many short strokes rather than a gradient, because a gradient along an
                // arbitrary path is not something Canvas will do — and each stroke overruns the next
                // by a hair, since abutting strokes on fractional pixels antialias into pale seams,
                // which is the very thing the fade exists to remove.
                let rate = Self.ramp(day.hours) { $0.color }
                let size = Self.ramp(day.hours) { $0.size_color }
                let steps = 144
                for k in 0..<steps {
                    let f0 = CGFloat(k) / CGFloat(steps), f1 = CGFloat(k + 1) / CGFloat(steps)
                    let u = (Double(k) + 0.5) / Double(steps) * 12
                    let to = min(1, f1 + 0.004)
                    if let c = Self.colourAt(u, rate) {
                        ctx.stroke(ring.trimmedPath(from: f0, to: to), with: .color(c),
                                   style: StrokeStyle(lineWidth: width, lineCap: .butt))
                    }
                    if let c = Self.colourAt(u, size) {
                        ctx.stroke(sizeRing.trimmedPath(from: f0, to: to), with: .color(c),
                                   style: StrokeStyle(lineWidth: sizeWidth, lineCap: .butt))
                    }
                }

                // THE DAY'S BOUNDARY: a LINE on the vertical where 6pm meets 6am, with a sunrise
                // clockwise of it and a sunset anticlockwise — the two sides of the day, said in the
                // one vocabulary that needs no key.
                //
                // Neither symbol can sit ON the boundary, because the first hour's own figures are
                // already there: 6am is where the day starts, so its numbers and the join are the same
                // point. They go in the 30 degrees of clear arc either side instead, between the 6am
                // figures and the 7am ones going one way and past the 5pm figures the other.
                if let p = ring.trimmedPath(from: 0, to: 0.0005).currentPoint {
                    let c = CGPoint(x: rect.midX, y: rect.midY)
                    let v = CGPoint(x: p.x - c.x, y: p.y - c.y)
                    var line = Path()
                    // Stops OUTSIDE the numbers: the first hour's figures are directly beneath it,
                    // and a line drawn through them is a strikethrough on a number.
                    line.move(to: CGPoint(x: c.x + v.x * 1.06, y: c.y + v.y * 1.06))
                    line.addLine(to: CGPoint(x: c.x + v.x * 0.94, y: c.y + v.y * 0.94))
                    ctx.stroke(line, with: .color(.white), style: StrokeStyle(lineWidth: 2, lineCap: .butt))
                }
                for (f, name, tint) in [(CGFloat(0.042), "sunrise.fill", Color.orange),
                                        (CGFloat(0.958), "sunset.fill", Color(red: 0.55, green: 0.6, blue: 0.95))] {
                    guard let p = numberRing.trimmedPath(from: f, to: f + 0.0005).currentPoint else { continue }
                    ctx.draw(Text(Image(systemName: name)).font(.system(size: 9)).foregroundColor(tint), at: p)
                }

                // The hour in question: a spoke from just outside the rating band inward past the
                // numbers, drawn BEFORE them so a number is never covered by it.
                if let hour = at, hour >= 6, hour <= 18 {
                    let f = CGFloat(hour - 6) / Self.slots
                    let onRing = ring.trimmedPath(from: max(0, f - 0.0005), to: min(1, f + 0.0005))
                    if let p = onRing.currentPoint {
                        let centre = CGPoint(x: rect.midX, y: rect.midY)
                        let v = CGPoint(x: p.x - centre.x, y: p.y - centre.y)
                        var spoke = Path()
                        // STOPS SHORT OF THE MIDDLE. The sea, swell and water lines run to about 0.78
                        // of the radius at the sides, and a spoke reaching past that strikes through
                        // them — at 3pm it lands straight across the water temperature. Far enough in
                        // to cross both bands and reach the hour's own figures, and no further.
                        spoke.move(to: CGPoint(x: centre.x + v.x * 1.04, y: centre.y + v.y * 1.04))
                        spoke.addLine(to: CGPoint(x: centre.x + v.x * 0.84, y: centre.y + v.y * 0.84))
                        ctx.stroke(spoke, with: .color(.white), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    }
                }

                guard numbers else { return }
                for h in day.hours where h.h >= 6 && h.h < 18 {
                    let mid = CGFloat(h.h - 6) / Self.slots
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

    /// The twelve hours' colours as RGB, indexed 0 = 6am, or nil where the hour is missing.
    static func ramp(_ hours: [Live.Hour], _ pick: (Live.Hour) -> String?) -> [(Double, Double, Double)?] {
        var out = [(Double, Double, Double)?](repeating: nil, count: 12)
        for h in hours where h.h >= 6 && h.h < 18 {
            out[h.h - 6] = rgb(pick(h))
        }
        return out
    }

    /// The same, from twelve hex strings already in hour order.
    static func ramp(hex: [String?]) -> [(Double, Double, Double)?] {
        (0..<12).map { $0 < hex.count ? rgb(hex[$0]) : nil }
    }

    static func rgb(_ hex: String?) -> (Double, Double, Double)? {
        guard let hex, hex.hasPrefix("#"), let v = UInt64(hex.dropFirst(), radix: 16) else { return nil }
        return (Double((v >> 16) & 0xff) / 255, Double((v >> 8) & 0xff) / 255, Double(v & 0xff) / 255)
    }

    /// The colour at a continuous hour offset. Flat across the middle of an hour, crossing to its
    /// neighbour over `fade` either side of the join — and NEVER across the day's own boundary, which
    /// is the one edge that has to stay hard.
    static func colourAt(_ u: Double, _ ramp: [(Double, Double, Double)?]) -> Color? {
        let i = min(11, max(0, Int(u)))
        guard let c = ramp[i] else { return nil }
        let frac = u - Double(i), fade = 0.25
        let mix = { (a: (Double, Double, Double), b: (Double, Double, Double), t: Double) in
            Color(red: a.0 + (b.0 - a.0) * t, green: a.1 + (b.1 - a.1) * t, blue: a.2 + (b.2 - a.2) * t)
        }
        if frac < fade, i > 0, let prev = ramp[i - 1] { return mix(prev, c, 0.5 + (frac / fade) * 0.5) }
        if frac > 1 - fade, i < 11, let next = ramp[i + 1] { return mix(c, next, (frac - (1 - fade)) / fade * 0.5) }
        return Color(red: c.0, green: c.1, blue: c.2)
    }

    /// Twelve, because it is a clock. 6am through 5pm each own the block from their own mark to the
    /// next, so the last runs 5pm to 6pm and the ring covers 6am to 6pm.
    static let slots: CGFloat = 12

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
    /// DETENTS PER DAY, and it is what sets the crown's speed. Bound straight to the day index, ten
    /// days is the crown's entire travel and a flick lands three days from the one you wanted.
    private static let perDay = 4.0
    /// THE GRID IS THE MIDDLE PANE AND THE DEFAULT: the week is the question the app is opened with,
    /// and both of the others hang off it — the day's own detail to the LEFT, the rain to the RIGHT.
    ///
    /// WAVE HEIGHT IS ALWAYS PAIRED WITH THE RATING. The ring's second band and the grid's second
    /// band are the same measure, or the two panes mean different things by the same blue. That is
    /// why rain is a pane of its own rather than a band on the dial.
    @State private var pane = 1
    private static let panes = 3
    /// How wide a pane is, and it is the width of the CLEAR MIDDLE — the ring's hourly figures sit
    /// about 45 points in from each edge, so anything wider paints over them as it slides past.
    private static let paneW: CGFloat = 128
    /// The numbers round the edge, on by default; a long press puts them away for the bands alone.
    @AppStorage("showNumbers") private var showNumbers = true

    var body: some View {
        let days = model.live?.days ?? []
        let i = min(day, max(0, days.count - 1))
        ZStack {
            if let l = model.live, !days.isEmpty {
                // NO SPOKE ACROSS ANY HOUR IS WHAT SAYS THE RING IS NOT TODAY'S. Nothing writes it in
                // words, and a label is the wrong instrument for it whatever it says: a word anywhere
                // near the middle is read as qualifying those numbers. A clock hand pointing at no
                // hour already means these are not the hours you are in.
                EdgeDial(day: days[i], at: days[i].today ? l.now_hour : nil, numbers: showNumbers)
                // THE PANES PAN. All three are laid out side by side and the row is offset to bring
                // one into view, so a swipe drags the next one in from the edge rather than swapping
                // it in place — which is what says they sit beside each other rather than being three
                // unrelated screens. Clipped to one pane's width, or the neighbours paint out over
                // the ring's own figures.
                HStack(spacing: 0) {
                    dayPane(l, days[i]).frame(width: Self.paneW)
                    grid(days, selected: i).frame(width: Self.paneW)
                    Group {
                        if let w = l.weather {
                            rainPane(w, days: days, now: l.now_hour, selected: days[i].date)
                        } else { Color.clear }
                    }
                    .frame(width: Self.paneW)
                }
                .frame(width: Self.paneW * 3)
                .offset(x: CGFloat(1 - pane) * Self.paneW)
                .frame(width: Self.paneW)
                .clipped()
                .animation(.easeOut(duration: 0.22), value: pane)
            } else if model.loading {
                ProgressView()
            } else {
                Image(systemName: "wifi.exclamationmark").font(.title2).foregroundStyle(.secondary)
            }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .focusable()
        // THE CLICK IS OURS, NOT THE CROWN'S. The crown has four detents to a day so it can be
        // aimed, and its own haptic fires on every one of them — four clicks for one day, so the
        // feel and the picture disagree. Turned off, and one click played at the moment the day
        // actually changes.
        .digitalCrownRotation($crown, from: 0, through: Double(max(1, days.count - 1)) * Self.perDay,
                              by: 1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: false)
        // The green crown indicator that slides in on every turn. It is a scroll position, and there
        // is nothing here to scroll — the day it is choosing is already said by the ring and the grid.
        .digitalCrownAccessory(.hidden)
        .onChange(of: crown) { _, v in
            let d = Int((v / Self.perDay).rounded())
            guard d != day else { return }
            day = d
            WKInterfaceDevice.current().play(.click)
        }
        // THREE GESTURES ON ONE VIEW, AND THE ORDER THEY RESOLVE IN IS THE WHOLE POINT. A plain
        // `.onTapGesture` beside `.onLongPressGesture` loses most first taps: the long press claims
        // the touch and waits out its duration before anyone else is asked, so the tap is swallowed
        // and only a second, luckier tap gets through.
        //
        // ExclusiveGesture tries the TAP FIRST and only falls to the long press when the tap fails,
        // which is exactly the intent. The drag is SIMULTANEOUS rather than in that chain, because a
        // gesture that has to fail before a tap is considered delays every tap by its own threshold.
        //
        // A swipe rather than a TabView, still: the crown is bound to this view and watchOS's paging
        // styles want it for themselves.
        .simultaneousGesture(DragGesture(minimumDistance: 18).onEnded { g in
            guard abs(g.translation.width) > abs(g.translation.height),
                  abs(g.translation.width) > 28 else { return }
            pane = min(Self.panes - 1, max(0, pane + (g.translation.width < 0 ? 1 : -1)))
        })
        // Back to today, and never a change of pane: the pane is where he put it.
        .gesture(ExclusiveGesture(
            TapGesture().onEnded { today(); model.refresh() },
            LongPressGesture(minimumDuration: 0.6).onEnded { _ in showNumbers.toggle() }))
        .onChange(of: model.live?.generated_at) { _, _ in today() }
    }

    /// IT OPENS ON TODAY, always — `days[0]`. Late in the evening that is a ring whose twelve hours
    /// have all been and gone, and it is still the day to open on: the crown is one turn away from
    /// tomorrow, and a face that silently shows a different day than the one you asked for is worse
    /// than one showing a finished day honestly.
    private func today() {
        day = 0; crown = 0
    }

    /// The day's own pane: what is MEASURED when the crown is on today, and that day's forecast when
    /// it is not — a day that has not happened has nothing measured in it.
    @ViewBuilder private func dayPane(_ l: Live, _ d: Live.Day) -> some View {
        if d.today { middle(l) } else { summary(d) }
    }

    /// A DAY THAT IS NOT TODAY, in the live block's place: how big, how good, and the wind, all of it
    /// the forecast's. The day is named because the ring cannot say which day it is drawing.
    @ViewBuilder private func summary(_ d: Live.Day) -> some View {
        let hs = d.hours
        let lo = hs.compactMap(\.ft_exact).min(), hi = hs.compactMap(\.ft_exact).max()
        let best = hs.max(by: { rank($0.rating) < rank($1.rating) })
        let midday = hs.first(where: { $0.h == 12 }) ?? hs.first
        VStack(spacing: 2) {
            Text(Self.weekday(d.date)).font(.system(size: 13, weight: .heavy))
                .foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
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
            let n = max(1, days.count)
            // ONE CONTINUOUS FIELD OF COLOUR, with a single seam before each SUNDAY so a week is
            // countable. It is the same hairline the cells all used to have — kept in one place rather
            // than widened there, because a wider gap stops being a seam and becomes a bar drawn
            // across the data.
            let weekGap: CGFloat = 1
            let sundays = days.indices.filter { $0 > 0 && Self.isSunday(days[$0].date) }
            let cw = (size.width - CGFloat(sundays.count) * weekGap) / CGFloat(n)
            let x = { (i: Int) in
                CGFloat(i) * cw + CGFloat(sundays.filter { $0 <= i }.count) * weekGap
            }
            let headH: CGFloat = 11, waterH: CGFloat = 23
            let bandH = (size.height - headH - waterH) / 2
            let ch = bandH / 12
            // EARLY AT THE BOTTOM, LATE AT THE TOP — 6am the bottom row, 5pm the top. That is the
            // ring's own orientation (6 o'clock is the bottom of a clock) and the hub's heat map's
            // (`y = base + GRID_H - h * ch` in cards/surf.js). Running it the other way makes the two
            // panes of this one screen disagree about which end of the day is which.
            let y = { (h: Int, band: CGFloat) in headH + band * bandH + CGFloat(17 - h) * ch }
            // THE SELECTED DAY IS ITS LETTER IN WHITE, and nothing marks today: the grid always
            // starts at today, so the first column says it without ink.
            for (i, d) in days.enumerated() {
                let l = String(Self.weekday(d.date).prefix(1))
                let on = i == selected
                ctx.draw(Text(l).font(.system(size: 8, weight: on ? .heavy : .semibold))
                            .foregroundColor(on ? .white : .secondary),
                         at: CGPoint(x: x(i) + cw / 2, y: headH / 2))
                // Cells OVERLAP by a hair. A column is a fraction of a point wide, so abutting rects
                // land on fractional pixels and antialias into a pale seam at every edge — which reads
                // as the grid still being ruled. The overlap is dropped where a real seam belongs:
                // before a Sunday, and at the bottom row of each band, which would otherwise bleed
                // into the band below.
                let over: CGFloat = 0.6
                let dx = (i + 1 < days.count && !sundays.contains(i + 1)) ? over : 0
                for h in d.hours where h.h >= 6 && h.h < 18 {
                    let dy: CGFloat = h.h > 6 ? over : 0
                    ctx.fill(Path(CGRect(x: x(i), y: y(h.h, 0), width: cw + dx, height: ch + dy)),
                             with: .color(Color(hex: h.color)))
                    if let sc = h.size_color {
                        ctx.fill(Path(CGRect(x: x(i), y: y(h.h, 1), width: cw + dx, height: ch + dy)),
                                 with: .color(Color(hex: sc)))
                    }
                }
            }
            // THE WATER, one point a day over the same columns, each segment in its own day's colour.
            // It stops where the marine model does, a few days short of the surf forecast — and the
            // blank that leaves at the right is where its RANGE is written, since a line with no scale
            // beside it says only that the water changed, not to what.
            let top = headH + bandH * 2
            let vals = days.map(\.water_f)
            let known = vals.compactMap { $0 }
            if known.count > 1 {
                let lo = known.min()!, hi = known.max()!, span = max(0.1, hi - lo)
                let pyTop = top + 8, pyBot = top + waterH - 4
                let py = { (v: Double) in pyBot - CGFloat((v - lo) / span) * (pyBot - pyTop) }
                for i in 0..<(days.count - 1) {
                    guard let a = vals[i], let b = vals[i + 1] else { continue }
                    var p = Path()
                    p.move(to: CGPoint(x: x(i) + cw / 2, y: py(a)))
                    p.addLine(to: CGPoint(x: x(i + 1) + cw / 2, y: py(b)))
                    ctx.stroke(p, with: .color(Color(hex: days[i].water_color)),
                               style: StrokeStyle(lineWidth: 2, lineCap: .round))
                }
                let lastKnown = vals.lastIndex(where: { $0 != nil }) ?? 0
                if lastKnown < days.count - 1 {
                    ctx.draw(Text(whole(hi)).font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.secondary),
                             at: CGPoint(x: size.width - 8, y: pyTop))
                    ctx.draw(Text(whole(lo)).font(.system(size: 8, weight: .semibold))
                                .foregroundColor(.secondary),
                             at: CGPoint(x: size.width - 8, y: pyBot))
                }
            }
            // ONE WHITE LINE DOWN THE CROWN'S COLUMN, through the bands and the water alike, so the
            // ring's day and the grid's are visibly the same day. Its letter above is white with it.
            if days.indices.contains(selected) {
                var p = Path()
                p.move(to: CGPoint(x: x(selected) + cw / 2, y: headH))
                p.addLine(to: CGPoint(x: x(selected) + cw / 2, y: size.height))
                ctx.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: 1.5))
            }
        }
        .frame(width: 118, height: 126)
    }

    /// RAIN, ITS OWN PANE. The same grammar as the grid beside it — a day per column, 6am at the
    /// bottom, one seam before each Sunday, the crown's day a white line with its letter in white —
    /// so the two read as two views of one week rather than two different charts — but over ALL 24 hours,
    /// not the twelve worth surfing: rain before dawn or at ten at night still decides something.
    ///
    /// It is SEVEN columns, not ten: the rain forecast is shorter than the surf one, and showing three
    /// empty columns to match would say the week ends in drought rather than that nothing is known.
    /// Under each column is that day's HIGHEST chance in the drawn hours, which is the number anyone
    /// actually asks of a rain forecast.
    @ViewBuilder private func rainPane(_ w: Live.Weather, days: [Live.Day], now: Double?,
                                       selected: String?) -> some View {
        Canvas { ctx, size in
            let n = max(1, w.cols.count)
            let weekGap: CGFloat = 1, over: CGFloat = 0.6
            let sundays = w.cols.indices.filter { $0 > 0 && Self.isSunday(w.cols[$0]) }
            let cw = (size.width - CGFloat(sundays.count) * weekGap) / CGFloat(n)
            let x = { (i: Int) in
                CGFloat(i) * cw + CGFloat(sundays.filter { $0 <= i }.count) * weekGap
            }
            // Two rows under the grid: the day's highest rain chance, then its air high over its low.
            let headH: CGFloat = 11, rainH: CGFloat = 11, tempH: CGFloat = 16
            let footH = rainH + tempH
            // THE WHOLE DAY, all 24 hours, where the surf grid draws only the twelve worth surfing.
            // Rain is a question about the day — whether it lands before dawn or at ten at night still
            // decides something — and 24 rows in this height is still three and a half points a row,
            // which is a heat map's worth of colour even if it is not a row anyone counts.
            let ch = (size.height - headH - footH) / 24
            let y = { (h: Int) in headH + CGFloat(23 - h) * ch }
            let byDate = Dictionary(uniqueKeysWithValues: days.map { ($0.date, $0) })
            for (i, date) in w.cols.enumerated() {
                let on = date == selected
                ctx.draw(Text(String(Self.weekday(date).prefix(1)))
                            .font(.system(size: 8, weight: on ? .heavy : .semibold))
                            .foregroundColor(on ? .white : .secondary),
                         at: CGPoint(x: x(i) + cw / 2, y: headH / 2))
                let dx = (i + 1 < n && !sundays.contains(i + 1)) ? over : 0
                var peak: Int? = nil
                for h in 0..<24 {
                    guard let v = w.level(date: date, hour: h) else { continue }
                    peak = max(peak ?? 0, v)
                    let dy: CGFloat = h > 0 ? over : 0
                    ctx.fill(Path(CGRect(x: x(i), y: y(h), width: cw + dx, height: ch + dy)),
                             with: .color(Color(hex: w.colors[v])))
                }
                let cx = x(i) + cw / 2
                // THE CHANCE IS BLUE and the temperatures are not, which is what tells the two rows
                // apart before either is read. The hairline under them says the same thing again for
                // anyone who reads down a column rather than across a row.
                if let p = peak {
                    ctx.draw(Text("\(w.percent(p))").font(.system(size: 8, weight: on ? .heavy : .semibold))
                                .foregroundColor(Color(red: 0.36, green: 0.74, blue: 0.9)
                                                    .opacity(on ? 1 : 0.8)),
                             at: CGPoint(x: cx, y: size.height - footH + rainH / 2))
                }
                // THE AIR, high over low. Two figures with no units and no labels: on a column already
                // headed by its day and footed by a rain chance, a bigger number over a smaller one in
                // the seventies is not going to be read as anything else.
                if let d = byDate[date] {
                    if let hi = d.air_hi {
                        ctx.draw(Text("\(hi)").font(.system(size: 8, weight: on ? .heavy : .semibold))
                                    .foregroundColor(.white.opacity(on ? 1 : 0.85)),
                                 at: CGPoint(x: cx, y: size.height - tempH + 4))
                    }
                    if let lo = d.air_lo {
                        ctx.draw(Text("\(lo)").font(.system(size: 8, weight: on ? .semibold : .regular))
                                    .foregroundColor(.secondary),
                                 at: CGPoint(x: cx, y: size.height - 4))
                    }
                }
            }
            // NOW, ACROSS THE WHOLE WIDTH — where in the day it is, which is what makes a column of
            // colour mean anything. Laid over a black underlay: today's column runs bright cyan right
            // where the line falls, and a bare white hairline on it cannot be seen.
            if let u = now, u >= 0, u <= 24 {
                let ny = headH + CGFloat(24 - u) * ch
                var p = Path()
                p.move(to: CGPoint(x: 0, y: ny)); p.addLine(to: CGPoint(x: size.width, y: ny))
                ctx.stroke(p, with: .color(.black.opacity(0.85)), style: StrokeStyle(lineWidth: 3))
                ctx.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: 1))
            }
            // The faintest rule between the chance and the temperatures.
            var sep = Path()
            sep.move(to: CGPoint(x: 6, y: size.height - tempH - 1))
            sep.addLine(to: CGPoint(x: size.width - 6, y: size.height - tempH - 1))
            ctx.stroke(sep, with: .color(.white.opacity(0.16)), style: StrokeStyle(lineWidth: 0.5))

            if let selected, let i = w.cols.firstIndex(of: selected) {
                var p = Path()
                p.move(to: CGPoint(x: x(i) + cw / 2, y: headH))
                p.addLine(to: CGPoint(x: x(i) + cw / 2, y: size.height - footH))
                ctx.stroke(p, with: .color(.white), style: StrokeStyle(lineWidth: 1.5))
            }
        }
        .frame(width: 118, height: 126)
    }

    /// A week boundary the reader can count from. Sunday is 1 in every Gregorian calendar here.
    static func isSunday(_ date: String) -> Bool {
        guard let d = dayFmt.date(from: date) else { return false }
        return Calendar(identifier: .gregorian).component(.weekday, from: d) == 1
    }

    /// Surfline's own order, worst to best, for picking a day's best hour.
    private func rank(_ r: String) -> Int {
        ["VERY_POOR", "POOR", "POOR_TO_FAIR", "FAIR", "FAIR_TO_GOOD", "GOOD", "GOOD_TO_EPIC", "EPIC"]
            .firstIndex(of: r) ?? 0
    }

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()
    /// THE WEEKDAY IS NOT ENOUGH over ten days — Friday comes round twice — so the date rides with
    /// it, and with its month, because the span crosses one.
    private static let weekdayFmt: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "EEE M/d"; return f
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
