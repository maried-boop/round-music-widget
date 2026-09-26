import AppKit
import Foundation

final class MusicLifecycleWatcher {
    private let workspace = NSWorkspace.shared
    private let musicBundleIdentifier = "com.apple.Music"
    private let widgetBundleIdentifier = "com.mariedrouvin.roundmusicwidget"
    private var observers: [NSObjectProtocol] = []

    private var widgetURL: URL? {
        let helperURL = URL(
            fileURLWithPath: CommandLine.arguments[0]
        )
        .standardizedFileURL
        .resolvingSymlinksInPath()

        let containingAppURL = helperURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        if containingAppURL.pathExtension == "app" {
            return containingAppURL
        }

        return workspace.urlForApplication(
            withBundleIdentifier: widgetBundleIdentifier
        )
    }

    func run() {
        let notificationCenter = workspace.notificationCenter

        observers = [
            notificationCenter.addObserver(
                forName: NSWorkspace.didLaunchApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.applicationDidLaunch(notification)
            },
            notificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                self?.applicationDidTerminate(notification)
            }
        ]

        if isApplicationRunning(bundleIdentifier: musicBundleIdentifier) {
            launchWidgetIfNeeded()
        }

        RunLoop.main.run()
    }

    private func applicationDidLaunch(_ notification: Notification) {
        guard application(from: notification)?.bundleIdentifier
                == musicBundleIdentifier else {
            return
        }

        launchWidgetIfNeeded()
    }

    private func applicationDidTerminate(_ notification: Notification) {
        guard application(from: notification)?.bundleIdentifier
                == musicBundleIdentifier else {
            return
        }

        NSRunningApplication.runningApplications(
            withBundleIdentifier: widgetBundleIdentifier
        ).forEach { application in
            if !application.terminate() {
                NSLog("Round Music Widget did not accept the quit request")
            }
        }
    }

    private func application(
        from notification: Notification
    ) -> NSRunningApplication? {
        notification.userInfo?[
            NSWorkspace.applicationUserInfoKey
        ] as? NSRunningApplication
    }

    private func isApplicationRunning(bundleIdentifier: String) -> Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: bundleIdentifier
        ).isEmpty
    }

    private func launchWidgetIfNeeded() {
        guard !isApplicationRunning(
            bundleIdentifier: widgetBundleIdentifier
        ) else {
            return
        }

        guard let widgetURL else {
            NSLog("Could not locate Round Music Widget")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        workspace.openApplication(
            at: widgetURL,
            configuration: configuration
        ) { _, error in
            if let error {
                NSLog(
                    "Could not open Round Music Widget: %@",
                    error.localizedDescription
                )
            }
        }
    }
}

let watcher = MusicLifecycleWatcher()
watcher.run()
