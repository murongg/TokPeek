#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_path="$project_root/dist/TokPeek.app"
source_app="$project_root/.build/xcode/Build/Products/Release/TokPeek.app"
signing_identity="${CODE_SIGN_IDENTITY:--}"

"$project_root/scripts/build.sh" release

rm -rf "$app_path"
mkdir -p "$(dirname "$app_path")"
ditto "$source_app" "$app_path"

if [[ -n "${MARKETING_VERSION:-}" ]]; then
    plutil -replace CFBundleShortVersionString \
        -string "$MARKETING_VERSION" \
        "$app_path/Contents/Info.plist"
fi
if [[ -n "${CURRENT_PROJECT_VERSION:-}" ]]; then
    plutil -replace CFBundleVersion \
        -string "$CURRENT_PROJECT_VERSION" \
        "$app_path/Contents/Info.plist"
fi

sign_target() {
    local target="$1"
    shift

    local codesign_arguments=(
        --force
        --options runtime
        --sign "$signing_identity"
    )
    if [[ "$signing_identity" != "-" ]]; then
        codesign_arguments+=(--timestamp)
    fi

    codesign "${codesign_arguments[@]}" "$@" "$target"
}

sparkle_framework="$app_path/Contents/Frameworks/Sparkle.framework"
if [[ -d "$sparkle_framework" ]]; then
    sparkle_version="$sparkle_framework/Versions/B"

    # Sparkle's services must be re-signed from the inside out. Signing the
    # outer app alone leaves the framework's resource seal invalid.
    sign_target "$sparkle_version/XPCServices/Installer.xpc"
    sign_target \
        "$sparkle_version/XPCServices/Downloader.xpc" \
        --preserve-metadata=entitlements
    sign_target "$sparkle_version/Autoupdate"
    sign_target "$sparkle_version/Updater.app"
    sign_target "$sparkle_framework"
fi

sign_target "$app_path"

codesign --verify --deep --strict --verbose=2 "$app_path"

echo "Created $app_path"
