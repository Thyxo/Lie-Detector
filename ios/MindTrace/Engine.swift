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

enum LearnStep: Equatable { case idle, noise, coin, done }

/// Styrer forløbet.
/// Normal: Start → Tænker (tilfældig tid) → Sandt/Falsk + lyd.
/// Hemmelig: sort skærm/billede → tryk → scanning → vibration (1 = Falsk, 2 = Sandt).
@MainActor
final class Engine: ObservableObject {
    @Published private(set) var screen: Screen = .start
    @Published private(set) var armed: Verdict?
    @Published private(set) var log: [LogEntry] = []
    @Published var panelOpen = false { didSet { if panelOpen { detector.resetLive(); liveMax = 0 } } }
    @Published private(set) var hiddenBusy = false   // scanner eller vibrerer i hemmelig tilstand

    // Live-visning i panelet
    @Published private(set) var liveAnomaly: Double?
    @Published private(set) var liveMax: Double = 0
    @Published private(set) var sensorLive = false

    // Lær min mønt
    @Published private(set) var learnStep: LearnStep = .idle
    @Published private(set) var learnRunning = false
    @Published private(set) var learnNoise: Double?
    @Published private(set) var learnCoin: Double?
    @Published private(set) var learnMessage: String?

    let settings: AppSettings
    let sensor = MagnetSensor()
    let detector = Detector()
    let volume = VolumeButtons()
    let sounds = Sounds()
    let haptics = Haptics()

    private var bag = Set<AnyCancellable>()
    private var token = 0
    private var buzzToken = 0
    private var lastPublish = Date.distantPast

    init(settings: AppSettings) {
        self.settings = settings
        detector.threshold = settings.threshold
        detector.consecutive = settings.consecutive
        detector.tracker.mode = settings.sensorMode

        sensor.onSample = { [weak self] s in self?.sample(s) }
        settings.$threshold.sink { [weak self] in self?.detector.threshold = $0 }.store(in: &bag)
        settings.$consecutive.sink { [weak self] in self?.detector.consecutive = $0 }.store(in: &bag)
        settings.$sensorMode.sink { [weak self] in self?.detector.tracker.mode = $0; self?.detector.resetLive() }.store(in: &bag)
        settings.$mode.dropFirst().sink { [weak self] _ in self?.resetToStart() }.store(in: &bag)

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
        sensor.start()
        volume.activate()
        UIApplication.shared.isIdleTimerDisabled = true
    }

    // MARK: Sensor
    private func sample(_ s: MagSample) {
        detector.push(s)
        if panelOpen, let a = detector.liveAnomaly {
            liveMax = max(liveMax, a)
            let now = Date()
            if now.timeIntervalSince(lastPublish) > 0.08 { lastPublish = now; liveAnomaly = a }
        }
    }

    func resetLive() { detector.resetLive(); liveMax = 0; liveAnomaly = 0 }

    private var thinkDuration: Double {
        let lo = settings.thinkMin, hi = max(settings.thinkMin, settings.thinkMax)
        return Double.random(in: lo...hi)
    }

    // MARK: Normal tilstand
    func tapStart() {
        guard screen == .start, !panelOpen else { return }
        token += 1
        let my = token
        detector.beginScan()
        screen = .thinking
        DispatchQueue.main.asyncAfter(deadline: .now() + thinkDuration) { [weak self] in
            guard let self, self.token == my, self.screen == .thinking else { return }
            let v = self.decide()
            self.screen = .result(v)
            if self.settings.sound { self.sounds.play(v) }
        }
    }

    func tapResult() {
        guard case .result = screen else { return }
        screen = .start
    }

    // MARK: Hemmelig vibrationstilstand
    func tapHidden() {
        guard !panelOpen else { return }
        if hiddenBusy { stopBuzz(); return }
        token += 1
        let my = token
        hiddenBusy = true
        detector.beginScan()
        DispatchQueue.main.asyncAfter(deadline: .now() + thinkDuration) { [weak self] in
            guard let self, self.token == my, self.hiddenBusy else { return }
            let v = self.decide()
            self.buzz(v, round: 0)
        }
    }

    private func buzz(_ v: Verdict, round: Int) {
        buzzToken += 1
        let my = buzzToken
        let length = haptics.pulses(v == .sandt ? 2 : 1)
        let maxRounds = settings.vibRepeat == .five ? 5 : Int.max
        guard round + 1 < maxRounds else {
            DispatchQueue.main.asyncAfter(deadline: .now() + length) { [weak self] in
                if self?.buzzToken == my { self?.hiddenBusy = false }
            }
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + length + 1.0) { [weak self] in
            guard let self, self.buzzToken == my, self.hiddenBusy else { return }
            self.buzz(v, round: round + 1)
        }
    }

    func stopBuzz() {
        buzzToken += 1
        token += 1
        detector.cancelScan()
        hiddenBusy = false
    }

    // MARK: Afgørelse
    private func decide() -> Verdict {
        let r = detector.endScan()
        let verdict: Verdict
        let source: String
        if let a = armed {
            verdict = a
            source = settings.tr("volumenknap", "volume button")
        } else if settings.autoSensor, let magnet = r.magnet {
            verdict = magnet ? settings.magnetMeans : settings.magnetMeans.opposite
            source = "sensor"
        } else {
            verdict = settings.fallback
            source = settings.tr("standard", "default")
        }
        let sensorText: String
        if let magnet = r.magnet {
            sensorText = String(format: "%@ · %.0f/%.0f µT", magnet ? "magnet" : settings.tr("ingen magnet", "no magnet"), r.peak, settings.threshold)
        } else {
            sensorText = settings.tr("ingen data", "no data")
        }
        addLog("\(settings.word(verdict)) ← \(source) | \(sensorText)")
        armed = nil
        return verdict
    }

    private func volumePressed(_ v: Verdict) {
        guard settings.volumeButtons, !panelOpen else { return }
        armed = v
        if settings.haptic { haptics.tick() }
    }

    // MARK: Lær min mønt
    func learn(_ step: LearnStep) {
        guard step == .noise || step == .coin, !learnRunning else { return }
        learnStep = step
        learnMessage = nil
        learnRunning = true
        detector.cancelScan()
        // Kort pause, så grundmålingen tages med telefonen i ro, derefter 3 s måling.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            guard self.detector.beginScan() else {
                self.learnRunning = false
                self.learnMessage = self.settings.tr("Ingen sensordata.", "No sensor data.")
                return
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self else { return }
                let r = self.detector.endScan()
                self.learnRunning = false
                if step == .noise { self.learnNoise = r.peak } else { self.learnCoin = r.peak }
                self.finishLearnIfReady()
            }
        }
    }

    private func finishLearnIfReady() {
        guard let n = learnNoise, let c = learnCoin else { return }
        if let t = Detector.learnedThreshold(noise: n, coin: c) {
            settings.threshold = min(300, max(5, t))
            learnStep = .done
            learnMessage = settings.tr("Tærskel sat til \(Int(settings.threshold)) µT.", "Threshold set to \(Int(settings.threshold)) µT.")
            addLog(settings.tr("Lært: uden mønt \(Int(n)) µT, med mønt \(Int(c)) µT → \(Int(settings.threshold)) µT",
                               "Learned: no coin \(Int(n)) µT, coin \(Int(c)) µT → \(Int(settings.threshold)) µT"))
        } else {
            learnStep = .done
            learnMessage = settings.tr("Mønten gav for lille udslag (\(Int(c)) µT mod \(Int(n)) µT). Hold toppen af telefonen tættere på mønten og prøv igen.",
                                       "The coin gave too small a signal (\(Int(c)) µT vs \(Int(n)) µT). Hold the top of the phone closer and try again.")
        }
    }

    func resetLearn() { learnStep = .idle; learnNoise = nil; learnCoin = nil; learnMessage = nil }

    // MARK: Panik / nulstil
    func panic() {
        resetToStart()
        settings.volumeButtons = false
        settings.autoSensor = true
        addLog(settings.tr("PANIK – volumenknapper slået fra", "PANIC – volume buttons off"))
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    func resetToStart() {
        token += 1
        buzzToken += 1
        detector.cancelScan()
        armed = nil
        hiddenBusy = false
        screen = .start
    }

    private func addLog(_ s: String) {
        log.insert(LogEntry(time: Date(), text: s), at: 0)
        if log.count > 12 { log.removeLast(log.count - 12) }
    }
}
