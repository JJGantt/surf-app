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

// ---- the glance -------------------------------------------------------------------------------------

struct LiveView: View {
    @ObservedObject var model: Model

    var body: some View {
        ScrollView {
            if let l = model.live {
                VStack(alignment: .leading, spacing: 10) {
                    rating(l)
                    if let w = l.wind { wind(w) }
                    hours(l.hours)
                    ForEach(l.buoys) { buoy($0) }
                }
            } else if model.loading {
                ProgressView()
            } else {
                Image(systemName: "wifi.exclamationmark")
                    .font(.title2).foregroundStyle(.secondary).padding(.top, 30)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }
            }
        }
    }

    private func rating(_ l: Live) -> some View {
        let c = l.surf?.current
        return HStack(spacing: 6) {
            Circle().fill(Color(hex: c?.ratingColor)).frame(width: 10, height: 10)
            Text(c?.ratingLabel ?? "—").font(.headline)
            if let a = c?.hMin, let b = c?.hMax { Text("\(trim(a))–\(trim(b)) ft").foregroundStyle(.secondary) }
        }
    }

    private func wind(_ w: Live.Wind) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(trim(w.kts)).font(.system(size: 30, weight: .bold, design: .rounded))
                Text("kt").font(.caption).foregroundStyle(.secondary)
                Text(w.compass ?? "").font(.headline)
                Spacer(minLength: 0)
                if let a = w.age_min { Text("\(a)m").font(.caption2).foregroundStyle(.secondary) }
            }
            HStack(spacing: 6) {
                Text(w.type ?? "").font(.caption.bold()).foregroundStyle(Color(hex: w.type_color))
                if let g = w.gust { Text("G \(trim(g))").font(.caption).foregroundStyle(.secondary) }
            }
            if let f = w.forecast {
                HStack(spacing: 4) {
                    Image(systemName: "chart.line.uptrend.xyaxis").font(.caption2)
                    Text("\(trim(f.kts)) \(f.compass ?? "")").font(.caption)
                    Text(f.type ?? "").font(.caption2.bold()).foregroundStyle(Color(hex: f.type_color))
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func hours(_ hs: [Live.Hour]) -> some View {
        HStack(alignment: .top, spacing: 2) {
            ForEach(Array(hs.prefix(12).enumerated()), id: \.element.id) { i, h in
                VStack(spacing: 2) {
                    RoundedRectangle(cornerRadius: 2).fill(Color(hex: h.color)).frame(height: 12)
                    Text(i % 3 == 0 ? h.t : " ").font(.system(size: 8)).foregroundStyle(.secondary).lineLimit(1)
                }
            }
        }
    }

    private func buoy(_ b: Live.Buoy) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack {
                Text(b.name).font(.caption.bold()).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let a = b.age_min { Text("\(a)m").font(.caption2).foregroundStyle(.secondary) }
            }
            Text("\(trim(b.wvht_ft)) ft @ \(trim(b.dpd_s))s \(b.mwd_compass ?? "")").font(.body.bold())
            if let s = b.swh_ft {
                Text("\(Image(systemName: "water.waves")) \(trim(s)) @ \(trim(b.swp_s))s \(b.swd ?? "")").font(.caption)
            }
            if let w = b.wwh_ft {
                Text("\(Image(systemName: "wind")) \(trim(w)) @ \(trim(b.wwp_s))s").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
