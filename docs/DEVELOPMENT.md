# Development guide

## Architecture

`USBBenchApp` contains the SwiftUI application and depends on `USBBenchCore`.
The core does not depend on the interface:

- `BenchmarkEngine` owns temporary I/O, measurement, verification, and cleanup.
- `SystemInspector` reads volume, hardware, connection, and negotiated-link
  metadata.
- `Models` defines persisted, backward-compatible payloads.
- `ResultStore` owns the local SQLite database and recoverable Trash.
- `USBBenchProbe` is a separate diagnostic executable and is not bundled in the
  application.

## Prerequisites

- macOS 14 or later
- Apple Silicon Mac
- Xcode with Swift 6 or later

The current public baseline was verified with Xcode 26.6 and Apple Swift 6.3.3.
The package declares Swift tools version 6.0 and Swift language mode 5.

## Local checks

Format source files:

```sh
swift format format --recursive --in-place \
  Sources Tests Package.swift
```

Lint and test:

```sh
swift format lint --recursive --parallel --strict \
  Sources Tests Package.swift
swift test --disable-sandbox
./scripts/verify_brand_assets.sh
```

Build and verify the local DMG:

```sh
./scripts/package_app.sh
./scripts/verify_release.sh
```

The verification script mounts the DMG read-only and checks its bundle metadata,
signature, Apple Silicon architecture, and Applications symlink.

## Storage-safety invariants

Every benchmark-engine change must preserve these properties:

1. No formatting, unmounting, or raw-device access.
2. No opening, reading, modifying, or deleting existing user files.
3. Writes are limited to one `.usbbench-<UUID>.tmp` file.
4. Cleanup targets only the URL created by the active benchmark.
5. Free space is checked in the interface and immediately before I/O.
6. The test stops if macOS rejects `F_NOCACHE`.
7. Automated tests write only to isolated temporary directories.

The sequential buffer is 4 KiB aligned and capped at 8 MiB. Measurement
protocol v2 records transfer write speed, durable write speed, synchronization
latency, sequential read speed, optional 4K QD1 measurements, cache policy, and
protocol metadata.

## Data compatibility

Each result is serialized as JSON in the SQLite `payload` column. New persisted
fields must be optional or have backward-compatible decoding behavior.

Changes that alter measurement meaning or comparability must increment:

```swift
BenchmarkEngine.measurementProtocolVersion
```

The comparison interface flags results created by different protocol versions.

## Versioning

The public version and build number are defined only in
`Packaging/Info.plist`:

- `CFBundleShortVersionString` is the semantic version.
- `CFBundleVersion` is the monotonically increasing build number.

Packaging and release automation read the version from that file.

## Brand assets

`Assets/USB-Bench-Icon.png` is the canonical 1024-by-1024 PNG for the
application icon and the public project identity. Packaging derives the macOS
icon set directly from this file.

The optimized website icon is generated from the same master:

```sh
./scripts/sync_brand_assets.sh
```

Do not edit `docs/assets/usb-bench-icon.png` independently. CI verifies its
dimensions and compares it with a freshly generated derivative of the
canonical icon.
