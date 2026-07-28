#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

export MACOSX_DEPLOYMENT_TARGET=14.0

cargo test \
    --manifest-path "$project_root/rust/Cargo.toml" \
    --package tokpeek-core-ffi

cargo build \
    --manifest-path "$project_root/rust/Cargo.toml" \
    --package tokpeek-core-ffi \
    --release

swift test --package-path "$project_root"

xcodebuild \
    -project "$project_root/TokPeek.xcodeproj" \
    -scheme TokPeek \
    -configuration Debug \
    -derivedDataPath "$project_root/.build/xcode" \
    CODE_SIGNING_ALLOWED=NO \
    test
