# Security policy

## Reporting a vulnerability

Use GitHub's private vulnerability reporting interface when it is available for this repository. Please do not include exploit details, private data or credentials in a public issue.

If private reporting is unavailable, open a minimal issue asking the maintainer to provide a private channel. Do not disclose the vulnerability in that issue.

## Distribution model

Round Music Widget is distributed as source code. It does not publish official prebuilt application binaries. Users build and ad hoc sign the application locally with Apple's free Command Line Tools.

A binary from a fork, mirror or third-party download site has not been built, reviewed or endorsed by Marie Drouvin.

## Data and permissions

The application has no account, analytics, remote service or update mechanism. It asks macOS for Automation permission to read the current track and control playback in the local Music application. Artwork is written only to the current user's temporary directory.
