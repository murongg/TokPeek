#!/usr/bin/env bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_path="$project_root/rust/Cargo.toml"
target_root="$project_root/rust/target"
output_directory="$target_root/universal/release"
output_library="$output_directory/libtokpeek_core_ffi.a"
requested_architectures="${ARCHS:-$(uname -m)}"
libraries=()

mkdir -p "$output_directory"

for architecture in $requested_architectures; do
    case "$architecture" in
        arm64)
            rust_target="aarch64-apple-darwin"
            ;;
        x86_64)
            rust_target="x86_64-apple-darwin"
            ;;
        *)
            echo "Unsupported macOS architecture: $architecture" >&2
            exit 2
            ;;
    esac

    if ! rustup target list --installed | grep -qx "$rust_target"; then
        echo "Missing Rust target: $rust_target" >&2
        echo "Install it with: rustup target add $rust_target" >&2
        exit 1
    fi

    cargo build \
        --manifest-path "$manifest_path" \
        --package tokpeek-core-ffi \
        --target "$rust_target" \
        --release

    libraries+=(
        "$target_root/$rust_target/release/libtokpeek_core_ffi.a"
    )
done

if [[ "${#libraries[@]}" -eq 1 ]]; then
    cp "${libraries[0]}" "$output_library"
else
    xcrun lipo -create "${libraries[@]}" -output "$output_library"
fi

xcrun lipo -info "$output_library"
