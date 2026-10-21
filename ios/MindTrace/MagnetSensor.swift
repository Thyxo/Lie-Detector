import Foundation
import CoreMotion

/// Læser ægte magnetfelt (µT) via Core Motion. Opfinder aldrig værdier.
final class MagnetSensor {
    private let mm = CMMotionManager()
    private(set) var running = false
    private(set) var activeSource: String = "—"
    private(set) var accuracy: String = "—"
    private(set) var lastSampleAt: Date?

    /// Kaldes på main-tråden med |B| i µT.
    var onSample: ((Double) -> Void)?

    var hardwareAvailable: Bool { mm.isMagnetometerAvailable || mm.isDeviceMotionAvailable }

    func start(source: SensorSource) {
        stop()
        if source == .calibrated, mm.isDeviceMotionAvailable {
            let frames = CMMotionManager.availableAttitudeReferenceFrames()
            let frame: CMAttitudeReferenceFrame = frames.contains(.xMagneticNorthZVertical) ? .xMagneticNorthZVertical : .xArbitraryCorrectedZVertical
            mm.deviceMotionUpdateInterval = 1.0 / 50.0
            mm.startDeviceMotionUpdates(using: frame, to: .main) { [weak self] dm, _ in
                guard let self, let dm else { return }
                let f = dm.magneticField
                self.accuracy = Self.label(f.accuracy)
                self.ingest(f.field.x, f.field.y, f.field.z)
            }
            activeSource = "Kalibreret (Device Motion)"
            running = true
        } else if mm.isMagnetometerAvailable {
            mm.magnetometerUpdateInterval = 1.0 / 50.0
            mm.startMagnetometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let data else { return }
                self.accuracy = "rå"
                self.ingest(data.magneticField.x, data.magneticField.y, data.magneticField.z)
            }
            activeSource = "Rå magnetometer"
            running = true
        } else {
            activeSource = "Ingen sensor"
            running = false
        }
    }

    func stop() {
        if mm.isDeviceMotionActive { mm.stopDeviceMotionUpdates() }
        if mm.isMagnetometerActive { mm.stopMagnetometerUpdates() }
        running = false
    }

    /// Data regnes kun som gyldige, hvis de er kommet inden for det seneste sekund.
    var isLive: Bool {
        guard running, let t = lastSampleAt else { return false }
        return Date().timeIntervalSince(t) < 1.0
    }

    private func ingest(_ x: Double, _ y: Double, _ z: Double) {
        guard x.isFinite, y.isFinite, z.isFinite else { return }
        let m = (x * x + y * y + z * z).squareRoot()
        guard m > 0.01 else { return } // nul-felt = ingen gyldig måling endnu
        lastSampleAt = Date()
        onSample?(m)
    }

    private static func label(_ a: CMMagneticFieldCalibrationAccuracy) -> String {
        switch a {
        case .uncalibrated: return "ukalibreret"
        case .low: return "lav"
        case .medium: return "middel"
        case .high: return "høj"
        @unknown default: return "?"
        }
    }
}
