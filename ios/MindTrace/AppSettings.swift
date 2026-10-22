import Foundation
import Combine

enum Verdict: String {
    case sandt, falsk
    var opposite: Verdict { self == .sandt ? .falsk : .sandt }
}

enum AppLanguage: String, CaseIterable, Identifiable { case da, en; var id: String { rawValue } }
enum AppMode: String, CaseIterable, Identifiable { case normal, hidden; var id: String { rawValue } }
enum VibRepeat: String, CaseIterable, Identifiable { case five, untilTap; var id: String { rawValue } }

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

    @Published var autoSensor: Bool { didSet { d.set(autoSensor, forKey: "autoSensor") } }
    @Published var volumeButtons: Bool { didSet { d.set(volumeButtons, forKey: "volumeButtons") } }
    @Published var haptic: Bool { didSet { d.set(haptic, forKey: "haptic") } }
    @Published var dot: Bool { didSet { d.set(dot, forKey: "dot") } }
    @Published var threshold: Double { didSet { d.set(threshold, forKey: "threshold2") } }
    @Published var consecutive: Int { didSet { d.set(consecutive, forKey: "consecutive2") } }
    @Published var thinkMin: Double { didSet { d.set(thinkMin, forKey: "thinkMin"); if thinkMax < thinkMin { thinkMax = thinkMin } } }
    @Published var thinkMax: Double { didSet { d.set(thinkMax, forKey: "thinkMax"); if thinkMin > thinkMax { thinkMin = thinkMax } } }
    @Published var sensorMode: SensorMode { didSet { d.set(sensorMode.rawValue, forKey: "sensorMode") } }
    @Published var fallback: Verdict { didSet { d.set(fallback.rawValue, forKey: "fallback") } }
    @Published var magnetMeans: Verdict { didSet { d.set(magnetMeans.rawValue, forKey: "magnetMeans") } }
    @Published var mode: AppMode { didSet { d.set(mode.rawValue, forKey: "mode") } }
    @Published var vibRepeat: VibRepeat { didSet { d.set(vibRepeat.rawValue, forKey: "vibRepeat") } }
    @Published var language: AppLanguage { didSet { d.set(language.rawValue, forKey: "language") } }
    @Published var font: AppFont { didSet { d.set(font.rawValue, forKey: "font") } }
    @Published var sound: Bool { didSet { d.set(sound, forKey: "sound") } }
    @Published var hasBackground: Bool { didSet { d.set(hasBackground, forKey: "hasBackground"); backgroundVersion += 1 } }
    @Published var backgroundVersion = 0

    init() {
        d.register(defaults: [
            "autoSensor": true, "volumeButtons": true, "haptic": true, "dot": true,
            "threshold2": AppSettings.defaultThreshold, "consecutive2": 3, "thinkMin": 2.0, "thinkMax": 4.0,
            "sensorMode": SensorMode.auto.rawValue, "fallback": Verdict.sandt.rawValue,
            "magnetMeans": Verdict.falsk.rawValue, "mode": AppMode.normal.rawValue,
            "vibRepeat": VibRepeat.five.rawValue, "language": AppLanguage.da.rawValue,
            "font": AppFont.bungee.rawValue, "sound": true, "hasBackground": false,
        ])
        autoSensor = d.bool(forKey: "autoSensor")
        volumeButtons = d.bool(forKey: "volumeButtons")
        haptic = d.bool(forKey: "haptic")
        dot = d.bool(forKey: "dot")
        threshold = d.double(forKey: "threshold2")
        consecutive = d.integer(forKey: "consecutive2")
        thinkMin = d.double(forKey: "thinkMin")
        thinkMax = d.double(forKey: "thinkMax")
        sensorMode = SensorMode(rawValue: d.string(forKey: "sensorMode") ?? "") ?? .auto
        fallback = Verdict(rawValue: d.string(forKey: "fallback") ?? "") ?? .sandt
        magnetMeans = Verdict(rawValue: d.string(forKey: "magnetMeans") ?? "") ?? .falsk
        mode = AppMode(rawValue: d.string(forKey: "mode") ?? "") ?? .normal
        vibRepeat = VibRepeat(rawValue: d.string(forKey: "vibRepeat") ?? "") ?? .five
        language = AppLanguage(rawValue: d.string(forKey: "language") ?? "") ?? .da
        font = AppFont(rawValue: d.string(forKey: "font") ?? "") ?? .bungee
        sound = d.bool(forKey: "sound")
        hasBackground = d.bool(forKey: "hasBackground")
    }

    /// Dansk/engelsk tekst.
    func tr(_ da: String, _ en: String) -> String { language == .en ? en : da }

    func word(_ v: Verdict) -> String { v == .sandt ? tr("Sandt", "True") : tr("Falsk", "False") }
}
