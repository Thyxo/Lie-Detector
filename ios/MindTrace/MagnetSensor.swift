import Foundation
import CoreMotion

/// Læser ægte data via Core Motion: rå magnetometer + orientering + iOS-kalibreret felt.
/// Opfinder aldrig værdier.
final class MagnetSensor {
    private let mm = CMMotionManager()
    private var latestRaw: Vec3?
    private(set) var running = false
    /// -1 = ukalibreret/ukendt, 0 = lav, 1 = middel, 2 = høj
    private(set) var accuracyLevel: Int = -1
    private(set) var lastSampleAt: Date?
    private(set) var rate: Int = 0
    private var rateCount = 0
    private var rateStart = Date()

    var onSample: ((MagSample) -> Void)?

    /// Kun til automatiske UI-tests (startargument -fakeSensor): 100 kunstige målinger i sekundet.
    private let fake = ProcessInfo.processInfo.arguments.contains("-fakeSensor")
    private var fakeTimer: Timer?

    var hardwareAvailable: Bool { fake || mm.isMagnetometerAvailable || mm.isDeviceMotionAvailable }

    var isLive: Bool {
        guard running, let t = lastSampleAt else { return false }
        return Date().timeIntervalSince(t) < 1.0
    }

    func start() {
        guard !running else { return }
        if fake {
            var t = 0.0
            fakeTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
                t += 0.01
                let n = Vec3(x: sin(t * 7) * 0.5, y: cos(t * 5) * 0.5, z: sin(t * 3) * 0.5)
                let e = Vec3(x: 18, y: 2, z: -42) + n
                self?.emit(MagSample(raw: e, cal: e, rot: .identity, gravity: Vec3(x: 0, y: 0, z: -1)))
            }
            running = true
            return
        }
        let hz = 1.0 / 100.0
        if mm.isMagnetometerAvailable {
            mm.magnetometerUpdateInterval = hz
            mm.startMagnetometerUpdates(to: .main) { [weak self] data, _ in
                guard let self, let f = data?.magneticField else { return }
                let v = Vec3(x: f.x, y: f.y, z: f.z)
                if v.isFinite { self.latestRaw = v }
                // Uden device motion leveres rå data direkte.
                if !self.mm.isDeviceMotionActive { self.emit(MagSample(raw: self.latestRaw, cal: nil, rot: nil, gravity: nil)) }
            }
        }
        if mm.isDeviceMotionAvailable {
            mm.deviceMotionUpdateInterval = hz
            let frames = CMMotionManager.availableAttitudeReferenceFrames()
            let frame: CMAttitudeReferenceFrame = frames.contains(.xArbitraryCorrectedZVertical) ? .xArbitraryCorrectedZVertical : .xArbitraryZVertical
            mm.startDeviceMotionUpdates(using: frame, to: .main) { [weak self] dm, _ in
                guard let self, let dm else { return }
                let r = dm.attitude.rotationMatrix
                let rot = Mat3([r.m11, r.m12, r.m13, r.m21, r.m22, r.m23, r.m31, r.m32, r.m33])
                let g = Vec3(x: dm.gravity.x, y: dm.gravity.y, z: dm.gravity.z)
                let mf = dm.magneticField
                var cal: Vec3? = Vec3(x: mf.field.x, y: mf.field.y, z: mf.field.z)
                if mf.accuracy == .uncalibrated || (cal?.length ?? 0) < 1 || !(cal?.isFinite ?? false) { cal = nil }
                self.accuracyLevel = Self.level(mf.accuracy)
                if self.latestRaw == nil && cal == nil { return }
                self.emit(MagSample(raw: self.latestRaw, cal: cal, rot: rot, gravity: g))
            }
        }
        running = mm.isMagnetometerActive || mm.isDeviceMotionActive
    }

    func stop() {
        if mm.isDeviceMotionActive { mm.stopDeviceMotionUpdates() }
        if mm.isMagnetometerActive { mm.stopMagnetometerUpdates() }
        running = false
    }

    private func emit(_ s: MagSample) {
        let now = Date()
        lastSampleAt = now
        rateCount += 1
        if now.timeIntervalSince(rateStart) >= 1 { rate = rateCount; rateCount = 0; rateStart = now }
        onSample?(s)
    }

    private static func level(_ a: CMMagneticFieldCalibrationAccuracy) -> Int {
        switch a {
        case .uncalibrated: return -1
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        @unknown default: return -1
        }
    }
}
