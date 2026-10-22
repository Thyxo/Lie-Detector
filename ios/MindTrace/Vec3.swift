import Foundation

/// Lille 3D-vektor (µT). Ren Swift, så den kan testes uden iPhone.
struct Vec3: Equatable {
    var x: Double, y: Double, z: Double

    static let zero = Vec3(x: 0, y: 0, z: 0)

    static func + (a: Vec3, b: Vec3) -> Vec3 { Vec3(x: a.x + b.x, y: a.y + b.y, z: a.z + b.z) }
    static func - (a: Vec3, b: Vec3) -> Vec3 { Vec3(x: a.x - b.x, y: a.y - b.y, z: a.z - b.z) }
    static func * (a: Vec3, k: Double) -> Vec3 { Vec3(x: a.x * k, y: a.y * k, z: a.z * k) }

    var length: Double { (x * x + y * y + z * z).squareRoot() }
    var isFinite: Bool { x.isFinite && y.isFinite && z.isFinite }

    static func mean(_ a: ArraySlice<Vec3>) -> Vec3? {
        guard !a.isEmpty else { return nil }
        return a.reduce(Vec3.zero, +) * (1.0 / Double(a.count))
    }
}

/// 3x3-matrix, række for række (m11 m12 m13 / m21 ...).
struct Mat3: Equatable {
    var m: [Double]

    init(_ m: [Double]) { precondition(m.count == 9); self.m = m }

    static let identity = Mat3([1, 0, 0, 0, 1, 0, 0, 0, 1])

    func mul(_ v: Vec3) -> Vec3 {
        Vec3(x: m[0] * v.x + m[1] * v.y + m[2] * v.z,
             y: m[3] * v.x + m[4] * v.y + m[5] * v.z,
             z: m[6] * v.x + m[7] * v.y + m[8] * v.z)
    }

    var transposed: Mat3 { Mat3([m[0], m[3], m[6], m[1], m[4], m[7], m[2], m[5], m[8]]) }

    static func * (a: Mat3, b: Mat3) -> Mat3 {
        var r = [Double](repeating: 0, count: 9)
        for i in 0..<3 { for j in 0..<3 { for k in 0..<3 { r[i * 3 + j] += a.m[i * 3 + k] * b.m[k * 3 + j] } } }
        return Mat3(r)
    }

    static func rotX(_ a: Double) -> Mat3 { Mat3([1, 0, 0, 0, cos(a), -sin(a), 0, sin(a), cos(a)]) }
    static func rotY(_ a: Double) -> Mat3 { Mat3([cos(a), 0, sin(a), 0, 1, 0, -sin(a), 0, cos(a)]) }
    static func rotZ(_ a: Double) -> Mat3 { Mat3([cos(a), -sin(a), 0, sin(a), cos(a), 0, 0, 0, 1]) }
}
