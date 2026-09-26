import AppKit
import CoreImage
import QuartzCore

final class WidgetView: NSView {
    private let controller: MusicController
    private let artworkView = PassthroughImageView()
    private let glassOverlay = GlassOverlayView()
    private let circularTitleView = CircularTitleView()
    private let previousButton: GlassControlButton
    private let playPauseButton: GlassControlButton
    private let nextButton: GlassControlButton
    private var trackingAreaReference: NSTrackingArea?
    private var dragStartScreenPoint: NSPoint?
    private var dragStartWindowOrigin: NSPoint?

    init(frame frameRect: NSRect, controller: MusicController) {
        self.controller = controller
        self.previousButton = GlassControlButton(
            symbol: "backward.fill",
            accessibilityLabel: "Previous track",
            size: 46
        )
        self.playPauseButton = GlassControlButton(
            symbol: "play.fill",
            accessibilityLabel: "Play",
            size: 54
        )
        self.nextButton = GlassControlButton(
            symbol: "forward.fill",
            accessibilityLabel: "Next track",
            size: 46
        )

        super.init(frame: frameRect)
        configureView()
        configureActions()
        configurePlaybackObservation()
        configureArtworkObservation()
        configureTrackInfoObservation()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()

        let diameter = max(1, min(bounds.width, bounds.height) - 8)
        let circleFrame = NSRect(
            x: (bounds.width - diameter) / 2,
            y: (bounds.height - diameter) / 2,
            width: diameter,
            height: diameter
        )

        artworkView.frame = circleFrame
        artworkView.layer?.cornerRadius = circleFrame.width / 2
        glassOverlay.frame = circleFrame
        circularTitleView.frame = circleFrame

        let scale = bounds.width / 300
        previousButton.setDiameter(46 * scale)
        playPauseButton.setDiameter(54 * scale)
        nextButton.setDiameter(46 * scale)

        let controlsY: CGFloat = 32 * scale
        let spacing: CGFloat = 18 * scale
        let totalWidth = previousButton.frame.width
            + playPauseButton.frame.width
            + nextButton.frame.width
            + (spacing * 2)
        var x = (bounds.width - totalWidth) / 2

        previousButton.setFrameOrigin(NSPoint(x: x, y: controlsY))
        x += previousButton.frame.width + spacing
        playPauseButton.setFrameOrigin(NSPoint(x: x, y: controlsY - 4))
        x += playPauseButton.frame.width + spacing
        nextButton.setFrameOrigin(NSPoint(x: x, y: controlsY))
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaReference {
            removeTrackingArea(trackingAreaReference)
        }

        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaReference = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        setControlsOpacity(1)
        setTitleVisible(!circularTitleView.title.isEmpty)
    }

    override func mouseExited(with event: NSEvent) {
        setControlsOpacity(0.74)
        setTitleVisible(false)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        dragStartScreenPoint = NSEvent.mouseLocation
        dragStartWindowOrigin = window?.frame.origin
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window,
              let dragStartScreenPoint,
              let dragStartWindowOrigin else {
            return
        }

        let currentPoint = NSEvent.mouseLocation
        window.setFrameOrigin(
            NSPoint(
                x: dragStartWindowOrigin.x
                    + currentPoint.x - dragStartScreenPoint.x,
                y: dragStartWindowOrigin.y
                    + currentPoint.y - dragStartScreenPoint.y
            )
        )
    }

    override func mouseUp(with event: NSEvent) {
        dragStartScreenPoint = nil
        dragStartWindowOrigin = nil
        NSCursor.openHand.set()
    }

    private func configureView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        artworkView.setArtwork(makeFallbackArtwork())
        artworkView.imageScaling = .scaleProportionallyUpOrDown
        artworkView.wantsLayer = true
        artworkView.layer?.masksToBounds = true
        artworkView.setAccessibilityLabel("Track artwork")
        circularTitleView.alphaValue = 0
        circularTitleView.setAccessibilityLabel("Current song")

        addSubview(artworkView)
        addSubview(glassOverlay)
        addSubview(circularTitleView)
        addSubview(previousButton)
        addSubview(playPauseButton)
        addSubview(nextButton)

        setControlsOpacity(0.74, animated: false)
    }

    private func configureActions() {
        previousButton.onPress = { [weak self] in
            self?.controller.previousTrack()
        }
        playPauseButton.onPress = { [weak self] in
            self?.controller.playPause()
        }
        nextButton.onPress = { [weak self] in
            self?.controller.nextTrack()
        }
    }

    private func configurePlaybackObservation() {
        controller.onPlaybackStateChanged = { [weak self] isPlaying in
            self?.playPauseButton.setSymbol(
                isPlaying ? "pause.fill" : "play.fill",
                accessibilityLabel: isPlaying ? "Pause" : "Play"
            )
        }
    }

    private func configureArtworkObservation() {
        controller.onArtworkChanged = { [weak self] image in
            guard let self else { return }
            let nextImage = image ?? self.makeFallbackArtwork()

            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.20
                self.artworkView.animator().alphaValue = 0
            } completionHandler: { [weak self] in
                self?.artworkView.setArtwork(nextImage)
                NSAnimationContext.runAnimationGroup { context in
                    context.duration = 0.24
                    self?.artworkView.animator().alphaValue = 1
                }
            }
        }
    }

    private func configureTrackInfoObservation() {
        controller.onTrackInfoChanged = { [weak self] title, artist in
            guard let self else { return }
            self.circularTitleView.title = [title, artist]
                .filter { !$0.isEmpty }
                .joined(separator: "   ·   ")

            if title.isEmpty {
                self.setTitleVisible(false)
            }
        }
    }

    private func setTitleVisible(_ isVisible: Bool) {
        circularTitleView.isMarqueeActive = isVisible
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            circularTitleView.animator().alphaValue = isVisible ? 1 : 0
        }
    }

    private func setControlsOpacity(
        _ opacity: Float,
        animated: Bool = true
    ) {
        let changes = {
            self.previousButton.layer?.opacity = opacity
            self.playPauseButton.layer?.opacity = opacity
            self.nextButton.layer?.opacity = opacity
        }

        guard animated else {
            changes()
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            context.timingFunction = CAMediaTimingFunction(
                name: .easeOut
            )
            changes()
        }
    }

    private func makeFallbackArtwork() -> NSImage? {
        NSImage(
            systemSymbolName: "music.note",
            accessibilityDescription: "Music"
        )
    }
}

private final class GlassControlButton: NSView {
    var onPress: (() -> Void)?

    private let button = NSButton()
    private var symbolName = ""
    private var symbolAccessibilityLabel = ""

    init(
        symbol: String,
        accessibilityLabel: String,
        size: CGFloat
    ) {
        super.init(
            frame: NSRect(x: 0, y: 0, width: size, height: size)
        )
        configureView()
        setSymbol(symbol, accessibilityLabel: accessibilityLabel)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        button.frame = bounds
        layer?.cornerRadius = bounds.width / 2
        applySymbol()
    }

    func setDiameter(_ diameter: CGFloat) {
        setFrameSize(NSSize(width: diameter, height: diameter))
        button.frame = bounds
        layer?.cornerRadius = diameter / 2
        applySymbol()
        needsLayout = true
    }

    func setSymbol(
        _ symbol: String,
        accessibilityLabel: String
    ) {
        symbolName = symbol
        symbolAccessibilityLabel = accessibilityLabel
        applySymbol()
    }

    private func configureView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.black
            .withAlphaComponent(0.18)
            .cgColor
        layer?.borderColor = NSColor.white
            .withAlphaComponent(0.16)
            .cgColor
        layer?.borderWidth = 0.7
        layer?.shadowColor = NSColor.black.cgColor
        layer?.shadowOpacity = 0.14
        layer?.shadowRadius = 8
        layer?.shadowOffset = CGSize(width: 0, height: -3)

        button.isBordered = false
        button.imagePosition = .imageOnly
        button.contentTintColor = .white
        button.target = self
        button.action = #selector(pressed)
        addSubview(button)
    }

    @objc private func pressed() {
        onPress?()
    }

    private func applySymbol() {
        let configuration = NSImage.SymbolConfiguration(
            pointSize: max(11, bounds.width * 0.34),
            weight: .semibold
        )
        button.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: symbolAccessibilityLabel
        )?.withSymbolConfiguration(configuration)
        button.setAccessibilityLabel(symbolAccessibilityLabel)
    }
}

private final class PassthroughImageView: NSImageView {
    private static let renderingContext = CIContext()

    func setArtwork(_ sourceImage: NSImage?) {
        guard let sourceImage else {
            image = nil
            return
        }

        image = Self.renderEdgeStretch(sourceImage) ?? sourceImage
    }

    private static func renderEdgeStretch(_ sourceImage: NSImage) -> NSImage? {
        guard let data = sourceImage.tiffRepresentation,
              let input = CIImage(data: data),
              let lens = CIFilter(name: "CITorusLensDistortion"),
              let mask = CIFilter(name: "CIRadialGradient"),
              let blend = CIFilter(name: "CIBlendWithMask") else {
            return nil
        }

        let diameter = min(input.extent.width, input.extent.height)
        let center = CIVector(x: input.extent.midX, y: input.extent.midY)

        lens.setValue(input, forKey: kCIInputImageKey)
        lens.setValue(center, forKey: kCIInputCenterKey)
        lens.setValue(diameter * 0.50, forKey: kCIInputRadiusKey)
        lens.setValue(diameter * 0.24, forKey: kCIInputWidthKey)
        lens.setValue(1.62, forKey: kCIInputRefractionKey)

        mask.setValue(center, forKey: kCIInputCenterKey)
        mask.setValue(diameter * 0.32, forKey: "inputRadius0")
        mask.setValue(diameter * 0.49, forKey: "inputRadius1")
        mask.setValue(CIColor.black, forKey: "inputColor0")
        mask.setValue(CIColor.white, forKey: "inputColor1")

        blend.setValue(lens.outputImage, forKey: kCIInputImageKey)
        blend.setValue(input, forKey: kCIInputBackgroundImageKey)
        blend.setValue(mask.outputImage, forKey: kCIInputMaskImageKey)

        guard let output = blend.outputImage?.cropped(to: input.extent),
              let cgImage = renderingContext.createCGImage(
                output,
                from: input.extent
              ) else {
            return nil
        }

        let representation = NSBitmapImageRep(cgImage: cgImage)
        let renderedImage = NSImage(size: sourceImage.size)
        renderedImage.addRepresentation(representation)
        return renderedImage
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}

private final class CircularTitleView: NSView {
    var title = "" {
        didSet {
            setAccessibilityValue(title)
            needsDisplay = true
        }
    }

    var isMarqueeActive = false {
        didSet {
            guard isMarqueeActive != oldValue else { return }
            isMarqueeActive ? startMarquee() : stopMarquee()
        }
    }

    private var marqueeTimer: Timer?
    private var scrollOffset: CGFloat = 0
    private var previousTick: TimeInterval?

    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    deinit {
        marqueeTimer?.invalidate()
    }

    private func startMarquee() {
        previousTick = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) {
            [weak self] _ in
            guard let self else { return }

            let now = ProcessInfo.processInfo.systemUptime
            let elapsed = min(0.1, now - (self.previousTick ?? now))
            self.previousTick = now
            self.scrollOffset += CGFloat(elapsed) * 24
            self.needsDisplay = true
        }
        RunLoop.main.add(timer, forMode: .common)
        marqueeTimer = timer
    }

    private func stopMarquee() {
        marqueeTimer?.invalidate()
        marqueeTimer = nil
        previousTick = nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard !title.isEmpty,
              let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        let diameter = min(bounds.width, bounds.height)
        let fontSize = max(9, diameter * 0.036)
        let font = NSFont.systemFont(ofSize: fontSize, weight: .regular)
        let measuringAttributes: [NSAttributedString.Key: Any] = [
            .font: font
        ]
        let separator = "       •       "
        let segment = title + separator
        let segmentWidth = (segment as NSString).size(
            withAttributes: measuringAttributes
        ).width
        let radius = (diameter / 2) - max(12, diameter * 0.047)
        let startAngle = CGFloat.pi * (215 / 180)
        let arcSpan = CGFloat.pi * (250 / 180)
        let pathLength = radius * arcSpan
        let characters = segment.map(String.init)
        let advances = characters.map {
            max(
                1,
                ($0 as NSString).size(
                    withAttributes: measuringAttributes
                ).width
            )
        }
        guard segmentWidth > 0 else { return }

        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let phase = scrollOffset.truncatingRemainder(
            dividingBy: segmentWidth
        )
        let copyCount = Int(ceil(pathLength / segmentWidth)) + 2
        let fadeLength = max(22, diameter * 0.09)

        context.saveGState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.48)
        shadow.shadowBlurRadius = max(2, diameter * 0.012)
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.set()

        for copyIndex in -1...copyCount {
            var characterPosition = CGFloat(copyIndex) * segmentWidth + phase

            for (character, advance) in zip(characters, advances) {
                let centerPosition = characterPosition + (advance / 2)
                characterPosition += advance

                guard centerPosition >= 0,
                      centerPosition <= pathLength else {
                    continue
                }

                let edgeDistance = min(
                    centerPosition,
                    pathLength - centerPosition
                )
                let opacity = min(1, max(0, edgeDistance / fadeLength))
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: NSColor.white.withAlphaComponent(
                        0.94 * opacity
                    )
                ]
                let glyphAngle = startAngle - (centerPosition / radius)
                let point = NSPoint(
                    x: center.x + cos(glyphAngle) * radius,
                    y: center.y + sin(glyphAngle) * radius
                )

                context.saveGState()
                context.translateBy(x: point.x, y: point.y)
                context.rotate(by: glyphAngle - (.pi / 2))
                let glyphSize = (character as NSString).size(
                    withAttributes: attributes
                )
                (character as NSString).draw(
                    at: NSPoint(
                        x: -glyphSize.width / 2,
                        y: -font.capHeight / 2
                    ),
                    withAttributes: attributes
                )
                context.restoreGState()
            }
        }

        context.restoreGState()
    }
}

private final class GlassOverlayView: NSView {
    override var isOpaque: Bool { false }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let outerPath = NSBezierPath(
            ovalIn: bounds.insetBy(dx: 1.2, dy: 1.2)
        )
        outerPath.lineWidth = 1.8
        NSColor.white.withAlphaComponent(0.38).setStroke()
        outerPath.stroke()

        let innerPath = NSBezierPath(
            ovalIn: bounds.insetBy(dx: 4, dy: 4)
        )
        innerPath.lineWidth = 0.8
        NSColor.white.withAlphaComponent(0.09).setStroke()
        innerPath.stroke()

        let highlightPath = NSBezierPath()
        highlightPath.appendArc(
            withCenter: NSPoint(x: bounds.midX, y: bounds.midY),
            radius: (bounds.width / 2) - 2.4,
            startAngle: 102,
            endAngle: 168,
            clockwise: false
        )
        highlightPath.lineWidth = 1.7
        highlightPath.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.18).setStroke()
        highlightPath.stroke()
    }
}
