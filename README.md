Créé par Codex, le [[2026-09-26-Sat]]

# Round Music Widget

A tiny, native macOS companion for Apple Music. It keeps the current track artwork on the desktop as a draggable circular object with previous, play-pause and next controls.

Round Music Widget is a normal AppKit application, not a WidgetKit widget. It has no network service, analytics, account or third-party dependency.

## Status

Version 0.1.0 is a source-first beta. It is used daily on Apple silicon and has been tested with multiple displays. Broader macOS and Intel testing is still welcome.

## Features

- Current Apple Music track artwork
- Circular title and artist marquee on hover
- Previous, play-pause and next controls
- Four sizes
- Draggable transparent window with saved position
- Optional always-on-top behavior
- Automatic opening and closing with Apple Music
- No telemetry or network access

## Requirements

- macOS 14 or later
- Apple Music
- Apple's free Command Line Tools

If the Command Line Tools are missing, install them with:

```sh
xcode-select --install
```

No paid Apple Developer account is required.

## Install

Download or clone this repository, open Terminal in its directory and run:

```sh
./scripts/install.sh
```

The script builds the app locally, applies an ad hoc signature, installs it in `~/Applications`, and creates a user LaunchAgent that follows Apple Music's lifecycle. Because the app is built on your Mac rather than downloaded as a prebuilt binary, it does not depend on Marie's filesystem paths or signing identity.

The first time the widget reads or controls Apple Music, macOS may ask for Automation permission. Approve access to Music for the controls and artwork to work.

## Update

Pull or download the newer source, then run the installer again:

```sh
./scripts/install.sh
```

## Uninstall

From the repository directory, run:

```sh
./scripts/uninstall.sh
```

This removes the app and its LaunchAgent. It does not change Apple Music or disable any macOS security setting.

## Build without installing

```sh
./scripts/package-app.sh
```

The packaged app is written to `dist/Round Music Widget.app`.

## Official distribution

This project does not publish prebuilt application binaries. The official release is the source in Marie Drouvin's GitHub repository, built locally by each user. A binary offered by a fork, mirror or third-party download site has not been built, reviewed or endorsed by Marie.

The MIT licence covers the source code. It does not grant permission to impersonate Marie Drouvin or present a modified build as an official release.

## Privacy and security

Round Music Widget communicates only with the local Music application through macOS Apple Events. Track metadata and artwork remain on the Mac. The artwork cache uses the current user's temporary directory.

The project deliberately does not ask users to disable Gatekeeper. Public binaries are not currently distributed because frictionless third-party macOS binaries require a paid Developer ID certificate and Apple notarization.

Please report suspected vulnerabilities privately through GitHub's security reporting interface. Do not include sensitive details in a public issue.

## Known limitations

- Apple Music must be running.
- Some tracks do not expose artwork through AppleScript; the widget then shows a neutral music symbol.
- The first public beta has primarily been tested on Apple silicon.
- The interface is currently English-only.

## Development

Build both Swift executables with:

```sh
swift build
```

The main application lives in `Sources/RoundMusicWidget`. The small helper in `Sources/MusicLifecycleWatcher` observes Apple Music launch and termination events. The installer generates the machine-specific LaunchAgent path at installation time.

## Licence

MIT. See `LICENSE`.

Apple Music is a trademark of Apple Inc. This independent project is not affiliated with or endorsed by Apple.
