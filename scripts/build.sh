#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
configuration="${1:-debug}"

if [[ "$configuration" != "debug" && "$configuration" != "release" ]]; then
    echo "Usage: $0 [debug|release]" >&2
    exit 2
fi

if [[ "$configuration" == "release" ]]; then
    xcode_configuration="Release"
else
    xcode_configuration="Debug"
fi

xcodebuild \
    -project "$project_root/TokPeek.xcodeproj" \
    -scheme TokPeek \
    -configuration "$xcode_configuration" \
    -derivedDataPath "$project_root/.build/xcode" \
    CODE_SIGNING_ALLOWED=NO \
    build
