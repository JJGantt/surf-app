import AppIntents

/// What the Surf control opens. A control that launches its app takes an `OpenIntent`, and an
/// `OpenIntent` opens a TARGET, so this enum exists to be that target even though there is only one.
enum SurfTarget: String, AppEnum {
    case face

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Gnarcast"
    static var caseDisplayRepresentations: [SurfTarget: DisplayRepresentation] = [.face: "Surf"]
}

/// Opens the watch app. IT LIVES IN `Shared/` DELIBERATELY, so it compiles into the WATCH APP as well
/// as the widget extension — the system launches the app and runs `perform()` THERE. An intent that
/// exists only in the extension gives a control that draws correctly and does nothing when tapped,
/// which is exactly how this failed.
///
/// And it is an `OpenIntent`, not a plain `AppIntent` with `openAppWhenRun`. That is the shape a
/// launching control takes; the flag alone does not carry a control to its app.
struct OpenSurfIntent: OpenIntent {
    static var title: LocalizedStringResource = "Surf"

    @Parameter(title: "Target") var target: SurfTarget

    init() {
        target = .face
    }

    func perform() async throws -> some IntentResult { .result() }
}
