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

if [[ "$signing_identity" == "-" ]]; then
    codesign \
        --force \
        --options runtime \
        --sign "$signing_identity" \
        "$app_path"
else
    codesign \
        --force \
        --options runtime \
        --timestamp \
        --sign "$signing_identity" \
        "$app_path"
fi

codesign --verify --deep --strict --verbose=2 "$app_path"

echo "Created $app_path"
