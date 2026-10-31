import XCTest
import AppKit
import MetalKit
@testable import RoundMusicWidget

final class DoubleMotionTests: XCTestCase {
    func testSelectedPresetAndPalette() throws {
        let s = try OrbSettings.bundled()
        XCTAssertEqual(s.version, 4)
        XCTAssertEqual(s.duration, 56)
        XCTAssertEqual(s.spin, 4)
        XCTAssertEqual(s.lensCycles, 2)
        XCTAssertEqual(s.lensTravel, 0.155)
        XCTAssertEqual(s.lensStrength, 1.88)
        XCTAssertEqual(s.lensWidth, 0.29)
        XCTAssertEqual(s.lensCenter, 0.74)
        XCTAssertEqual(s.lensMotion, 1)
        XCTAssertEqual(s.lensWidthMotion, 1)
        XCTAssertTrue(s.artworkColors && s.lensEnabled && s.orbEnabled)
        let red = ArtworkPalette.colors(pixels: Array(repeating: [210, 35, 20, 255], count: 100).flatMap { $0 })
        let blue = ArtworkPalette.colors(pixels: Array(repeating: [20, 55, 210, 255], count: 100).flatMap { $0 })
        XCTAssertEqual(red[0], SIMD3<Float>(210, 35, 20) / 255)
        XCTAssertEqual(blue[0], SIMD3<Float>(20, 55, 210) / 255)
        XCTAssertNotEqual(red, blue)
        let gray = ArtworkPalette.colors(pixels: [80, 80, 80, 255, 190, 190, 190, 255])
        for color in gray { XCTAssertEqual(color.x, color.y); XCTAssertEqual(color.y, color.z) }
    }

    func testArtworkUploadAndDetachedPause() throws {
        let view = try XCTUnwrap(OrbView(settings: OrbSettings.bundled()))
        view.setArtwork(try XCTUnwrap(NSImage(systemSymbolName: "music.note", accessibilityDescription: nil)))
        XCTAssertTrue(view.hasArtwork)
        view.isPlaying = true
        XCTAssertTrue(view.isPaused, "Detached views must not animate")
        view.setArtwork(nil)
        XCTAssertFalse(view.hasArtwork)
        XCTAssertTrue(view.isHidden)
    }

    func testArtworkOrientationIsPreserved() throws {
        var pixels = [UInt8](repeating: 255, count: 16 * 16 * 4)
        for y in 0..<16 { for x in 0..<16 {
            let i = (y * 16 + x) * 4
            pixels[i] = y < 8 ? 200 : 10
            pixels[i + 1] = 20
            pixels[i + 2] = y < 8 ? 10 : 200
        } }
        let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
        let cg = try XCTUnwrap(CGImage(width: 16, height: 16, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: 64, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        let image = NSImage(cgImage: cg, size: NSSize(width: 16, height: 16))
        let bitmap = try XCTUnwrap(OrbView.rasterize(image, dimension: 16))
        let result = try XCTUnwrap(bitmap.bitmapData)
        XCTAssertEqual(Array(UnsafeBufferPointer(start: result, count: 4)), [200, 20, 10, 255])
        XCTAssertEqual(Array(UnsafeBufferPointer(start: result + 15 * 64, count: 4)), [10, 20, 200, 255])
    }

    func testBothLayersLoopPointerAndTransparency() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let renderer = try OrbRenderer(device: device)
        let s = try OrbSettings.bundled()
        let input = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: 256, height: 256, mipmapped: false)
        input.usage = .shaderRead; input.storageMode = .shared
        let artwork = try XCTUnwrap(device.makeTexture(descriptor: input))
        var source = [UInt8](repeating: 255, count: 256 * 256 * 4)
        for y in 0..<256 { for x in 0..<256 {
            let i = (y * 256 + x) * 4
            let v: UInt8 = x % 24 < 3 || y % 24 < 3 ? 30 : 180
            source[i] = v; source[i + 1] = v; source[i + 2] = v
        } }
        source.withUnsafeBytes { artwork.replace(region: MTLRegionMake2D(0, 0, 256, 256), mipmapLevel: 0, withBytes: $0.baseAddress!, bytesPerRow: 1024) }
        let palette = ArtworkPalette.colors(pixels: source)
        func render(_ phase: Float, settings: OrbSettings? = nil, pointer: SIMD2<Float> = .zero) throws -> [UInt8] {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: 300, height: 300, mipmapped: false)
            descriptor.usage = .renderTarget; descriptor.storageMode = .shared
            let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = texture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
            let command = try XCTUnwrap(renderer.queue.makeCommandBuffer())
            renderer.encode(try XCTUnwrap(command.makeRenderCommandEncoder(descriptor: pass)), uniforms: OrbUniforms(
                settings: settings ?? s, size: CGSize(width: 300, height: 300), phase: phase, pointer: pointer, palette: palette
            ), artwork: artwork)
            command.commit(); command.waitUntilCompleted()
            XCTAssertNil(command.error)
            var pixels = [UInt8](repeating: 0, count: 300 * 300 * 4)
            pixels.withUnsafeMutableBytes { texture.getBytes($0.baseAddress!, bytesPerRow: 1200, from: MTLRegionMake2D(0, 0, 300, 300), mipmapLevel: 0) }
            return pixels
        }
        let start = try render(0)
        XCTAssertNotEqual(start, try render(0.8))
        XCTAssertNotEqual(start, try render(0, pointer: SIMD2(0.6, -0.4)))
        let loop = try render(2 * .pi)
        XCTAssertLessThanOrEqual(zip(start, loop).map { abs(Int($0) - Int($1)) }.max()!, 3)
        XCTAssertEqual(start[3], 0)
        for i in stride(from: 0, to: start.count, by: 4) {
            XCTAssertEqual(start[i], start[i + 1], "Grayscale artwork must give neutral orb colours")
            XCTAssertEqual(start[i], start[i + 2])
        }
        var values = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as? [String: Any])
        values["orbEnabled"] = false
        let lensOnly = try OrbSettings.decode(JSONSerialization.data(withJSONObject: values))
        let lensStart = try render(0, settings: lensOnly), lensMoved = try render(0.8, settings: lensOnly)
        XCTAssertNotEqual(lensStart, lensMoved)
        XCTAssertNotEqual(start, lensStart)
        for y in 120..<180 { for x in 120..<180 {
            let i = (y * 300 + x) * 4
            XCTAssertEqual(Array(lensStart[i..<i + 4]), Array(lensMoved[i..<i + 4]), "Keep the selected clear centre intact")
        } }
        values["lensEnabled"] = false; values["orbEnabled"] = true
        let orbOnly = try OrbSettings.decode(JSONSerialization.data(withJSONObject: values))
        XCTAssertNotEqual(try render(0, settings: orbOnly), try render(0.8, settings: orbOnly))
    }
}
