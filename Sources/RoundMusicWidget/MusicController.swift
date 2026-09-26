import AppKit
import Foundation

final class MusicController {
    var onMusicAppUnavailable: (() -> Void)?

    var onPlaybackStateChanged: ((Bool) -> Void)? {
        didSet {
            onPlaybackStateChanged?(isPlaying)
        }
    }

    private(set) var isPlaying = false {
        didSet {
            guard isPlaying != oldValue else { return }
            onPlaybackStateChanged?(isPlaying)
        }
    }

    var onArtworkChanged: ((NSImage?) -> Void)?

    var onTrackInfoChanged: ((String, String) -> Void)? {
        didSet {
            onTrackInfoChanged?(trackTitle, trackArtist)
        }
    }

    private(set) var trackTitle = "" {
        didSet {
            guard trackTitle != oldValue else { return }
            onTrackInfoChanged?(trackTitle, trackArtist)
        }
    }

    private(set) var trackArtist = "" {
        didSet {
            guard trackArtist != oldValue else { return }
            onTrackInfoChanged?(trackTitle, trackArtist)
        }
    }

    private var stateTimer: Timer?
    private var currentArtworkKey = ""
    private var isRefreshingMetadata = false

    init() {
        refreshPlaybackState()
        stateTimer = Timer.scheduledTimer(
            withTimeInterval: 2.0,
            repeats: true
        ) { [weak self] _ in
            self?.refreshPlaybackState()
        }
    }

    deinit {
        stateTimer?.invalidate()
    }

    func previousTrack() {
        runMusicCommand("previous track")
    }

    func playPause() {
        runMusicCommand("playpause")
    }

    func nextTrack() {
        runMusicCommand("next track")
    }

    private func runMusicCommand(_ command: String) {
        guard musicIsRunning else {
            onMusicAppUnavailable?()
            return
        }

        executeAppleScript(
            "tell application \"Music\" to \(command)"
        ) { [weak self] _ in
            self?.refreshPlaybackState()
        }
    }

    private func refreshPlaybackState() {
        guard !isRefreshingMetadata else { return }

        guard musicIsRunning else {
            onMusicAppUnavailable?()
            return
        }

        isRefreshingMetadata = true

        let script = """
        if application "Music" is running then
            tell application "Music"
                try
                    set playbackState to player state as text
                    set trackIdentifier to database ID of current track as text
                    set trackName to name of current track
                    set trackArtist to artist of current track
                    return playbackState & tab & trackIdentifier & tab & trackName & tab & trackArtist
                on error
                    return (player state as text) & tab & "" & tab & "" & tab & ""
                end try
            end tell
        end if
        return "stopped" & tab & "" & tab & "" & tab & ""
        """

        executeAppleScript(script) { [weak self] result in
            guard let self else { return }
            self.isRefreshingMetadata = false

            let parts = (result ?? "")
                .components(separatedBy: "\t")
            let playbackState = parts.first ?? "stopped"
            self.isPlaying = playbackState == "playing"

            let trackIdentifier = parts.count > 1 ? parts[1] : ""
            self.trackTitle = parts.count > 2 ? parts[2] : ""
            self.trackArtist = parts.count > 3 ? parts[3] : ""
            let artworkKey = [
                trackIdentifier,
                self.trackTitle,
                self.trackArtist
            ].joined(separator: "|")

            guard artworkKey != "||",
                  artworkKey != self.currentArtworkKey else {
                return
            }

            self.currentArtworkKey = artworkKey
            self.refreshArtwork()
        }
    }

    private func refreshArtwork() {
        guard musicIsRunning else {
            onMusicAppUnavailable?()
            return
        }

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "RoundMusicWidget",
                isDirectory: true
            )

        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        } catch {
            NSLog("Could not create artwork cache: %@", error.localizedDescription)
            return
        }

        let artworkURL = directory.appendingPathComponent(
            "current-artwork"
        )
        let scriptPath = appleScriptLiteral(artworkURL.path)

        let script = """
        set outputFile to POSIX file "\(scriptPath)"
        set artworkData to missing value

        if application "Music" is not running then return ""

        tell application "Music"
            try
                if (count of artworks of current track) > 0 then
                    set artworkData to raw data of artwork 1 of current track
                end if
            end try

        end tell

        if artworkData is missing value then return ""

        set fileReference to open for access outputFile with write permission
        try
            set eof fileReference to 0
            write artworkData to fileReference
            close access fileReference
        on error errorMessage number errorNumber
            try
                close access fileReference
            end try
            error errorMessage number errorNumber
        end try

        return POSIX path of outputFile
        """

        executeAppleScript(script) { [weak self] result in
            guard let self,
                  let path = result,
                  !path.isEmpty,
                  let image = NSImage(contentsOfFile: path) else {
                self?.onArtworkChanged?(nil)
                return
            }

            self.onArtworkChanged?(image)
        }
    }

    private func appleScriptLiteral(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private var musicIsRunning: Bool {
        !NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.apple.Music"
        ).isEmpty
    }

    private func executeAppleScript(
        _ source: String,
        completion: @escaping (String?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            var errorInfo: NSDictionary?
            let result = NSAppleScript(source: source)?
                .executeAndReturnError(&errorInfo)
                .stringValue

            if let errorInfo {
                NSLog("Apple Music command failed: %@", errorInfo)
            }

            DispatchQueue.main.async {
                completion(result)
            }
        }
    }
}
