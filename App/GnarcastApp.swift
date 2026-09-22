import SwiftUI
import WebKit

// The whole iPhone app: the hub's /surf page, full screen. That page is public (status-hub server.js,
// PUBLIC_SURF) and pushes itself from /api/surf/stream, so there is nothing to sign in to and nothing
// here to refresh.
@main
struct GnarcastApp: App {
    var body: some Scene {
        WindowGroup {
            SurfPage()
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
                .background(Color.black)
        }
    }
}

struct SurfPage: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let wv = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        wv.isOpaque = false
        wv.backgroundColor = .black
        wv.scrollView.backgroundColor = .black
        // The page pads itself with env(safe-area-inset-*) (viewport-fit=cover); letting the scroll
        // view inset it as well would pad it twice.
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.load(URLRequest(url: URL(string: Hub.host + "/surf")!))
        return wv
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
