import Foundation
import Combine

enum Verdict: String {
    case sandt, falsk
}

enum AppLanguage: String, CaseIterable, Identifiable { case da, en; var id: String { rawValue } }
enum AppMode: String, CaseIterable, Identifiable { case normal, hidden; var id: String { rawValue } }

enum AppFont: String, CaseIterable, Identifiable {
    case bungee, rubik, lilita, luckiest, pixel, gill
    var id: String { rawValue }
    var postScript: String {
        switch self {
        case .bungee: return "Bungee-Regular"
        case .rubik: return "RubikMonoOne-Regular"
        case .lilita: return "LilitaOne"
        case .luckiest: return "LuckiestGuy-Regular"
        case .pixel: return "PressStart2P-Regular"
        case .gill: return "GillSans"
        }
    }
    var displayName: String {
        switch self {
        case .bungee: return "Bungee"
        case .rubik: return "Rubik Mono"
        case .lilita: return "Lilita"
        case .luckiest: return "Luckiest Guy"
        case .pixel: return "Pixel"
        case .gill: return "Gill Sans"
        }
    }
    /// Pixel-skriften er meget bred.
    var scale: Double { self == .pixel ? 0.55 : 1 }
}

/// Alle indstillinger gemmes lokalt i UserDefaults.
final class AppSettings: ObservableObject {
    static let defaultThreshold = 40.0
    private let d = UserDefaults.standard

    @Published var threshold: Double { didSet { d.set(threshold, forKey: "threshold2") } }
    @Published var consecutive: Int { didSet { d.set(consecutive, forKey: "consecutive2") } }
    @Published var vibDelay: Double { didSet { d.set(vibDelay, forKey: "vibDelay") } }
    @Published var vibEnabled: Bool { didSet { d.set(vibEnabled, forKey: "vibEnabled") } }
    @Published var vibStrength: Double { didSet { d.set(vibStrength, forKey: "vibStrength") } }
    @Published var coinDot: Bool { didSet { d.set(coinDot, forKey: "coinDot") } }
    @Published var sensorMode: SensorMode { didSet { d.set(sensorMode.rawValue, forKey: "sensorMode") } }
    @Published var mode: AppMode { didSet { d.set(mode.rawValue, forKey: "mode") } }
    @Published var language: AppLanguage { didSet { d.set(language.rawValue, forKey: "language") } }
    @Published var font: AppFont { didSet { d.set(font.rawValue, forKey: "font") } }
    @Published var sound: Bool { didSet { d.set(sound, forKey: "sound") } }
    @Published var soundVolume: Double { didSet { d.set(soundVolume, forKey: "soundVolume") } }
    @Published var hasBackground: Bool { didSet { d.set(hasBackground, forKey: "hasBackground"); backgroundVersion += 1 } }
    @Published var backgroundVersion = 0

    init() {
        d.register(defaults: [
            "threshold2": AppSettings.defaultThreshold, "consecutive2": 3, "vibDelay": 1.0,
            "vibEnabled": true, "vibStrength": 1.0, "coinDot": false,
            "sensorMode": SensorMode.auto.rawValue, "mode": AppMode.normal.rawValue,
            "language": AppLanguage.en.rawValue, "font": AppFont.bungee.rawValue,
            "sound": true, "soundVolume": 1.0, "hasBackground": false,
        ])
        threshold = d.double(forKey: "threshold2")
        consecutive = d.integer(forKey: "consecutive2")
        vibDelay = d.double(forKey: "vibDelay")
        vibEnabled = d.bool(forKey: "vibEnabled")
        vibStrength = min(1, max(0.1, d.double(forKey: "vibStrength")))
        coinDot = d.bool(forKey: "coinDot")
        sensorMode = SensorMode(rawValue: d.string(forKey: "sensorMode") ?? "") ?? .auto
        mode = AppMode(rawValue: d.string(forKey: "mode") ?? "") ?? .normal
        language = AppLanguage(rawValue: d.string(forKey: "language") ?? "") ?? .en
        font = AppFont(rawValue: d.string(forKey: "font") ?? "") ?? .bungee
        sound = d.bool(forKey: "sound")
        soundVolume = min(1, max(0, d.double(forKey: "soundVolume")))
        hasBackground = d.bool(forKey: "hasBackground")
    }

    /// Dansk/engelsk tekst.
    func tr(_ da: String, _ en: String) -> String { language == .en ? en : da }

    func word(_ v: Verdict) -> String { v == .sandt ? tr("Sandt", "True") : tr("Falsk", "False") }
}
