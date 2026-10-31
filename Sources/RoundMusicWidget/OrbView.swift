import AppKit
import MetalKit
import QuartzCore

// Float4 groups keep the Swift and generated Metal layouts identical.
struct OrbUniforms {
    var viewport: SIMD4<Float>
    var glass: SIMD4<Float>
    var movement: SIMD4<Float>
    var material: SIMD4<Float>
    var lens: SIMD4<Float>
    var lensMotion: SIMD4<Float>
    var cycles: SIMD4<Float>
    var color1: SIMD4<Float>
    var color2: SIMD4<Float>
    var color3: SIMD4<Float>

    init(settings s: OrbSettings, size: CGSize, phase: Float, pointer: SIMD2<Float>,
         palette: [SIMD3<Float>] = ArtworkPalette.neutral) {
        let normalizedPhase = phase.truncatingRemainder(dividingBy: 2 * .pi)
        viewport = SIMD4(Float(size.width), Float(size.height), normalizedPhase, s.size)
        glass = SIMD4(s.body, s.light, s.rim, s.glow)
        movement = SIMD4(s.width, s.motion, s.follow, s.spin)
        material = SIMD4(pointer.x, pointer.y, Float(
            ["orb", "aurora", "chrome", "plasma", "silk", "clear"].firstIndex(of: s.inside) ?? 0
        ), s.detail)
        lens = SIMD4(s.lensEnabled ? 1 : 0, s.orbEnabled ? 1 : 0, s.lensStrength, s.lensWidth)
        lensMotion = SIMD4(s.lensMotion, s.lensCenter, s.lensWidthMotion, s.lensTravel)
        cycles = SIMD4(s.lensCycles, 0, 0, 0)
        let colors = s.artworkColors ? palette : [OrbSettings.rgb(s.color1), OrbSettings.rgb(s.color2), OrbSettings.rgb(s.color3)]
        color1 = SIMD4(colors[0], 0)
        color2 = SIMD4(colors[1], 0)
        color3 = SIMD4(colors[2], 0)
    }
}

final class OrbRenderer {
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    let lensMap: MTLTexture

    init(device: MTLDevice) throws {
        guard let queue = device.makeCommandQueue(),
              let shaderURL = Bundle.module.url(forResource: "orb-shader", withExtension: "txt"),
              let mapURL = Bundle.module.url(forResource: "lens-map", withExtension: "rgba") else {
            throw CocoaError(.fileNoSuchFile)
        }
        self.queue = queue
        let library = try device.makeLibrary(source: String(contentsOf: shaderURL, encoding: .utf8), options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: "orbVertex")
        descriptor.fragmentFunction = library.makeFunction(name: "orbFragment")
        let attachment = descriptor.colorAttachments[0]!
        attachment.pixelFormat = .bgra8Unorm
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .one
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.sourceAlphaBlendFactor = .one
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        let data = try Data(contentsOf: mapURL)
        guard data.count == 512 * 151 * 4 else { throw CocoaError(.fileReadCorruptFile) }
        let mapDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: 512, height: 151, mipmapped: false
        )
        mapDescriptor.storageMode = .shared
        mapDescriptor.usage = .shaderRead
        guard let lensMap = device.makeTexture(descriptor: mapDescriptor) else { throw CocoaError(.featureUnsupported) }
        self.lensMap = lensMap
        data.withUnsafeBytes {
            lensMap.replace(region: MTLRegionMake2D(0, 0, 512, 151), mipmapLevel: 0,
                            withBytes: $0.baseAddress!, bytesPerRow: 512 * 4)
        }
    }

    func encode(_ encoder: MTLRenderCommandEncoder, uniforms: OrbUniforms, artwork: MTLTexture) {
        var uniforms = uniforms
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<OrbUniforms>.stride, index: 0)
        encoder.setFragmentTexture(artwork, index: 0)
        encoder.setFragmentTexture(lensMap, index: 1)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
    }
}

final class OrbView: MTKView, MTKViewDelegate {
    override var isOpaque: Bool { false }
    let settings: OrbSettings
    private let renderer: OrbRenderer
    private var artwork: MTLTexture?
    private var palette = ArtworkPalette.neutral
    var hasArtwork: Bool { artwork != nil }
    private var phase: Float = 0
    private var lastFrameTime: CFTimeInterval?
    private var pointer = SIMD2<Float>.zero
    private var targetPointer = SIMD2<Float>.zero
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    var isPlaying = false { didSet { updateAnimation() } }
    var animationEnabled = true { didSet { updateAnimation() } }

    init?(settings: OrbSettings) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let renderer = try? OrbRenderer(device: device) else { return nil }
        self.settings = settings
        self.renderer = renderer
        super.init(frame: .zero, device: device)
        colorPixelFormat = .bgra8Unorm
        clearColor = MTLClearColorMake(0, 0, 0, 0)
        wantsLayer = true
        layer?.isOpaque = false
        preferredFramesPerSecond = 30
        enableSetNeedsDisplay = true
        isPaused = true
        delegate = self
        observe(NSWorkspace.shared.notificationCenter, NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
        observe(NotificationCenter.default, NSWindow.didChangeOcclusionStateNotification)
        observe(NotificationCenter.default, NSApplication.didChangeScreenParametersNotification)
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { observers.forEach { $0.0.removeObserver($0.1) } }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAnimation()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        needsDisplay = true
    }

    func setArtwork(_ image: NSImage?) {
        // Normalize vector symbols and unusual artwork colour spaces into RGBA
        // before uploading. Metal's image loader cannot use every NSImage format.
        guard let device, let image, image.size.width > 0, image.size.height > 0 else {
            artwork = nil
            isHidden = true
            updateAnimation()
            return
        }
        let side = min(image.size.width, image.size.height)
        let dimension = max(1, Int(min(1024, max(512, side))))
        guard let bitmap = Self.rasterize(image, dimension: dimension),
              let sample = Self.rasterize(image, dimension: 48) else { return }
        if let pixels = sample.bitmapData {
            var straight = Array(UnsafeBufferPointer(start: pixels, count: 48 * 48 * 4))
            // NSGraphicsContext uses premultiplied pixels; palette sampling uses straight RGB.
            for i in stride(from: 0, to: straight.count, by: 4) {
                let alpha = Float(straight[i + 3]) / 255
                if alpha > 0 { for c in 0..<3 {
                    straight[i + c] = UInt8(min(255, (Float(straight[i + c]) / alpha).rounded()))
                } }
            }
            palette = ArtworkPalette.colors(pixels: straight)
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm, width: dimension, height: dimension, mipmapped: false
        )
        descriptor.storageMode = .shared
        descriptor.usage = .shaderRead
        artwork = device.makeTexture(descriptor: descriptor)
        if let pixels = bitmap.bitmapData {
            artwork?.replace(region: MTLRegionMake2D(0, 0, dimension, dimension), mipmapLevel: 0,
                             withBytes: pixels, bytesPerRow: bitmap.bytesPerRow)
        }
        isHidden = artwork == nil
        updateAnimation()
    }

    static func rasterize(_ image: NSImage, dimension: Int) -> NSBitmapImageRep? {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: dimension, pixelsHigh: dimension,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: dimension * 4, bitsPerPixel: 32
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        let side = min(image.size.width, image.size.height)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: dimension, height: dimension),
                   from: NSRect(x: (image.size.width - side) / 2, y: (image.size.height - side) / 2,
                                width: side, height: side), operation: .copy, fraction: 1)
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            self?.updateAnimation()
        }
        observers.append((center, token))
    }

    private func updateAnimation() {
        let visible = window?.occlusionState.contains(.visible) == true
        isPaused = !(isPlaying && animationEnabled && visible && !isHidden
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion)
        // Keep the current phase through pause/resume and hidden windows.
        lastFrameTime = nil
        needsDisplay = true
    }

    func follow(_ point: NSPoint?) {
        guard isPlaying, animationEnabled,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        if let point, bounds.width > 0, bounds.height > 0 {
            targetPointer = SIMD2(
                Float(max(-1, min(1, point.x / bounds.width * 2 - 1))),
                Float(max(-1, min(1, point.y / bounds.height * 2 - 1)))
            )
        } else { targetPointer = .zero }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    func draw(in view: MTKView) {
        let now = CACurrentMediaTime()
        if !isPaused {
            let delta = min(0.1, max(0, now - (lastFrameTime ?? now)))
            phase = (phase + Float(delta) * 2 * .pi / (settings.duration))
                .truncatingRemainder(dividingBy: 2 * .pi)
            pointer += (targetPointer - pointer) * Float(1 - exp(-delta * 8))
        }
        lastFrameTime = now
        guard let artwork, let drawable = currentDrawable, let pass = currentRenderPassDescriptor,
              let command = renderer.queue.makeCommandBuffer(),
              let encoder = command.makeRenderCommandEncoder(descriptor: pass) else { return }
        renderer.encode(encoder, uniforms: OrbUniforms(
            settings: settings, size: drawableSize, phase: phase, pointer: pointer, palette: palette
        ), artwork: artwork)
        command.present(drawable)
        command.commit()
    }
}
