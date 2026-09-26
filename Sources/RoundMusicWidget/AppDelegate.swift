import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = MusicController()
    private var panel: FloatingPanel?
    private var statusItem: NSStatusItem?
    private var sizeMenuItems: [NSMenuItem] = []
    private var musicTerminationObserver: NSObjectProtocol?

    private let sizeOptions: [(title: String, diameter: CGFloat)] = [
        ("Compact", 220),
        ("Medium", 300),
        ("Large", 380),
        ("Extra Large", 460)
    ]

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMusicLifecycle()
        createPanel()
        createStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        panel?.saveFrame(usingName: FloatingPanel.autosaveName)

        if let musicTerminationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(
                musicTerminationObserver
            )
        }
    }

    private func configureMusicLifecycle() {
        controller.onMusicAppUnavailable = {
            NSApp.terminate(nil)
        }

        musicTerminationObserver = NSWorkspace.shared.notificationCenter
            .addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { notification in
                guard let application = notification.userInfo?[
                    NSWorkspace.applicationUserInfoKey
                ] as? NSRunningApplication,
                application.bundleIdentifier == "com.apple.Music" else {
                    return
                }

                NSApp.terminate(nil)
            }
    }

    private func createPanel() {
        let size = NSSize(width: 300, height: 300)
        let panel = FloatingPanel(
            contentRect: NSRect(origin: .zero, size: size)
        )

        panel.contentView = WidgetView(
            frame: NSRect(origin: .zero, size: size),
            controller: controller
        )

        if !panel.setFrameUsingName(FloatingPanel.autosaveName) {
            panel.center()
        }

        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func createStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(
            withLength: NSStatusItem.squareLength
        )

        statusItem.button?.image = NSImage(
            systemSymbolName: "music.note",
            accessibilityDescription: "Round Music Widget"
        )

        let menu = NSMenu()
        menu.addItem(
            withTitle: "Show or hide widget",
            action: #selector(toggleWidget),
            keyEquivalent: ""
        )

        let alwaysOnTopItem = NSMenuItem(
            title: "Always on top",
            action: #selector(toggleAlwaysOnTop(_:)),
            keyEquivalent: ""
        )
        alwaysOnTopItem.state = .on
        menu.addItem(alwaysOnTopItem)

        let sizeMenu = NSMenu()
        sizeMenuItems = sizeOptions.map { option in
            let item = NSMenuItem(
                title: option.title,
                action: #selector(changeWidgetSize(_:)),
                keyEquivalent: ""
            )
            item.tag = Int(option.diameter)
            item.target = self
            sizeMenu.addItem(item)
            return item
        }
        let sizeItem = NSMenuItem(
            title: "Widget size",
            action: nil,
            keyEquivalent: ""
        )
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Round Music Widget",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        self.statusItem = statusItem
        updateSizeMenuState()
    }

    @objc private func toggleWidget() {
        guard let panel else { return }

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    @objc private func toggleAlwaysOnTop(_ sender: NSMenuItem) {
        guard let panel else { return }

        let shouldFloat = sender.state == .off
        sender.state = shouldFloat ? .on : .off
        panel.level = shouldFloat ? .floating : .normal
    }

    @objc private func changeWidgetSize(_ sender: NSMenuItem) {
        guard let panel else { return }

        let diameter = CGFloat(sender.tag)
        let oldFrame = panel.frame
        let center = NSPoint(x: oldFrame.midX, y: oldFrame.midY)
        let newFrame = NSRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )

        panel.setFrame(newFrame, display: true, animate: true)
        panel.saveFrame(usingName: FloatingPanel.autosaveName)
        updateSizeMenuState()
    }

    private func updateSizeMenuState() {
        guard let width = panel?.frame.width else { return }

        for item in sizeMenuItems {
            item.state = abs(CGFloat(item.tag) - width) < 1 ? .on : .off
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
