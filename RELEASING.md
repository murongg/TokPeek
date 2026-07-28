# Releasing TokPeek

TokPeek releases are signed with a Developer ID Application certificate,
submitted to Apple’s notary service, stapled, and then published as a Universal
2 ZIP with a SHA-256 checksum and a Sparkle appcast. The ZIP and appcast use a
separate EdDSA key so installed copies can authenticate application updates.

## Prerequisites

- Active Apple Developer Program membership
- A Developer ID Application certificate and its private key
- An App Store Connect team API key
- A Sparkle EdDSA update-signing key
- GitHub repository admin access
- GitHub CLI authenticated for `murongg/TokPeek`

Only a Developer ID Application certificate is suitable for signing a Mac app
distributed outside the Mac App Store. Export the certificate and private key
from Keychain Access as a password-protected `.p12` file.

Create an App Store Connect team API key under **Users and Access →
Integrations → Team Keys**. Save the downloaded `.p8` file, Key ID, and Issuer
ID. Apple only allows the private key to be downloaded once.

Generate the Sparkle key with the `generate_keys` tool bundled in Sparkle. The
private key remains in the macOS login keychain; copy the printed public key to
`SUPublicEDKey` in `Resources/Info.plist`.

```bash
sparkle_tools_dir=".build/xcode/SourcePackages/artifacts/sparkle/Sparkle/bin"
"$sparkle_tools_dir/generate_keys" --account tokpeek
```

## Configure GitHub secrets

Run these commands from a trusted Mac. File contents are sent directly to
GitHub Secrets and are not written to the repository:

```bash
base64 < DeveloperIDApplication.p12 \
  | gh secret set APPLE_DEVELOPER_ID_P12_BASE64
gh secret set APPLE_DEVELOPER_ID_P12_PASSWORD

base64 < AuthKey_ABC123DEFG.p8 \
  | gh secret set APPLE_NOTARY_KEY_P8_BASE64
gh secret set APPLE_NOTARY_KEY_ID
gh secret set APPLE_NOTARY_ISSUER_ID

temporary_key="$(mktemp -t tokpeek-sparkle).sparkle-private-key"
"$sparkle_tools_dir/generate_keys" \
  --account tokpeek \
  -x "$temporary_key"
gh secret set SPARKLE_EDDSA_PRIVATE_KEY < "$temporary_key"
rm -f "$temporary_key"
```

The required secret names are:

| Secret | Value |
| --- | --- |
| `APPLE_DEVELOPER_ID_P12_BASE64` | Base64-encoded `.p12` certificate |
| `APPLE_DEVELOPER_ID_P12_PASSWORD` | Password used when exporting the `.p12` |
| `APPLE_NOTARY_KEY_P8_BASE64` | Base64-encoded App Store Connect `.p8` key |
| `APPLE_NOTARY_KEY_ID` | App Store Connect API Key ID |
| `APPLE_NOTARY_ISSUER_ID` | App Store Connect API Issuer ID |
| `SPARKLE_EDDSA_PRIVATE_KEY` | Sparkle EdDSA private update-signing key |

Confirm that all names are present without printing their values:

```bash
gh secret list
```

Never commit the `.p12`, `.p8`, or exported Sparkle private-key files.
TokPeek’s `.gitignore` blocks the common credential filenames as an additional
safeguard.

## Publish a release

Create and push a stable semantic version tag:

```bash
git tag -a v0.1.0 -m "TokPeek v0.1.0"
git push origin v0.1.0
```

The Release workflow then:

1. Runs the complete Rust, Swift Package Manager, and Xcode test suites.
2. Imports the Developer ID certificate into an ephemeral keychain.
3. Builds a Universal 2 app with hardened runtime and a secure timestamp.
4. Verifies the Developer ID signature, timestamp, architectures, and version.
5. Submits the app to Apple with `notarytool` and waits for acceptance.
6. Staples and validates the notarization ticket, then runs Gatekeeper checks.
7. Generates an EdDSA-signed `appcast.xml` for Sparkle.
8. Publishes the final ZIP, SHA-256 checksum, and appcast to GitHub Releases.
9. Deletes the temporary keychain, certificate, API key, and submission files.

Release tags must use the exact form `vMAJOR.MINOR.PATCH`, such as `v1.2.3`.
The first release containing Sparkle bootstraps update support. Its update flow
can be exercised when the following release is published.

## Rotate credentials

If an Apple certificate or API key is exposed, revoke it immediately in Apple
Developer or App Store Connect. If the Sparkle private key is exposed, generate
a replacement, update both `SUPublicEDKey` and the GitHub Secret, and ship that
public-key change in a release signed by the previous trusted key whenever
possible. Do not reuse compromised credentials.
