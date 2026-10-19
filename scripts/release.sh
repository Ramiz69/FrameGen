#!/bin/zsh
#
# Builds a FrameGen release: archive, Developer ID export, notarization, stapling,
# and the zip that GitHub Releases and the Homebrew cask point to.
#
# Usage: scripts/release.sh <version> [--dry-run]
#
#   <version>   Marketing version, e.g. 2.0 or 2.1.3. The build number is the commit count
#               unless BUILD_NUMBER is set.
#   --dry-run   Signs ad hoc and skips export, notarization and Gatekeeper checks, so the
#               script can be tried without a Developer ID certificate or notary credentials.
#
# Environment (required unless --dry-run):
#   NOTARY_PROFILE   notarytool keychain profile created with `xcrun notarytool store-credentials`.
#   NOTARY_KEYCHAIN  Optional keychain that holds the profile (used by the release workflow).
#
# Output: build/release/FrameGen-<version>.zip and FrameGen-<version>.zip.sha256 (hex digest only).

set -euo pipefail

usage() {
    print -u2 "Usage: scripts/release.sh <version> [--dry-run]"
    exit 2
}

fail() {
    print -u2 "error: $1"
    exit 1
}

step() {
    print -P "%B==> $1%b"
}

(( $# >= 1 && $# <= 2 )) || usage
VERSION=$1
DRY_RUN=false
if (( $# == 2 )); then
    [[ $2 == --dry-run ]] || usage
    DRY_RUN=true
fi
[[ $VERSION =~ '^[0-9]+(\.[0-9]+){1,2}$' ]] || fail "“$VERSION” is not a version like 2.0 or 2.1.3."

ROOT=${0:A:h:h}
cd "$ROOT"

TEAM_ID=8AD8N54BY6
OUTPUT=build/release
ARCHIVE=$OUTPUT/FrameGen.xcarchive
EXPORT=$OUTPUT/export
ZIP=$OUTPUT/FrameGen-$VERSION.zip
BUILD_NUMBER=${BUILD_NUMBER:-$(git rev-list --count HEAD)}

if $DRY_RUN; then
    SIGNING=(CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM=)
else
    [[ -n ${NOTARY_PROFILE:-} ]] || fail "Set NOTARY_PROFILE to a notarytool keychain profile, or pass --dry-run."
    security find-identity -v -p codesigning | grep -q "Developer ID Application" \
        || fail "No “Developer ID Application” signing identity in the keychain. See docs/RELEASING.md."
    SIGNING=(CODE_SIGN_STYLE=Manual "CODE_SIGN_IDENTITY=Developer ID Application" DEVELOPMENT_TEAM=$TEAM_ID)
fi

step "Building FrameGen $VERSION ($BUILD_NUMBER)$($DRY_RUN && print ' — dry run')"
rm -rf "$OUTPUT"
mkdir -p "$OUTPUT"
xcodebuild archive \
    -quiet \
    -project FrameGen.xcodeproj \
    -scheme FrameGen \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -archivePath "$ARCHIVE" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    "${SIGNING[@]}"

if $DRY_RUN; then
    step "Copying the app out of the archive (no Developer ID export in a dry run)"
    mkdir -p "$EXPORT"
    ditto "$ARCHIVE/Products/Applications/FrameGen.app" "$EXPORT/FrameGen.app"
else
    step "Exporting with Developer ID"
    xcodebuild -exportArchive \
        -quiet \
        -archivePath "$ARCHIVE" \
        -exportPath "$EXPORT" \
        -exportOptionsPlist scripts/ExportOptions.plist
fi
APP=$EXPORT/FrameGen.app

step "Checking the app"
codesign --verify --deep --strict --verbose=2 "$APP"
SHORT_VERSION=$(plutil -extract CFBundleShortVersionString raw "$APP/Contents/Info.plist")
[[ $SHORT_VERSION == "$VERSION" ]] || fail "The app reports version $SHORT_VERSION instead of $VERSION."
ARCHS=$(lipo -archs "$APP/Contents/MacOS/FrameGen")
[[ $ARCHS == arm64 ]] || fail "Expected an arm64-only binary, got: $ARCHS."

if $DRY_RUN; then
    step "Skipping notarization, stapling and Gatekeeper checks (dry run)"
else
    step "Notarizing (this usually takes a few minutes)"
    NOTARY_OPTIONS=(--keychain-profile "$NOTARY_PROFILE")
    [[ -n ${NOTARY_KEYCHAIN:-} ]] && NOTARY_OPTIONS+=(--keychain "$NOTARY_KEYCHAIN")
    SUBMISSION_ZIP=$OUTPUT/FrameGen-notarization.zip
    SUBMISSION_RESULT=$OUTPUT/notarization.json
    ditto -c -k --keepParent "$APP" "$SUBMISSION_ZIP"
    xcrun notarytool submit "$SUBMISSION_ZIP" "${NOTARY_OPTIONS[@]}" --wait --output-format json > "$SUBMISSION_RESULT"
    STATUS=$(plutil -extract status raw "$SUBMISSION_RESULT")
    if [[ $STATUS != Accepted ]]; then
        SUBMISSION_ID=$(plutil -extract id raw "$SUBMISSION_RESULT")
        xcrun notarytool log "$SUBMISSION_ID" "${NOTARY_OPTIONS[@]}" || true
        fail "Notarization finished with status “$STATUS”."
    fi
    rm -f "$SUBMISSION_ZIP"

    step "Stapling the notarization ticket"
    xcrun stapler staple "$APP"
    xcrun stapler validate "$APP"

    step "Checking Gatekeeper"
    spctl --assess --type execute --verbose=4 "$APP"
fi

step "Packaging"
ditto -c -k --keepParent "$APP" "$ZIP"
SHA256=$(shasum -a 256 "$ZIP" | awk '{ print $1 }')
print "$SHA256" > "$ZIP.sha256"

print
print "Version:  $VERSION ($BUILD_NUMBER)"
print "Archive:  $ZIP"
print "SHA-256:  $SHA256"
$DRY_RUN && print "Note:     ad-hoc signed and not notarized; don't publish this build."
exit 0
