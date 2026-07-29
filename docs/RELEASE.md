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
./scripts/check_all.sh
```

The local packaging command uses an ad-hoc signature by default. Never publish
that DMG as an official release.

## 2. Sign source commits and tags

Git commit signing uses a Git signing key. It does not use the Apple Developer
ID certificate that signs the application.

SSH signing is the recommended setup for this repository because it is
supported by the Git and OpenSSH versions included with current macOS releases.
Create a dedicated key outside the repository and protect it with a strong
passphrase:

```sh
mkdir -p -m 700 ~/.ssh
ssh-keygen \
  -t ed25519 \
  -a 100 \
  -C "YOUR_VERIFIED_GITHUB_EMAIL" \
  -f ~/.ssh/id_ed25519_binarybears_signing
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_binarybears_signing
```

Add the contents of
`~/.ssh/id_ed25519_binarybears_signing.pub` to the maintainer's GitHub account
as an **SSH signing key**, not as a deploy key. The commit email must be
verified on the same GitHub account.

Configure signing locally for this repository:

```sh
git config --local gpg.format ssh
git config --local user.email "YOUR_VERIFIED_GITHUB_EMAIL"
git config --local user.signingkey ~/.ssh/id_ed25519_binarybears_signing.pub
git config --local commit.gpgsign true
git config --local tag.gpgsign true
printf '%s %s\n' \
  "YOUR_VERIFIED_GITHUB_EMAIL" \
  "$(cat ~/.ssh/id_ed25519_binarybears_signing.pub)" \
  > .git/allowed_signers
git config --local gpg.ssh.allowedSignersFile .git/allowed_signers
```

Verify a signed commit locally:

```sh
git log --show-signature -1
git cat-file commit HEAD | grep '^gpgsig '
```

Do not rewrite signed or unsigned commits after they have been published. If
the initial commits have not been pushed yet, sign them before the first push.

## 3. One-time Apple setup

1. Enroll BinaryBears LLC in the Apple Developer Program.
2. Create and install a **Developer ID Application** certificate.
3. Export the certificate and private key as a password-protected `.p12`.
4. Create an App Store Connect API key for automated notarization and retain the
   `.p8` file, Key ID, and Issuer ID securely.

Being signed in to an Apple Account in Xcode does not prove that the signing
identity is usable on the Mac. Confirm that the certificate and its private key
are both present:

```sh
security find-identity -v -p codesigning
```

The output must include an identity similar to:

```text
Developer ID Application: BinaryBears LLC (TEAMID)
```

`0 valid identities found` means that the Mac does not have a usable private
key for code signing. If the certificate belongs to another team member,
obtain a password-protected `.p12` export through an approved secure channel.
Alternatively, the Account Holder can create a new Developer ID Application
identity; Admins require the relevant Developer ID certificate access. The
GitHub release runner needs an exportable certificate and private key in
password-protected `.p12` form, not a cloud-only signing identity.

For a local manual release, store notarization credentials in the login
Keychain:

```sh
xcrun notarytool store-credentials "BinaryBears-Notary" \
  --apple-id "APPLE-ID" \
  --team-id "TEAM-ID" \
  --password "APP-SPECIFIC-PASSWORD"
```

Build and notarize:

```sh
SIGNING_IDENTITY="Developer ID Application: BinaryBears LLC (TEAMID)" \
  ./scripts/notarize_release.sh
```

The script builds for Apple Silicon, enables Hardened Runtime and a secure
timestamp, signs the application and DMG, submits the DMG with `notarytool`,
staples and validates the ticket, checks Gatekeeper, and writes a SHA-256 file.

## 4. One-time GitHub setup

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

## 5. Prepare a release

1. Update `CFBundleShortVersionString` and `CFBundleVersion` in
   `Packaging/Info.plist`.
2. Move relevant changelog entries from `Unreleased` to the new version.
3. Run `./scripts/check_all.sh`, commit the release preparation, and push
   `main`.
4. Confirm that the `CI` workflow is green on the exact `main` commit.
5. Create and verify a signed tag whose value exactly matches the application
   version, then push only that tag.

```sh
git tag -s v1.2.1 -m "USB Bench 1.2.1"
git verify-tag v1.2.1
git push origin v1.2.1
```

Pushing a tag does not publish anything. It only makes the signed release point
available to GitHub.

## 6. Publish when you decide

1. Open the repository's **Actions** tab.
2. Select **Release notarized DMG**.
3. Select **Run workflow**.
4. Keep the branch set to `main`, enter the version without the `v` prefix,
   and start the workflow.

This manual action is the only release trigger. The workflow requires the
matching signed tag, verifies that the tag belongs to `main`, checks the
application version, runs tests, imports Apple credentials into an isolated
temporary Keychain, signs and notarizes the DMG, validates Gatekeeper, and only
then creates the public GitHub Release with the DMG and SHA-256 file.

If any check, signing operation, or notarization step fails, no GitHub Release
is published. Re-running an already published version is also rejected instead
of overwriting its artifacts.

## 7. GitHub Pages

The landing page is published from `docs/index.html` by the
`Publish GitHub Pages` workflow.

Before the first Pages workflow run:

1. Open **Settings → Pages**.
2. Under **Build and deployment**, select **GitHub Actions** as the source.
3. Run the Pages workflow manually once.

This is a one-time repository setting. After it is enabled, pushes that modify
`docs/` publish the website automatically. Source-code-only changes do not
redeploy the website.

The page reads the latest public GitHub Release and links its Apple Silicon DMG.
It falls back to the Releases page if the public API is unavailable.
