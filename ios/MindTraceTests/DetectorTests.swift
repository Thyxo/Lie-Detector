import XCTest

final class DetectorTests: XCTestCase {
    let earth = Vec3(x: 18, y: 2, z: -42)   // ca. dansk jordfelt i µT
    let bias = Vec3(x: 120, y: -310, z: 75) // telefonens egen magnetisme

    /// Laver en måling, som CoreMotion ville levere den. `rowConvention`: world = R·v (ellers world = Rᵀ·v).
    func sample(_ r: Mat3, magnet: Vec3 = .zero, rowConvention: Bool = false, calOK: Bool = true) -> MagSample {
        let toDevice = rowConvention ? r.transposed : r
        let devField = toDevice.mul(earth + magnet)
        let g = toDevice.mul(Vec3(x: 0, y: 0, z: -1))
        return MagSample(raw: devField + bias, cal: calOK ? devField : nil, rot: r, gravity: g)
    }

    func rotation(_ i: Int) -> Mat3 {
        let a = Double(i) * 0.02
        return Mat3.rotZ(a * 3) * Mat3.rotX(0.6 + a) * Mat3.rotY(-0.3 + a * 0.5)
    }

    func testWorldFieldIsRotationInvariantBothConventions() {
        for conv in [false, true] {
            let t = FieldTracker()
            for i in 0..<50 {
                let w = t.field(sample(rotation(i), rowConvention: conv))!
                XCTAssertLessThan((w - earth).length, 0.001, "konvention \(conv)")
            }
        }
    }

    func testNoMagnetWhileTurningPhone() {
        let d = Detector()
        for i in 0..<40 { d.push(sample(rotation(0))) }
        XCTAssertTrue(d.beginScan())
        for i in 0..<200 { d.push(sample(rotation(i))) }   // telefonen drejes kraftigt
        let r = d.endScan()
        XCTAssertEqual(r.magnet, false)
        XCTAssertLessThan(r.peak, 1)
    }

    func testMagnetDetectedEvenIfCalibrationAdapts() {
        let d = Detector()
        for _ in 0..<40 { d.push(sample(rotation(0))) }
        d.beginScan()
        for i in 0..<200 {
            let near = (80..<120).contains(i)
            var s = sample(rotation(i % 30), magnet: near ? Vec3(x: 150, y: -60, z: 90) : .zero)
            if near { s.cal = Vec3.zero }   // iOS-kalibreringen "spiser" magneten – må ikke påvirke
            d.push(s)
        }
        let r = d.endScan()
        XCTAssertEqual(r.magnet, true)
        XCTAssertGreaterThan(r.peak, 100)
    }

    func testSingleSpikeIsIgnored() {
        let d = Detector()
        d.consecutive = 3
        for _ in 0..<40 { d.push(sample(.identity)) }
        d.beginScan()
        for i in 0..<100 { d.push(sample(.identity, magnet: i == 50 ? Vec3(x: 500, y: 0, z: 0) : .zero)) }
        XCTAssertEqual(d.endScan().magnet, false)
    }

    func testThresholdIsRespected() {
        let d = Detector()
        d.threshold = 40
        for _ in 0..<40 { d.push(sample(.identity)) }
        d.beginScan()
        for _ in 0..<100 { d.push(sample(.identity, magnet: Vec3(x: 25, y: 0, z: 0))) }
        XCTAssertEqual(d.endScan().magnet, false)   // 25 µT < 40 µT
        for _ in 0..<40 { d.push(sample(.identity)) }
        d.threshold = 20
        d.beginScan()
        for _ in 0..<100 { d.push(sample(.identity, magnet: Vec3(x: 25, y: 0, z: 0))) }
        XCTAssertEqual(d.endScan().magnet, true)
    }

    func testTooFewSamplesGivesNoVerdict() {
        let d = Detector()
        XCTAssertFalse(d.beginScan())
        XCTAssertNil(d.endScan().magnet)
    }

    func testWorksWithoutCalibration() {
        let d = Detector()
        for _ in 0..<40 { d.push(sample(.identity, calOK: false)) }
        d.beginScan()
        for _ in 0..<50 { d.push(sample(.identity, magnet: Vec3(x: 0, y: 90, z: 0), calOK: false)) }
        XCTAssertEqual(d.endScan().magnet, true)
    }

    func testLearnedThreshold() {
        XCTAssertEqual(Detector.learnedThreshold(noise: 10, coin: 210), 80)
        XCTAssertNil(Detector.learnedThreshold(noise: 20, coin: 30))
    }
}

final class ScanStatusTests: XCTestCase {
    func testStatusLatchesOnceCoinFound() {
        let d = Detector()
        d.threshold = 40
        let e = Vec3(x: 18, y: 2, z: -42)
        func s(_ m: Vec3 = .zero) -> MagSample { MagSample(raw: e + m, cal: e + m, rot: .identity, gravity: Vec3(x: 0, y: 0, z: -1)) }
        for _ in 0..<40 { d.push(s()) }
        d.beginScan()
        XCTAssertNil(d.scanStatus)                       // for få målinger
        for _ in 0..<20 { d.push(s()) }
        XCTAssertEqual(d.scanStatus, false)              // ingen mønt endnu
        for _ in 0..<10 { d.push(s(Vec3(x: 0, y: 0, z: 200))) }
        XCTAssertEqual(d.scanStatus, true)               // mønt fundet
        for _ in 0..<50 { d.push(s()) }
        XCTAssertEqual(d.scanStatus, true)               // forbliver fundet
    }
}

final class NewGuessTests: XCTestCase {
    func testNewGuessStartsFresh() {
        let d = Detector()
        d.threshold = 40
        let e = Vec3(x: 18, y: 2, z: -42)
        func s(_ m: Vec3 = .zero) -> MagSample { MagSample(raw: e + m, cal: e + m, rot: .identity, gravity: Vec3(x: 0, y: 0, z: -1)) }
        // Gæt 1: mønt findes
        for _ in 0..<40 { d.push(s()) }
        d.beginScan()
        for _ in 0..<30 { d.push(s(Vec3(x: 0, y: 0, z: 200))) }
        XCTAssertEqual(d.scanStatus, true)
        // Nyt gæt: nulstil, frisk grundmåling – ingen gammel "mønt" hænger ved
        d.resetForNewGuess()
        XCTAssertNil(d.scanStatus)
        XCTAssertFalse(d.beginScan())                    // ingen gamle målinger at bygge på
        for _ in 0..<30 { d.push(s()) }
        XCTAssertTrue(d.beginScan())
        for _ in 0..<30 { d.push(s()) }
        XCTAssertEqual(d.scanStatus, false)
        XCTAssertLessThan(d.scanPeak, 1)
    }
}
