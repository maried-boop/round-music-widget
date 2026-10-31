import AppKit

// Matches OrbRenderer.paletteFromPixels in the orb tool. Sample only on a track change.
enum ArtworkPalette {
    static let neutral = [SIMD3<Float>(repeating: 170 / 255),
                          SIMD3<Float>(repeating: 85 / 255),
                          SIMD3<Float>(repeating: 238 / 255)]

    static func colors(pixels: [UInt8]) -> [SIMD3<Float>] {
        struct Bucket { var count: Float = 0; var sum = SIMD3<Float>.zero }
        var buckets: [Int: Bucket] = [:]
        var order: [Int] = []
        for i in stride(from: 0, to: pixels.count - 3, by: 4) {
            let alpha = Float(pixels[i + 3]) / 255
            guard alpha >= 0.5 else { continue }
            let r = Int(pixels[i]), g = Int(pixels[i + 1]), b = Int(pixels[i + 2])
            let key = (r >> 5) * 64 + (g >> 5) * 8 + (b >> 5)
            if buckets[key] == nil { order.append(key) }
            var bucket = buckets[key] ?? Bucket()
            bucket.count += alpha
            bucket.sum += SIMD3(Float(r), Float(g), Float(b)) * alpha
            buckets[key] = bucket
        }
        guard !order.isEmpty else { return neutral }
        struct Color { var rgb: SIMD3<Float>; var count: Float; var score: Float }
        let colors: [Color] = order.compactMap { key in
            guard let bucket = buckets[key] else { return nil }
            let rgb = bucket.sum / bucket.count
            let high = max(rgb.x, max(rgb.y, rgb.z)), low = min(rgb.x, min(rgb.y, rgb.z))
            let saturation = high > 0 ? (high - low) / high : 0
            return Color(rgb: rgb, count: bucket.count, score: bucket.count * (0.45 + saturation))
        }
        func best(_ candidates: [Color], score: (Color) -> Float) -> Color {
            candidates.dropFirst().reduce(candidates[0]) { score($1) > score($0) ? $1 : $0 }
        }
        let primary = best(colors) { $0.score }
        let secondary = best(colors) {
            let difference = $0.rgb - primary.rgb
            let distance = sqrt(difference.x * difference.x + difference.y * difference.y + difference.z * difference.z) / 442
            return $0.score * (0.05 + distance)
        }
        let lightest = best(colors.filter { $0.count >= primary.count * 0.03 }) {
            $0.rgb.x + $0.rgb.y + $0.rgb.z
        }
        func quantize(_ color: SIMD3<Float>) -> SIMD3<Float> {
            SIMD3(color.x.rounded(), color.y.rounded(), color.z.rounded()) / 255
        }
        return [quantize(primary.rgb), quantize(secondary.rgb),
                quantize(lightest.rgb + (SIMD3<Float>(repeating: 255) - lightest.rgb) * 0.42)]
    }
}
