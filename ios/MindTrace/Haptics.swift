import CoreHaptics
import AudioToolbox
import UIKit

/// Vibrationer. Falsk = 1 bump, Sandt = 2 bump.
@MainActor
final class Haptics {
    private var engine: CHHapticEngine?
    private let light = UIImpactFeedbackGenerator(style: .medium)

    init() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let e = try CHHapticEngine()
            e.isAutoShutdownEnabled = true
            e.resetHandler = { [weak e] in try? e?.start() }
            try e.start()
            engine = e
        } catch { engine = nil }
    }

    func tick() { light.impactOccurred() }

    /// Én lang vibration (ingen sensordata).
    @discardableResult
    func long() -> Double {
        if let engine {
            do {
                try engine.start()
                let e = CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.3),
                ], relativeTime: 0, duration: 0.8)
                try engine.makePlayer(with: CHHapticPattern(events: [e], parameters: [])).start(atTime: 0)
                return 0.8
            } catch { }
        }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        return 0.5
    }

    /// `count` kraftige bump. Returnerer hvor lang tid mønstret varer (s).
    @discardableResult
    func pulses(_ count: Int) -> Double {
        let len = 0.22, gap = 0.18
        if let engine {
            var events: [CHHapticEvent] = []
            for i in 0..<count {
                events.append(CHHapticEvent(eventType: .hapticContinuous, parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.6),
                ], relativeTime: Double(i) * (len + gap), duration: len))
            }
            do {
                try engine.start()
                let player = try engine.makePlayer(with: CHHapticPattern(events: events, parameters: []))
                try player.start(atTime: 0)
                return Double(count) * (len + gap)
            } catch { /* fald tilbage herunder */ }
        }
        for i in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.55) {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            }
        }
        return Double(count) * 0.55
    }
}
