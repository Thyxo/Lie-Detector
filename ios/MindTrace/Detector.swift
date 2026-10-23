import Foundation

/// Én måling fra telefonen. Alle felter er valgfrie, fordi sensorerne leverer hver for sig.
struct MagSample {
    var raw: Vec3?        // rå magnetometer (µT, telefonens akser, inkl. telefonens egen magnetisme)
    var cal: Vec3?        // iOS-kalibreret felt (µT), kun når kalibreringen er gyldig
    var rot: Mat3?        // telefonens orientering
    var gravity: Vec3?    // tyngdekraft i telefonens akser (bruges til at vælge matrix-konvention)
}

enum SensorMode: String, CaseIterable, Identifiable {
    case auto   // drejnings-kompenseret
    case raw    // rå vektor, telefonen skal holdes roligt
    var id: String { rawValue }
}

/// Omsætter målinger til et felt i "rummets" akser, så det ikke ændrer sig, når telefonen drejes.
/// Kun en magnet tæt på giver så et udslag.
final class FieldTracker {
    private(set) var bias: Vec3?
    var biasFrozen = false
    var mode: SensorMode = .auto

    func field(_ s: MagSample) -> Vec3? {
        // Telefonens egen magnetisme (bias) = rå − kalibreret. Læres løbende, fryses under scanning,
        // så iOS' kalibrering ikke kan "vænne sig til" magneten.
        if let raw = s.raw, let cal = s.cal, !biasFrozen {
            let b = raw - cal
            if b.isFinite { bias = bias.map { $0 + (b - $0) * 0.05 } ?? b }
        }
        if mode == .raw { return s.raw ?? s.cal }
        guard let rot = s.rot else { return s.raw ?? s.cal }
        let device: Vec3
        if let raw = s.raw, let b = bias { device = raw - b }
        else if let cal = s.cal { device = cal }
        else { return s.raw }
        return FieldTracker.toWorld(device, rot: rot, gravity: s.gravity)
    }

    /// CoreMotions matrix-konvention afgøres med tyngdekraften: i rummets akser peger den lige ned (z = −1).
    static func toWorld(_ v: Vec3, rot: Mat3, gravity: Vec3?) -> Vec3 {
        let t = rot.transposed
        guard let g = gravity, g.length > 0.5 else { return t.mul(v) }
        let za = rot.mul(g).z / g.length, zb = t.mul(g).z / g.length
        return abs(za + 1) < abs(zb + 1) ? rot.mul(v) : t.mul(v)
    }
}

struct ScanResult {
    let magnet: Bool?      // nil = for få målinger
    let peak: Double       // største udslag holdt i `consecutive` målinger (µT)
    let samples: Int
}

/// Grundmåling lige før tryk → største vedvarende udslag under scanning → sammenlign med tærsklen.
final class Detector {
    let tracker = FieldTracker()
    var threshold = 40.0
    var consecutive = 3

    private var idle: [Vec3] = []
    private let idleMax = 60
    private(set) var current: Vec3?

    private struct Scan { var base: Vec3; var recent: [Double] = []; var peak = 0.0; var n = 0 }
    private var scan: Scan?
    var isScanning: Bool { scan != nil }

    /// Status midt i en scanning: nil = for få målinger endnu, ellers om udslaget har passeret tærsklen.
    /// "Låser": når mønten først er fundet, forbliver svaret magnet resten af scanningen.
    var scanStatus: Bool? {
        guard let sc = scan, sc.n >= 10 else { return nil }
        return sc.peak >= threshold
    }
    var scanPeak: Double { scan?.peak ?? 0 }

    // Live-måling til panelet
    private var liveRef: Vec3?
    private(set) var liveAnomaly: Double?

    func push(_ s: MagSample) {
        guard let w = tracker.field(s), w.isFinite, w.length > 0.01 else { return }
        current = w
        if var sc = scan {
            let a = (w - sc.base).length
            sc.n += 1
            sc.recent.append(a)
            if sc.recent.count > max(1, consecutive) { sc.recent.removeFirst() }
            if sc.recent.count >= max(1, consecutive) { sc.peak = max(sc.peak, sc.recent.min() ?? 0) }
            scan = sc
        } else {
            idle.append(w)
            if idle.count > idleMax { idle.removeFirst(idle.count - idleMax) }
        }
        if liveRef == nil { liveRef = w }
        if let r = liveRef { liveAnomaly = (w - r).length }
    }

    /// Starter scanning. Grundmåling = gennemsnit af de seneste ~0,3 s.
    @discardableResult
    func beginScan() -> Bool {
        guard idle.count >= 5, let base = Vec3.mean(idle.suffix(30)) else { scan = nil; return false }
        tracker.biasFrozen = true
        scan = Scan(base: base)
        return true
    }

    func endScan() -> ScanResult {
        tracker.biasFrozen = false
        defer { scan = nil; idle.removeAll() }
        guard let sc = scan, sc.n >= 10 else { return ScanResult(magnet: nil, peak: scan?.peak ?? 0, samples: scan?.n ?? 0) }
        return ScanResult(magnet: sc.peak >= threshold, peak: sc.peak, samples: sc.n)
    }

    func cancelScan() { tracker.biasFrozen = false; scan = nil }

    /// Nyt gæt: glem alt fra sidste scanning (grundmåling, top, live-reference),
    /// så næste grundmåling tages helt frisk.
    /// Rører IKKE tærsklen fra "Lær min mønt" eller den lærte telefon-magnetisme (bias).
    func resetForNewGuess() {
        tracker.biasFrozen = false
        scan = nil
        idle.removeAll()
        liveRef = nil
        liveAnomaly = nil
    }

    func resetLive() { liveRef = current }

    /// Tærskel ud fra "Lær min mønt": udslag uden mønt (støj) og med mønt.
    static func learnedThreshold(noise: Double, coin: Double) -> Double? {
        guard coin >= noise * 1.5 + 5 else { return nil }
        return (noise + (coin - noise) * 0.35).rounded()
    }
}
