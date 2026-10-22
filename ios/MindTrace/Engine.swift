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

/// Rutinen: "Har du mønten i hånden?" – tilskueren svarer ja/nej.
/// Telefonen afgør IKKE selv. Den vibrerer i performerens hånd:
///   2 bump = mønt i hånden, 1 bump = ingen mønt, 1 lang = ingen sensordata
/// gentaget ca. hvert sekund, indtil performeren trykker.
/// Normal tilstand: Start → tryk → Tænker (+ vibration) → volumen op = Sandt / ned = Falsk.
/// Hemmelig tilstand: sort skærm/billede → tryk → vibration → tryk igen stopper.
@MainActor
final class Engine: ObservableObject {
    @Published private(set) var screen: Screen = .start
    @Published private(set) var log: [LogEntry] = []
    @Published var panelOpen = false { didSet { if panelOpen { stopScan(); resetLive() } } }
    @Published private(set) var hiddenBusy = false

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
    private var scanToken = 0
    private var lastPublish = Date.distantPast
    private let maxBuzzRounds = 120   // sikkerhed: stopper efter ca. 2 minutter

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

        volume.onUp = { [weak self] in self?.reveal(.sandt) }
        volume.onDown = { [weak self] in self?.reveal(.falsk) }

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

    // MARK: Normal tilstand
    func tapStart() {
        guard screen == .start, !panelOpen else { return }
        screen = .thinking
        startScan()
    }

    /// Volumenknap: op = Sandt, ned = Falsk. Virker på Tænker- og resultatskærmen (kan rettes).
    private func reveal(_ v: Verdict) {
        guard !panelOpen, settings.mode == .normal else { return }
        switch screen {
        case .start:
            return
        case .thinking:
            let peak = detector.scanPeak
            let status = detector.scanStatus
            stopScan()
            addLog(logText(v, status: status, peak: peak))
        case .result(let old):
            if old == v { return }
            addLog(settings.tr("Rettet til \(settings.word(v))", "Changed to \(settings.word(v))"))
        }
        screen = .result(v)
        if settings.sound { sounds.play(v) }
    }

    func tapResult() {
        guard case .result = screen else { return }
        screen = .start
    }

    // MARK: Hemmelig tilstand
    func tapHidden() {
        guard !panelOpen else { return }
        if hiddenBusy {
            let peak = detector.scanPeak
            let status = detector.scanStatus
            stopScan()
            addLog(logText(nil, status: status, peak: peak))
            return
        }
        hiddenBusy = true
        startScan()
    }

    // MARK: Scanning + vibration
    private func startScan() {
        scanToken += 1
        let my = scanToken
        detector.beginScan()
        DispatchQueue.main.asyncAfter(deadline: .now() + settings.vibDelay) { [weak self] in
            self?.buzzRound(my, round: 0)
        }
    }

    private func buzzRound(_ my: Int, round: Int) {
        guard my == scanToken, round < maxBuzzRounds else { return }
        let length: Double
        if !sensor.isLive && detector.scanStatus == nil {
            length = haptics.long()                       // ingen sensordata
        } else {
            let coin = detector.scanStatus ?? false
            length = haptics.pulses(coin ? 2 : 1)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + length + 1.0) { [weak self] in
            self?.buzzRound(my, round: round + 1)
        }
    }

    private func stopScan() {
        scanToken += 1
        if detector.isScanning { _ = detector.endScan() }
        hiddenBusy = false
    }

    private func logText(_ v: Verdict?, status: Bool?, peak: Double) -> String {
        let sensorText: String
        switch status {
        case .some(true): sensorText = String(format: settings.tr("mønt · %.0f/%.0f µT", "coin · %.0f/%.0f µT"), peak, settings.threshold)
        case .some(false): sensorText = String(format: settings.tr("ingen mønt · %.0f/%.0f µT", "no coin · %.0f/%.0f µT"), peak, settings.threshold)
        case .none: sensorText = settings.tr("ingen sensordata", "no sensor data")
        }
        if let v { return "\(settings.word(v)) | \(sensorText)" }
        return settings.tr("Hemmelig: ", "Secret: ") + sensorText
    }

    // MARK: Lær min mønt
    func learn(_ step: LearnStep) {
        guard step == .noise || step == .coin, !learnRunning else { return }
        learnStep = step
        learnMessage = nil
        learnRunning = true
        stopScan()
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
        learnStep = .done
        if let t = Detector.learnedThreshold(noise: n, coin: c) {
            settings.threshold = min(300, max(5, t))
            learnMessage = settings.tr("Tærskel sat til \(Int(settings.threshold)) µT.", "Threshold set to \(Int(settings.threshold)) µT.")
            addLog(settings.tr("Lært: uden mønt \(Int(n)) µT, med mønt \(Int(c)) µT → \(Int(settings.threshold)) µT",
                               "Learned: no coin \(Int(n)) µT, coin \(Int(c)) µT → \(Int(settings.threshold)) µT"))
        } else {
            learnMessage = settings.tr("Mønten gav for lille udslag (\(Int(c)) µT mod \(Int(n)) µT). Hold toppen af telefonen tættere på mønten og prøv igen.",
                                       "The coin gave too small a signal (\(Int(c)) µT vs \(Int(n)) µT). Hold the top of the phone closer and try again.")
        }
    }

    func resetLearn() { learnStep = .idle; learnNoise = nil; learnCoin = nil; learnMessage = nil }

    // MARK: Nulstil
    func resetToStart() {
        stopScan()
        screen = .start
    }

    private func addLog(_ s: String) {
        log.insert(LogEntry(time: Date(), text: s), at: 0)
        if log.count > 12 { log.removeLast(log.count - 12) }
    }
}
