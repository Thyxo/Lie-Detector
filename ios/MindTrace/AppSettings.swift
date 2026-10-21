import Foundation
import Combine

enum Verdict: String {
    case sandt, falsk
    var label: String { self == .sandt ? "Sandt" : "Falsk" }
}

enum SensorSource: String, CaseIterable, Identifiable {
    case calibrated, raw
    var id: String { rawValue }
    var label: String { self == .calibrated ? "Kalibreret" : "Rå" }
}

/// Alle indstillinger gemmes i UserDefaults (lokalt på telefonen).
final class AppSettings: ObservableObject {
    private let d = UserDefaults.standard

    @Published var autoSensor: Bool { didSet { d.set(autoSensor, forKey: "autoSensor") } }
    @Published var volumeButtons: Bool { didSet { d.set(volumeButtons, forKey: "volumeButtons") } }
    @Published var haptic: Bool { didSet { d.set(haptic, forKey: "haptic") } }
    @Published var dot: Bool { didSet { d.set(dot, forKey: "dot") } }
    @Published var threshold: Double { didSet { d.set(threshold, forKey: "threshold") } }
    @Published var consecutive: Int { didSet { d.set(consecutive, forKey: "consecutive") } }
    @Published var thinkMin: Double { didSet { d.set(thinkMin, forKey: "thinkMin"); if thinkMax < thinkMin { thinkMax = thinkMin } } }
    @Published var thinkMax: Double { didSet { d.set(thinkMax, forKey: "thinkMax"); if thinkMin > thinkMax { thinkMin = thinkMax } } }
    @Published var source: SensorSource { didSet { d.set(source.rawValue, forKey: "source") } }
    @Published var fallback: Verdict { didSet { d.set(fallback.rawValue, forKey: "fallback") } }

    init() {
        d.register(defaults: [
            "autoSensor": true, "volumeButtons": true, "haptic": true, "dot": true,
            "threshold": 20.0, "consecutive": 4, "thinkMin": 2.0, "thinkMax": 4.0,
            "source": SensorSource.calibrated.rawValue, "fallback": Verdict.sandt.rawValue,
        ])
        autoSensor = d.bool(forKey: "autoSensor")
        volumeButtons = d.bool(forKey: "volumeButtons")
        haptic = d.bool(forKey: "haptic")
        dot = d.bool(forKey: "dot")
        threshold = d.double(forKey: "threshold")
        consecutive = d.integer(forKey: "consecutive")
        thinkMin = d.double(forKey: "thinkMin")
        thinkMax = d.double(forKey: "thinkMax")
        source = SensorSource(rawValue: d.string(forKey: "source") ?? "") ?? .calibrated
        fallback = Verdict(rawValue: d.string(forKey: "fallback") ?? "") ?? .sandt
    }
}
