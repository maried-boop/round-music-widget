import Foundation
import simd

struct OrbSettings: Codable {
    let version: Int
    let body: Float
    let light: Float
    let rim: Float
    let glow: Float
    let width: Float
    let motion: Float
    let duration: Float
    let size: Float
    let color1: String
    let color2: String
    let color3: String
    let follow: Float
    let spin: Float
    let inside: String
    let detail: Float
    let lensEnabled: Bool
    let orbEnabled: Bool
    let artworkColors: Bool
    let lensStrength: Float
    let lensWidth: Float
    let lensMotion: Float
    let lensCenter: Float
    let lensWidthMotion: Float
    let lensTravel: Float
    let lensCycles: Float

    static func decode(_ data: Data) throws -> OrbSettings {
        let settings = try JSONDecoder().decode(Self.self, from: data)
        let ranges: [(Float, ClosedRange<Float>)] = [
            (settings.body, 0...1), (settings.light, 0...1),
            (settings.rim, 0...1), (settings.glow, 0...1),
            (settings.width, 0.1...0.8), (settings.motion, 0...1),
            (settings.duration, 4...120), (settings.size, 0.4...0.9),
            (settings.follow, 0...1), (settings.spin, -4...4),
            (settings.detail, 0...1), (settings.lensStrength, 1...2.5),
            (settings.lensWidth, 0.08...0.4), (settings.lensMotion, 0...1),
            (settings.lensCenter, 0.3...0.9), (settings.lensWidthMotion, 0...1),
            (settings.lensTravel, 0...1), (settings.lensCycles, 1...4)
        ]
        guard settings.version == 4,
              settings.lensCycles.rounded() == settings.lensCycles,
              settings.spin.rounded() == settings.spin,
              ranges.allSatisfy({ $0.0.isFinite && $0.1.contains($0.0) }),
              [settings.color1, settings.color2, settings.color3].allSatisfy({
                  $0.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil
              }),
              ["orb", "aurora", "chrome", "plasma", "silk", "clear"].contains(settings.inside)
        else { throw CocoaError(.coderReadCorrupt) }
        return settings
    }

    static func bundled() throws -> OrbSettings {
        guard let url = Bundle.module.url(forResource: "orb-settings", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(Data(contentsOf: url))
    }

    static func rgb(_ hex: String) -> SIMD3<Float> {
        let value = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return SIMD3(Float((value >> 16) & 255), Float((value >> 8) & 255), Float(value & 255)) / 255
    }
}
