import SwiftUI
import CoreText

/// App entry point. The whole MVP flow lives behind `RootView`.
@main
struct KwizzApp: App {
    init() { FontRegistration.registerAll() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
    }
}

/// Registers the bundled .ttf fonts at launch so `Font.custom` resolves them.
/// If a file is missing, SwiftUI falls back to the system font automatically.
enum FontRegistration {
    static func registerAll() {
        for name in ["PressStart2P-Regular", "SpaceMono-Regular", "SpaceMono-Bold"] {
            guard let url = Bundle.main.url(forResource: name, withExtension: "ttf") else { continue }
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}
