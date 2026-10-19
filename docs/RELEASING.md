# Releasing FrameGen

FrameGen ships outside the Mac App Store: it runs `xcodebuild`, so it can't use the App Sandbox. A release is a Developer ID–signed, notarized `FrameGen-<version>.zip` attached to a GitHub release. The Homebrew cask in [Ramiz69/homebrew-tap](https://github.com/Ramiz69/homebrew-tap) points to that zip.

The zip contains `FrameGen.app` with the `framegen` command-line tool in `Contents/Helpers`. Xcode signs the tool with the app (hardened runtime, Developer ID), so notarizing the app covers it. The cask links it into the Homebrew `bin` folder with its `binary` stanza. `scripts/release.sh` checks that the tool is present, arm64-only, signed with the hardened runtime and reports the release version.

```
git tag v2.1 ──▶ .github/workflows/release.yml
                   ├─ scripts/release.sh 2.1     archive → Developer ID export → notarize → staple → zip
                   ├─ gh release create v2.1     attaches FrameGen-2.1.zip
                   └─ scripts/update-cask.sh     bumps Casks/framegen.rb in the tap (optional)
```

## One-time setup

### 1. Developer ID certificate

You need a paid Apple Developer Program membership (team `8AD8N54BY6`).

1. In Xcode, open **Settings → Accounts → Manage Certificates**, click **+** and choose **Developer ID Application**.
2. To use the certificate on CI, export it from Keychain Access (**My Certificates**, right-click the certificate → **Export…**) as a `.p12` with a strong password.

### 2. Notarization credentials

Create an App Store Connect API key at [App Store Connect → Users and Access → Integrations](https://appstoreconnect.apple.com/access/integrations/api) with the **Developer** role. Download the `.p8` file (you can only download it once) and note the key ID and issuer ID.

To release from your Mac, store the credentials in the keychain once:

```bash
xcrun notarytool store-credentials framegen-notary --key AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### 3. GitHub secrets

Add these in **Settings → Secrets and variables → Actions** of `Ramiz69/FrameGen`:

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_CERTIFICATE_P12_BASE64` | `base64 -i DeveloperID.p12 \| pbcopy` |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password of the `.p12` |
| `KEYCHAIN_PASSWORD` | Any random string; protects the temporary CI keychain |
| `APP_STORE_CONNECT_API_KEY_P8_BASE64` | `base64 -i AuthKey_XXXXXXXXXX.p8 \| pbcopy` |
| `APP_STORE_CONNECT_KEY_ID` | Key ID of the API key |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID |
| `HOMEBREW_TAP_TOKEN` | Optional. Fine-grained token with **Contents: read and write** on `Ramiz69/homebrew-tap`. Without it, the cask is updated by hand. |

### 4. Homebrew tap

1. Create a public repository named **`Ramiz69/homebrew-tap`**. Homebrew requires the `homebrew-` prefix.
2. After the first release, add `Casks/framegen.rb`, copied from [`packaging/homebrew/framegen.rb`](../packaging/homebrew/framegen.rb). If `HOMEBREW_TAP_TOKEN` is set, the release workflow does this for you.

Users then install FrameGen with:

```bash
brew install --cask ramiz69/tap/framegen
```

The official `homebrew/cask` repository only accepts notable projects. Once FrameGen has enough users, submit the cask there with `brew bump-cask-pr` or a pull request.

### 5. Runner with Xcode 27

The workflows need Xcode 27. If GitHub-hosted macOS runners don't have it yet, register a self-hosted runner on an Apple silicon Mac (**Settings → Actions → Runners**). Then change `runs-on` in `ci.yml` and `release.yml` to `[self-hosted, macOS, ARM64]`.

## Making a release

1. Make sure `main` is green, and update the README or changelog if needed.
2. Tag and push:

   ```bash
   git tag v2.1 && git push origin v2.1
   ```

   You can also run the **Release** workflow manually with a version from the Actions tab.
3. Watch the workflow. Notarization usually takes a few minutes.
4. Check the release page and, if the tap wasn't updated automatically, update the cask:

   ```bash
   scripts/update-cask.sh 2.1 build/release/FrameGen-2.1.zip ../homebrew-tap/Casks/framegen.rb
   ```

### Releasing from your Mac

With the certificate in your keychain and the `framegen-notary` profile stored:

```bash
NOTARY_PROFILE=framegen-notary scripts/release.sh 2.1
```

Then upload `build/release/FrameGen-2.1.zip` with `gh release create v2.1 build/release/FrameGen-2.1.zip --generate-notes`.

To check the build without signing or notarizing:

```bash
scripts/release.sh 2.1 --dry-run
```

## Troubleshooting

- **Notarization status is “Invalid”.** The script prints the notarization log. The usual causes are a missing hardened runtime, which is enabled in the project, or binaries that aren't signed with the Developer ID certificate.
- **“No Developer ID Application signing identity”.** The certificate isn't in the keychain search list. On CI, check the `DEVELOPER_ID_CERTIFICATE_*` secrets.
- **Gatekeeper rejects the app after download.** Run `xcrun stapler validate FrameGen.app` and `spctl --assess --type execute -vv FrameGen.app` on the downloaded copy.
