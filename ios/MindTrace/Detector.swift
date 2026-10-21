import Foundation

struct ScanResult {
    let magnet: Bool?        // nil = for få målinger
    let peak: Double
    let samples: Int
    let baseline: Double?
}

/// Grundmåling = median af de seneste ~1,5 s før scanning.
/// Magnet = |B| afviger mindst `threshold` µT i `consecutive` målinger i træk.
final class Detector {
    private var recent: [Double] = []
    private let recentMax = 75            // 1,5 s ved 50 Hz
    private(set) var smoothed: Double?
    private(set) var reference: Double?   // fri reference til test i panelet

    private var scanning = false
    private var baseline: Double?
    private var run = 0, bestRun = 0, count = 0
    private var peak = 0.0

    var threshold = 20.0
    var consecutive = 4

    func push(_ m: Double) {
        smoothed = smoothed.map { $0 + 0.25 * (m - $0) } ?? m
        if scanning, let b = baseline {
            let dev = abs(m - b)
            count += 1
            peak = max(peak, dev)
            run = dev >= threshold ? run + 1 : 0
            bestRun = max(bestRun, run)
        } else {
            recent.append(m)
            if recent.count > recentMax { recent.removeFirst(recent.count - recentMax) }
        }
    }

    var liveBaseline: Double? { Self.median(recent) }

    func setReference() { reference = smoothed }

    func beginScan() {
        baseline = recent.count >= 15 ? Self.median(recent) : nil
        run = 0; bestRun = 0; count = 0; peak = 0
        scanning = true
    }

    func endScan() -> ScanResult {
        scanning = false
        guard let b = baseline, count >= 10 else {
            return ScanResult(magnet: nil, peak: peak, samples: count, baseline: baseline)
        }
        return ScanResult(magnet: bestRun >= consecutive, peak: peak, samples: count, baseline: b)
    }

    func cancelScan() { scanning = false }

    static func median(_ a: [Double]) -> Double? {
        guard !a.isEmpty else { return nil }
        let s = a.sorted()
        return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
    }
}
