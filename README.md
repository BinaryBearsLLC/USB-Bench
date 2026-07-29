# USB Bench

[![CI](https://github.com/BinaryBearsLLC/USB-Bench/actions/workflows/ci.yml/badge.svg)](https://github.com/BinaryBearsLLC/USB-Bench/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

USB Bench is a native macOS utility for measuring and comparing storage devices,
USB cables, enclosures, hubs, and ports. It is developed by
[BinaryBears](https://binarybears.com) and released as open-source software
under the MIT License.

## Highlights

- Device and cable test modes with an explicit reference component.
- Quick, complete, and single-operation benchmark profiles.
- Sequential read and write measurements with `F_NOCACHE`.
- Separate transfer and durable-write results, including drive synchronization.
- 4K random read and write measurements in the complete profile.
- Data-integrity verification outside the timed read measurement.
- Negotiated USB-link, free-space, filesystem, and device metadata inspection.
- Local SQLite history, recoverable Trash, guided comparisons, and CSV export.
- English-first interface with built-in Italian localization.
- Native Apple Silicon release build and drag-to-Applications DMG packaging.

## Safety model

USB Bench does not format, unmount, or access raw disks. A benchmark creates one
uniquely named `.usbbench-<UUID>.tmp` file inside the selected directory. The
engine removes only that file when the test completes, fails, or is cancelled.
Existing files are never opened, read, modified, or deleted.

The automated tests use isolated temporary directories and include a sentinel
file check to enforce this boundary.

## Requirements

- macOS 14 or later
- Apple Silicon Mac
- Xcode with Swift 6 or later for development
- Apple Developer Program membership only for public Developer ID releases

## Build and test

```sh
swift test --disable-sandbox
./scripts/package_app.sh
./scripts/verify_release.sh
```

`package_app.sh` creates an ad-hoc-signed local test DMG under `dist/`. It is
appropriate for local validation, but a public release should be signed with a
Developer ID Application certificate and notarized by Apple.

## Project layout

```text
Sources/USBBenchApp/       SwiftUI application and localization
Sources/USBBenchCore/      benchmark engine, models, SQLite, system inspection
Sources/USBBenchProbe/     command-line diagnostics
Tests/                     non-destructive automated tests
Packaging/                 application bundle metadata and icon configuration
scripts/                   build, verification, signing, and notarization
docs/                      development, release, and GitHub Pages content
.github/workflows/         continuous integration and release automation
```

Results are stored locally at:

```text
~/Library/Application Support/USB Bench/results.sqlite3
```

USB Bench has no telemetry, analytics, account system, or cloud dependency.

## Documentation

- [Development guide](docs/DEVELOPMENT.md)
- [Release and notarization guide](docs/RELEASE.md)
- [Contributing](CONTRIBUTING.md)
- [Security policy](SECURITY.md)
- [Changelog](CHANGELOG.md)

## License

Copyright © 2026 BinaryBears LLC.

The source code is licensed under the [MIT License](LICENSE). The USB Bench and
BinaryBears names and logos are not granted as trademarks by that license.
