# Changelog

All notable changes to USB Bench are documented in this file.

The project follows [Semantic Versioning](https://semver.org/).

## Unreleased

## 1.3.0

### Added

- A sanitized, transparent BinaryBears raster logo in the application, with
  company attribution linked to the official website.
- A professional Finder DMG with custom artwork, drag-to-Applications layout,
  volume icon, website shortcut, checksum, and mounted-image verification.
- Focused tests for command timeouts and safe CSV field encoding.
- Attached-volume test support and cancellation-during-I/O regression coverage.

### Changed

- The final volume preflight now runs outside the main actor and has a bounded
  `diskutil` execution time, keeping the interface responsive.
- Application packaging and professional DMG creation are separate, explicit
  steps so the signed app can be notarized before it is placed in the DMG.
- Temporary benchmark files are unlinked immediately after their exclusive
  creation and remain accessible only through the active file descriptor.

### Fixed

- Retried interrupted and partial POSIX reads and writes instead of reporting
  avoidable benchmark failures.
- Neutralized formula-like CSV values before export to spreadsheet software.
- Prevented stale volume-inspection results and duplicate preflight starts from
  racing with a newer selection.
- Completed the Italian temporary-space cleanup status translation.
- Website download discovery now selects the latest stable release and keeps
  usable GitHub Releases links when the API is unavailable.

## 1.2.0

### Added

- Automatic, light, and dark appearance modes using native macOS colors.
- Results and comparison filters for cables and devices.
- Device-reported hardware names in persisted results and result details.
- BinaryBears LLC branding and attribution.
- Local and GitHub Actions pipelines for Developer ID signing, notarization,
  stapling, checksum generation, and DMG publication.
- Responsive bilingual GitHub Pages landing page with automatic theme support.
- Live discovery of the latest public GitHub Release and Apple Silicon DMG.
- Extended CSV export with hardware name, filesystem, and macOS device
  identifier.

### Changed

- Established the public MIT-licensed repository baseline.
- Made English the default localization while preserving Italian support.
- Standardized source formatting with the Swift formatter included in Xcode.
- Replaced third-party product-name examples with generic storage labels.
- Added original brand-neutral project visuals and expanded landing-page
  metadata for search and social previews.
- Replaced runtime icon generation with one canonical PNG used by packaging,
  the website, and the repository documentation.
- Documented SSH source signing and local Developer ID identity verification.
- Made releases an explicit manual action guarded by a maintainer-signed tag.
- Made Swift formatting checks compatible with both local and GitHub runner
  toolchains.
- Isolated Apple release credentials in a temporary Keychain during automation.
- Added an explicit distribution policy for maintainers, contributors, and
  automation agents.
- Hardened ignore rules against committing credentials and release binaries.

## 1.1.1

### Added

- Negotiated USB-link inspection before a benchmark.
- Free-space validation before I/O.
- Measurement protocol v2.
- Recoverable Trash for saved results.
- English and Italian application interface.
