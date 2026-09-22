import SwiftUI
import WebKit
import Security
import WatchConnectivity

@main
struct GnarcastApp: App {
    @StateObject private var session = Session()

    init() { WatchLink.shared.start() }

    var body: some Scene {
        WindowGroup {
            Group {
                if let token = session.token {
                    SurfPage(token: token, signedOut: { session.signOut() }).ignoresSafeArea()
                } else {
                    SignIn(session: session)
                }
            }
            .preferredColorScheme(.dark)
            .background(Color.black)
        }
    }
}

// ---- the password, kept in the Keychain ------------------------------------------------------------

enum Keychain {
    private static let service = "com.jaredgantt.surf"
    private static let account = "hubPassword"
    private static var base: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }
    static func save(_ password: String) {
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = Data(password.utf8)
        SecItemAdd(add as CFDictionary, nil)
    }
    static func load() -> String? {
        var q = base
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
    static func clear() { SecItemDelete(base as CFDictionary) }
}

@MainActor
final class Session: ObservableObject {
    @Published var token: String? = Keychain.load().map(Hub.token(for:))

    func signIn(_ password: String) async -> Bool {
        let t = Hub.token(for: password)
        guard await Hub.check(token: t) else { return false }
        Keychain.save(password)
        token = t
        WatchLink.shared.push()
        return true
    }

    func signOut() {
        Keychain.clear()
        token = nil
        WatchLink.shared.push()
    }
}

struct SignIn: View {
    @ObservedObject var session: Session
    @State private var password = ""
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Text("Gnarcast").font(.largeTitle.bold())
            SecureField("Hub password", text: $password)
                .textContentType(.password)
                .submitLabel(.go)
                .onSubmit(go)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(white: 0.12)))
            Button(action: go) {
                if busy { ProgressView() } else { Text("Sign in").bold().frame(maxWidth: .infinity) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(password.isEmpty || busy)
            if failed { Image(systemName: "xmark.octagon.fill").foregroundStyle(.red).font(.title2) }
            Spacer()
        }
        .padding(24)
    }

    private func go() {
        guard !password.isEmpty, !busy else { return }
        busy = true
        Task {
            failed = !(await session.signIn(password))
            busy = false
        }
    }
}

// ---- the page ---------------------------------------------------------------------------------------

/// The hub's /surf page, signed in with the `hub` cookie. The page is live on its own (it rides the
/// hub's surf stream), so this view never reloads it.
struct SurfPage: UIViewRepresentable {
    let token: String
    let signedOut: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(signedOut: signedOut) }

    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        wv.isOpaque = false
        wv.backgroundColor = .black
        wv.scrollView.backgroundColor = .black
        // The page pads itself with env(safe-area-inset-*) (viewport-fit=cover); letting the scroll view
        // inset it as well would pad it twice.
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.navigationDelegate = context.coordinator
        let host = URL(string: Hub.host)?.host ?? ""
        let cookie = HTTPCookie(properties: [.domain: host, .path: "/", .name: "hub", .value: token, .secure: "TRUE",
                                             .expires: Date(timeIntervalSinceNow: 3650 * 86400)])
        let req = URLRequest(url: URL(string: Hub.host + "/surf")!)
        if let cookie {
            wv.configuration.websiteDataStore.httpCookieStore.setCookie(cookie) { wv.load(req) }
        } else {
            wv.load(req)
        }
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        let signedOut: () -> Void
        init(signedOut: @escaping () -> Void) { self.signedOut = signedOut }
        // The hub sends a request it does not recognise to /login: the password changed. Back to sign-in
        // rather than showing the hub's own login form inside this app.
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if action.request.url?.path == "/login" {
                decisionHandler(.cancel)
                DispatchQueue.main.async { self.signedOut() }
                return
            }
            decisionHandler(.allow)
        }
    }
}

// ---- the watch's token ------------------------------------------------------------------------------

/// Hands the hub token to the watch app, which has no password and no web view of its own. Sent as
/// application context, which the system keeps and delivers whenever the watch app next runs; the
/// watch can also ask with a message. An empty string means signed out.
final class WatchLink: NSObject, WCSessionDelegate {
    static let shared = WatchLink()

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private var token: String { Keychain.load().map(Hub.token(for:)) ?? "" }

    func push() {
        let s = WCSession.default
        guard WCSession.isSupported(), s.activationState == .activated, s.isPaired, s.isWatchAppInstalled else { return }
        try? s.updateApplicationContext(["hubToken": token])
    }

    func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) { push() }
    func sessionWatchStateDidChange(_ session: WCSession) { push() }
    func session(_ session: WCSession, didReceiveMessage message: [String: Any],
                 replyHandler: @escaping ([String: Any]) -> Void) { replyHandler(["hubToken": token]) }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
}
