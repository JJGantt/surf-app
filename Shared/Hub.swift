import Foundation
import SwiftUI

// The hub on Fly is this app's backend. Its surf page and surf feeds are PUBLIC (status-hub
// server.js, PUBLIC_SURF) — a forecast, the measured wind and the buoys, nothing personal — so
// there is no password here, no token and nothing to sign in to.
enum Hub {
    static let host = "https://jared-status-hub.fly.dev"

    /// The live feed — what the watch draws. The phone shows the page, which streams the same payload.
    static func live() async throws -> Live {
        guard let url = URL(string: host + "/api/surf/live") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Live.self, from: data)
    }
}

// /api/surf/live, the parts the watch draws. Every value arrives finished from the hub — colours,
// labels, compass points — so nothing here derives one.
struct Live: Decodable {
    struct Wind: Decodable {
        let kts: Double?
        let gust: Double?
        let compass: String?
        let dir_to: Double?     // where the wind blows TO, for an arrow
        let type: String?
        let type_color: String?
        let age_min: Int?
        let stale: Bool?        // against the station's own cadence, not one number
        let forecast: Forecast?
    }
    struct Forecast: Decodable {
        let kts: Double?
        let compass: String?
        let type: String?
        let type_color: String?
    }
    /// The two buoys blended into one sea for Mayport, which sits between them (status-hub
    /// lib/livebuoy.js). What to read; the buoys themselves are the detail behind it.
    struct Sea: Decodable {
        let wvht_ft: Double?
        let dpd_s: Double?
        let mwd_compass: String?
        let swh_ft: Double?
        let swp_s: Double?
        let swd: String?
        let wwh_ft: Double?
        let wwp_s: Double?
        let wwd: String?
        let water_f: Double?
        let water_color: String?   // the wetsuit scale, cold blue to warm orange
        let age_min: Int?
    }
    struct Buoy: Decodable, Identifiable {
        let station: String
        let name: String
        let wvht_ft: Double?
        let dpd_s: Double?
        let mwd_compass: String?
        let swh_ft: Double?
        let swp_s: Double?
        let swd: String?
        let wwh_ft: Double?
        let wwp_s: Double?
        let age_min: Int?
        var id: String { station }
    }
    struct Hour: Decodable, Identifiable {
        let t: String           // the label a strip prints: "3p"
        let h: Int              // the clock hour, 0-23: where a dial puts it
        let rating: String
        let color: String       // the rating's band colour
        let size_color: String? // wave height, on the heat map's own blue scale
        let ft_exact: Double?   // the aggregate that breaks, to a decimal — the range is coarse
        let swh_ft: Double?
        let swp_s: Double?
        let wind_kts: Double?
        let wind_type: String?
        let wind_color: String?
        let ft: String?
        var id: String { t }
    }
    struct Surf: Decodable { let current: Current? }
    struct Current: Decodable {
        let ratingLabel: String?
        let ratingColor: String?
        let hMin: Double?
        let hMax: Double?
    }
    /// ONE SURFABLE DAY, 6am to 6pm. The feed sends every day of the forecast from today out, so the
    /// same array is the ring the crown turns and the grid the other pane draws — one source, and no
    /// way for the two to disagree about a day. `water_f` is that day's water at local noon and is
    /// null past the marine model's range, which is shorter than the surf forecast's.
    struct Day: Decodable {
        let date: String
        let today: Bool
        let hours: [Hour]
        let water_f: Double?
        let water_color: String?
    }
    let wind: Wind?
    let days: [Day]
    /// The break's own clock, not the device's: which day to open on (today until 6pm, the next day
    /// after) and where now falls in the ring. `Calendar.current` is the PHONE's timezone, so a spoke
    /// placed from the device lands on the wrong hour the moment he travels.
    let open_day: Int?
    let now_hour: Double?
    let generated_at: String?
    let sea: Sea?
    let buoys: [Buoy]
    let hours: [Hour]
    let surf: Surf?
}

extension Color {
    /// `#rrggbb`, as the hub sends every colour.
    init(hex: String?) {
        var v: UInt64 = 0x8b96a5
        if let h = hex, h.hasPrefix("#"), let n = UInt64(h.dropFirst(), radix: 16) { v = n }
        self.init(red: Double((v >> 16) & 0xff) / 255, green: Double((v >> 8) & 0xff) / 255, blue: Double(v & 0xff) / 255)
    }
}

/// Rounded whole, for a figure where a decimal is noise.
func whole(_ v: Double?) -> String {
    guard let v else { return "—" }
    return String(Int(v.rounded()))
}

/// One decimal, and no ".0".
func trim(_ v: Double?) -> String {
    guard let v else { return "—" }
    return v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
}
