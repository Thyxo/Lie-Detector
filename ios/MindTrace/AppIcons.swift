import UIKit

/// Valgbare app-ikoner. `nil` = standardikonet (AppIcon).
enum AppIconChoice: String, CaseIterable, Identifiable {
    case fingerprint, glow, classic
    var id: String { rawValue }

    var iconName: String? {
        switch self {
        case .fingerprint: return nil
        case .glow: return "AppIconGlow"
        case .classic: return "AppIconClassic"
        }
    }

    var preview: String {
        switch self {
        case .fingerprint: return "IconPreviewFingerprint"
        case .glow: return "IconPreviewGlow"
        case .classic: return "IconPreviewClassic"
        }
    }

    func label(_ s: AppSettings) -> String {
        switch self {
        case .fingerprint: return s.tr("Fingeraftryk", "Fingerprint")
        case .glow: return s.tr("Neon", "Neon")
        case .classic: return s.tr("Klassisk", "Classic")
        }
    }

    @MainActor
    static var current: AppIconChoice {
        let name = UIApplication.shared.alternateIconName
        return allCases.first { $0.iconName == name } ?? .fingerprint
    }

    @MainActor
    func apply(_ done: @escaping (Bool) -> Void) {
        guard UIApplication.shared.supportsAlternateIcons else { done(false); return }
        UIApplication.shared.setAlternateIconName(iconName) { error in
            DispatchQueue.main.async { done(error == nil) }
        }
    }
}
