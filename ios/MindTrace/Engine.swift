import Foundation
import Combine
import UIKit

enum Screen: Equatable {
    case start
    case thinking
    case result(Verdict)
}

struct LogEntry: Identifiable {
    let id = UUID()
    let time: Date
    let text: String
}

/// Styrer forløbet: Start → Tænker (2–4 s) → Sandt/Falsk.
/// Afgørelsen kommer fra volumenknapperne (hvis trykket) ellers fra sensoren.
@MainActor
final class Engine: ObservableObject {
    @Published private(set) var screen: Screen = .start
    @Published private(set) var armed: Verdict?            // fra volumenknapper
    @Published private(set) var log: [LogEntry] = []
    @Published var panelOpen = false

    // Live-visning i panelet (opdateres ~10 gange i sekundet)
    @Published private(set) var liveField: Double?
    @Published private(set) var liveBaseline: Double?
    @Published private(set) var liveReference: Double?
    @Published private(set) var sensorLive = false

    let settings: AppSettings
    let sensor = MagnetSensor()
    let detector = Detector()
    let volume = VolumeButtons()

    private var bag = Set<AnyCancellable>()
    private var scanToken = 0
    private var lastPublish = Date.distantPast
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    init(settings: AppSettings) {
        self.settings = settings
        detector.threshold = settings.threshold
        detector.consecutive = settings.consecutive

        sensor.onSample = { [weak self] m in self?.sample(m) }

        settings.$threshold.sink { [weak self] in self?.detector.threshold = $0 }.store(in: &bag)
        settings.$consecutive.sink { [weak self] in self?.detector.consecutive = $0 }.store(in: &bag)
        settings.$source.dropFirst().sink { [weak self] src in self?.sensor.start(source: src) }.store(in: &bag)

        volume.onUp = { [weak self] in self?.volumePressed(.sandt) }
        volume.onDown = { [weak self] in self?.volumePressed(.falsk) }

        Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let live = self.sensor.isLive
                if live != self.sensorLive { self.sensorLive = live }
            }
            .store(in: &bag)
    }

    func becameActive() {
        if !sensor.running { sensor.start(source: settings.source) }
        volume.activate()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    // MARK: Sensor
    private func sample(_ m: Double) {
        detector.push(m)
        let now = Date()
        if panelOpen, now.timeIntervalSince(lastPublish) > 0.1 {
            lastPublish = now
            liveField = detector.smoothed
            liveBaseline = detector.liveBaseline
            liveReference = detector.reference
        }
    }

    func setReference() { detector.setReference(); liveReference = detector.reference }

    // MARK: Forløb
    func tapStart() {
        guard screen == .start else { return }
        scanToken += 1
        let token = scanToken
        detector.beginScan()
        screen = .thinking
        let lo = settings.thinkMin, hi = max(settings.thinkMin, settings.thinkMax)
        let duration = Double.random(in: lo...hi)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self, self.scanToken == token, self.screen == .thinking else { return }
            self.finish()
        }
    }

    private func finish() {
        let r = detector.endScan()
        let verdict: Verdict
        var source: String
        if let a = armed {
            verdict = a
            source = "volumenknap"
        } else if settings.autoSensor, sensor.isLive || r.samples > 0, let magnet = r.magnet {
            verdict = magnet ? .falsk : .sandt
            source = "sensor"
        } else {
            verdict = settings.fallback
            source = settings.autoSensor ? "standard (ingen sensordata)" : "standard"
        }
        let sensorText: String
        if let magnet = r.magnet {
            sensorText = String(format: "%@ · top Δ %.0f µT · n=%d", magnet ? "magnet" : "ingen magnet", r.peak, r.samples)
        } else {
            sensorText = "ingen gyldige data (n=\(r.samples))"
        }
        addLog("\(verdict.label) ← \(source) | sensor: \(sensorText)")
        armed = nil
        screen = .result(verdict)
    }

    func tapResult() {
        guard case .result = screen else { return }
        screen = .start
    }

    private func volumePressed(_ v: Verdict) {
        guard settings.volumeButtons, !panelOpen else { return }
        if case .result = screen { /* tryk på resultat-skærmen gælder næste afsløring */ }
        armed = v
        if settings.haptic { haptic.impactOccurred() }
    }

    // MARK: Hemmelig menu / panik
    func panic() {
        scanToken += 1
        detector.cancelScan()
        armed = nil
        settings.volumeButtons = false
        settings.autoSensor = true
        screen = .start
        addLog("PANIK – volumenknapper slået fra, kun sensor")
        let n = UINotificationFeedbackGenerator()
        n.notificationOccurred(.warning)
    }

    func resetToStart() {
        scanToken += 1
        detector.cancelScan()
        armed = nil
        screen = .start
    }

    private func addLog(_ s: String) {
        log.insert(LogEntry(time: Date(), text: s), at: 0)
        if log.count > 12 { log.removeLast(log.count - 12) }
    }
}
