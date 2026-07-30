# Distribution policy

This document defines the boundary between normal source development and
publishing an official USB Bench binary. It applies to maintainers,
contributors, CI automation, and AI agents working in this repository.

## Source changes are not releases

| Action | Automated result | Public application release |
| --- | --- | --- |
| Commit or push source code | CI validates formatting, tests, and packaging | No |
| Push a change under `docs/` | CI runs and GitHub Pages is updated | No |
| Push a signed version tag | The tag becomes available to the release workflow | No |
| Manually run `Release notarized DMG` | The tagged source is built, signed, notarized, and published | Yes |

Normal development follows this sequence:

1. Make one focused change.
2. Run `./scripts/check_all.sh`.
3. Review the diff.
4. Create a signed commit with an English commit message.
5. Push the commit and wait for CI.

Do not change the application version or create a release merely because source
code was pushed. Documentation-only and internal changes may not require a new
binary distribution.

## Official release boundary

An official release requires a deliberate maintainer action:

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in
   `Packaging/Info.plist`.
2. Update `CHANGELOG.md`.
3. Pass the complete local quality gate and the CI workflow on `main`.
4. Create, verify, and push a signed `vX.Y.Z` tag.
5. Manually start `Release notarized DMG` from GitHub Actions.

Pushing a commit or tag never starts this workflow. The workflow verifies the
maintainer signature, tag ancestry, and application version before accessing
Apple credentials. It publishes only after Developer ID signing, Apple
notarization, ticket stapling, Gatekeeper assessment, and checksum generation
have all succeeded.

Never replace an existing release asset or reuse a published version tag.
Publish a new version instead. See [RELEASE.md](RELEASE.md) for the operational
procedure.

## Credentials and artifacts

Repository secrets may contain the Developer ID certificate, its password, and
App Store Connect notarization credentials. Only secret names belong in source
control. Secret values must never appear in files, commits, tags, issues,
workflow output, screenshots, documentation, or chat transcripts.

The following files must remain outside Git:

- `.p12`, `.p8`, `.pem`, `.key`, `.cer`, and provisioning-profile files;
- `.env` files and plaintext or Base64 credential exports;
- local Keychains and notarization profiles;
- DMGs, application bundles, packages, archives, and build directories.

Base64 is transport encoding, not encryption. Encoded certificates and keys
must be handled as secrets.

Local DMGs are ad-hoc signed unless the Developer ID release procedure is used.
They are test artifacts and must not be uploaded as official downloads.

## Automation and AI-agent rule

Unless the maintainer explicitly requests a release, automation and AI agents
must stop after validated source commits. They must not:

- create or push version tags;
- start the release workflow;
- upload or replace release assets;
- print, read back, copy, or expose repository-secret values.

The maintainer retains the final manual release decision.
