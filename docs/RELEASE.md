# Release, signing, and notarization

USB Bench can be built and tested without Apple credentials. A public DMG
should be Developer ID signed, notarized, stapled, and verified before it is
published.

Git commit signing and macOS application signing are separate controls:

- Git commit signing proves the origin of a commit.
- Developer ID signing identifies the application publisher to Gatekeeper.
- Apple notarization scans a submitted build and issues a ticket.

Commit signing is recommended but does not replace Developer ID signing or
notarization.

## 1. Local pre-release validation

Run all checks before creating a tag:

```sh
swift format lint --recursive --parallel --strict \
  Sources Tests Package.swift scripts/make_icon.swift
swift test --disable-sandbox
./scripts/package_app.sh
./scripts/verify_release.sh
```

The local packaging command uses an ad-hoc signature by default. Never publish
that DMG as an official release.

## 2. One-time Apple setup

1. Enroll BinaryBears LLC in the Apple Developer Program.
2. Create and install a **Developer ID Application** certificate.
3. Export the certificate and private key as a password-protected `.p12`.
4. Create an App Store Connect API key for automated notarization and retain the
   `.p8` file, Key ID, and Issuer ID securely.

For a local manual release, store notarization credentials in the login
Keychain:

```sh
xcrun notarytool store-credentials "BinaryBears-Notary" \
  --apple-id "APPLE-ID" \
  --team-id "TEAM-ID" \
  --password "APP-SPECIFIC-PASSWORD"
```

Then identify the certificate:

```sh
security find-identity -v -p codesigning
```

Build and notarize:

```sh
SIGNING_IDENTITY="Developer ID Application: BinaryBears LLC (TEAMID)" \
  ./scripts/notarize_release.sh
```

The script builds for Apple Silicon, enables Hardened Runtime and a secure
timestamp, signs the application and DMG, submits the DMG with `notarytool`,
staples and validates the ticket, checks Gatekeeper, and writes a SHA-256 file.

## 3. One-time GitHub setup

Add these repository secrets under **Settings → Secrets and variables →
Actions**:

| Secret | Value |
| --- | --- |
| `APPLE_CERTIFICATE_P12_BASE64` | Developer ID `.p12`, Base64 encoded |
| `APPLE_CERTIFICATE_PASSWORD` | `.p12` export password |
| `APPLE_SIGNING_IDENTITY` | Full Developer ID Application identity |
| `APPLE_API_KEY_BASE64` | App Store Connect `.p8`, Base64 encoded |
| `APPLE_API_KEY_ID` | App Store Connect Key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect Issuer ID |

Encode files without creating intermediate plaintext copies:

```sh
base64 -i DeveloperID.p12 | pbcopy
base64 -i AuthKey_ABC123.p8 | pbcopy
```

Never commit `.p12`, `.p8`, passwords, Keychain profiles, or encoded credential
values.

## 4. Publish a release

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in
   `Packaging/Info.plist`.
2. Move relevant changelog entries from `Unreleased` to the new version.
3. Run every local check and confirm the `CI` workflow is green on `main`.
4. Create a tag whose value exactly matches the application version.

```sh
git tag -s v1.2.0 -m "USB Bench 1.2.0"
git push origin main
git push origin v1.2.0
```

Use a signed tag when a signing key is configured. An unsigned annotated tag is
acceptable for development, but should not be used for the official release.

The release workflow verifies the tag/version match, runs tests, imports the
certificate into a temporary Keychain, notarizes the DMG, publishes the DMG and
SHA-256 file, and removes the temporary Keychain.

Do not push a release tag until all Apple and GitHub secrets are configured.

## 5. GitHub Pages

The landing page is published from `docs/index.html` by the
`Publish GitHub Pages` workflow.

After the workflow is committed:

1. Open **Settings → Pages**.
2. Select **GitHub Actions** as the source.
3. Run the Pages workflow manually once, or push a change under `docs/`.

The page reads the latest public GitHub Release and links its Apple Silicon DMG.
It falls back to the Releases page if the public API is unavailable.
