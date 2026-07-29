# Security policy

## Supported versions

Security fixes are applied to the latest released version and the current
`main` branch. Older releases may not receive backports.

## Reporting a vulnerability

Please use GitHub private vulnerability reporting from the repository's
**Security** tab when that option is available.

If private reporting is unavailable, open a minimal issue requesting a private
security contact. Do not include exploit details, credentials, private device
information, or personal data in a public issue.

Include the affected version, macOS version, impact, reproduction boundary, and
whether the issue can affect files outside USB Bench's uniquely named temporary
benchmark file.

## Scope

Security-sensitive areas include:

- benchmark file creation and cleanup;
- path validation and free-space checks;
- SQLite result parsing and migration;
- release signing and notarization;
- GitHub Actions secrets and generated release artifacts.

Reports about benchmark accuracy are welcome, but measurement variance without
a security impact should be filed as a normal bug.
