# USB Bench 1.3.0 local validation

Date: 2026-09-07. Target: version 1.3.0, build 5, Apple Silicon.
Branch: `update/v1.3.0`. This report covers the local release candidate,
including the accompanying uncommitted qualification and website changes.
It is not evidence of a published or notarized release.

## Executed checks

| Check | Result |
| --- | --- |
| Complete local quality gate (`scripts/check_all.sh`) | Passed; 12 Swift tests, no failures |
| Benchmark engine suite on a writable USB ExFAT volume | 7 tests passed |
| Benchmark engine suite on a writable NFS mount | 7 tests passed |
| ExFAT sequential probe, 2 GiB, 2 measured passes | Passed; integrity verified |
| NFS sequential probe, 2 GiB, 2 measured passes | Passed; integrity verified |
| DMG checksum and read-only mounted verification | Passed |
| Website desktop/mobile and Italian/English checks | Passed; no horizontal overflow or broken images in inspected views |
| Website API-unavailable path | Passed; download buttons point to GitHub Releases |
| Simulated 1.3.0 release response | Passed; both download buttons select the supplied DMG |

The engine suite includes sequential and 4K operations, anonymous temporary
files, progress, integrity, synthetic sentinel preservation, and cancellation
before and during I/O. No formatting, raw-device writes, or access to existing
user files was part of these tests. Test fixtures are isolated and cleaned up.

The NFS result qualifies the exposed network-mount stack only; it does not
certify native NTFS behavior or power-loss durability. Probe timings are not
published as a controlled performance comparison. Raw machine and volume
metadata remain outside tracked documentation.

The generated local DMG contains the branded Finder layout, application,
Applications link, background, volume icon, and company website shortcut.
Verification checks metadata, bundled raster logo, architecture, signature,
layout resources, and SHA-256. Its signature is ad-hoc, for local testing only.

## Publication gates still required

- Maintainer approval before new commits, pushes, website deployment, or release.
- Hosted CI on the exact approved source revision.
- Developer ID signing, Apple notarization and stapling, and Gatekeeper checks.
- Verification of the final signed DMG and its final checksum.
- Public release and website smoke test after authorized publication.

The website continues to obtain its download from the latest published stable
GitHub release; preparing 1.3.0 content locally does not publish a 1.3.0 binary.
