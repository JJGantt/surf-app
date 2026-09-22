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

struct LiveView: View {
    @ObservedObject var model: Model
    /// The crown scrubs the day: the spoke moves to an hour and the middle shows that hour's forecast.
    /// It lets go by itself after a few seconds, because a watch left on 9am at four in the afternoon
    /// is lying about what is happening now.
    @State private var crown: Double = 6
    @State private var scrubbed: Int?
    @State private var idle: Task<Void, Never>?
    /// The numbers round the edge, on by default; a long press puts them away for the bands alone.
    @AppStorage("showNumbers") private var showNumbers = true

    private var nowHour: Double {
        let p = Calendar.current.dateComponents([.hour, .minute], from: Date())
        return Double(p.hour ?? 0) + Double(p.minute ?? 0) / 60
    }

    var body: some View {
        ZStack {
            if let l = model.live {
                if let d = l.day {
                    EdgeDial(day: d,
                             at: scrubbed.map(Double.init) ?? (d.today ? nowHour : nil),
                             numbers: showNumbers)
                }
                if let h = scrubbed, let hour = l.day?.hours.first(where: { $0.h == h }) {
                    forecast(hour, tomorrow: l.day?.today == false)
                } else {
                    middle(l)
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
        .digitalCrownRotation($crown, from: 6, through: 17, by: 1, sensitivity: .low,
                              isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crown) { _, v in
            scrubbed = Int(v.rounded())
            idle?.cancel()
            idle = Task {
                try? await Task.sleep(for: .seconds(8))
                if !Task.isCancelled { scrubbed = nil }
            }
        }
        .onTapGesture { scrubbed = nil; model.refresh() }
        .onLongPressGesture(minimumDuration: 0.5) { showNumbers.toggle() }
    }

    /// WHICH DAY THE RING IS. The spoke only exists on today's, so once the ring has moved on to
    /// tomorrow — which it does at 6pm — something has to say so or the missing spoke reads as a fault.
    ///
    /// It labels the RING and nothing else, which decides where it can go. The middle is MEASURED — the
    /// wind, the sea and the water as they are right now — whatever day the ring is showing, so a line
    /// sitting over that block claims those numbers are tomorrow's. Under the block it is a footnote to
    /// the face; over it, it is a lie. The top of the screen is no good either: there it lands under the
    /// bands and across the noon numbers and is cut in half.
    @ViewBuilder private func dayMark(_ tomorrow: Bool) -> some View {
        if tomorrow {
            Text("tomorrow").font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.tertiary).textCase(.uppercase)
        }
    }

    /// One hour of the FORECAST, while the crown is on it. Dim where the live middle is bright: none of
    /// this is measured.
    @ViewBuilder private func forecast(_ h: Live.Hour, tomorrow: Bool) -> some View {
        VStack(spacing: 2) {
            dayMark(tomorrow)
            Text(h.t).font(.system(size: 13, weight: .heavy)).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(h.ft_exact.map { String(format: "%.1f", $0) } ?? "—")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("ft").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
            }
            Text(h.rating).font(.system(size: 11, weight: .heavy)).foregroundStyle(Color(hex: h.color))
            if let kt = h.wind_kts {
                Text("\(Int(kt.rounded())) kt \(h.wind_type ?? "")")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(Color(hex: h.wind_color))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            if let sw = h.swh_ft, let sp = h.swp_s {
                Text("swell \(String(format: "%.1f", sw)) @ \(Int(sp))s")
                    .font(.system(size: 9)).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 30)
    }

    /// The middle: the wind now, then the sea under it. What is MEASURED is big, and it says as little
    /// as it can. The direction is an ARROW pointing where the wind BLOWS, coloured green offshore,
    /// amber cross, red onshore — so there is no word for it and no compass point to turn around in
    /// your head. Age is a bare `4h` when the reading is old, and nothing at all when it is not.
    @ViewBuilder private func middle(_ l: Live) -> some View {
        VStack(spacing: 2) {
            if let w = l.wind {
                HStack(alignment: .center, spacing: 5) {
                    Text(trim(w.kts)).font(.system(size: 36, weight: .bold, design: .rounded))
                    if let to = w.dir_to {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 20, weight: .bold))
                            .rotationEffect(.degrees(to))
                            .foregroundStyle(Color(hex: w.type_color))
                    }
                }
                HStack(spacing: 5) {
                    Text("kt").font(.system(size: 10, weight: .semibold))
                    if let g = w.gust { Text("g\(whole(g))").font(.system(size: 10)) }
                    if let age = w.age_min, age > 30 {
                        Text(age >= 120 ? "\(age / 60)h" : "\(age)m")
                            .font(.system(size: 10, weight: .semibold)).foregroundStyle(.orange)
                    }
                }
                .foregroundStyle(.secondary)
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
            dayMark(l.day?.today == false).padding(.top, 4)
        }
        // Inside the bands: the dial owns the edge, and a line that runs under it is unreadable on both.
        .padding(.horizontal, 26)
    }
}
