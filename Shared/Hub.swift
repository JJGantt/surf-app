import Foundation
import CryptoKit
import SwiftUI

// The hub on Fly is this app's backend: the surf page, the live feed, the sign-in check.
//
// The hub knows one password. Its token is sha256("status-hub:" + password) in hex — the same value
// its web cookie `hub` holds and its API accepts as the X-Hub-Token header — so the password is typed
// once, kept in the Keychain on the phone, and the token is derived from it.
enum Hub {
    static let host = "https://jared-status-hub.fly.dev"

    static func token(for password: String) -> String {
        SHA256.hash(data: Data(("status-hub:" + password).utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// True when the hub accepts this token.
    static func check(token: String) async -> Bool {
        guard let url = URL(string: host + "/api/surf/live") else { return false }
        var req = URLRequest(url: url)
        req.setValue(token, forHTTPHeaderField: "X-Hub-Token")
        guard let (_, resp) = try? await URLSession.shared.data(for: req) else { return false }
        return (resp as? HTTPURLResponse)?.statusCode == 200
    }

    /// The live feed — what the watch draws. The page on the phone reads the same payload as a stream.
    static func live(token: String) async throws -> Live {
        guard let url = URL(string: host + "/api/surf/live") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue(token, forHTTPHeaderField: "X-Hub-Token")
        req.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.userAuthenticationRequired) }
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
        let type: String?
        let type_color: String?
        let age_min: Int?
        let forecast: Forecast?
    }
    struct Forecast: Decodable {
        let kts: Double?
        let compass: String?
        let type: String?
        let type_color: String?
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
        let t: String
        let rating: String
        let color: String
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
    let wind: Wind?
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

/// One decimal, and no ".0".
func trim(_ v: Double?) -> String {
    guard let v else { return "—" }
    return v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v)
}
