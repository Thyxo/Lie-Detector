import SwiftUI
import CoreText

enum FontLoader {
    /// Registrerer de medfølgende skrifter (ttf i appen).
    static func registerAll() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls { CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil) }
    }
}

extension AppFont {
    func font(_ size: Double) -> Font { .custom(postScript, size: size * scale) }
}
