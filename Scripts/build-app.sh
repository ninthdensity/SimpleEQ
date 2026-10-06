#!/bin/bash
# Builds build/SimpleEQ.app. Set SIGN_IDENTITY to a Developer ID Application identity
# for distribution; the default is a local ad-hoc signature.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
build_dir="${SIMPLEEQ_BUILD_DIR:-$project_dir/.build}"
app_dir="$project_dir/build/SimpleEQ.app"
identity="${SIGN_IDENTITY:--}"
configuration="${CONFIGURATION:-release}"
swift_build=(swift build --scratch-path "$build_dir" -c "$configuration")
"${swift_build[@]}"
binary_dir="$("${swift_build[@]}" --show-bin-path)"

rm -rf "$app_dir"
mkdir -p "$app_dir/Contents/MacOS" "$app_dir/Contents/Resources"
cp "$binary_dir/SimpleEQ" "$app_dir/Contents/MacOS/SimpleEQ"
cp Resources/Info.plist "$app_dir/Contents/Info.plist"

# The hardened runtime blocks audio input unless the entitlement is in the signature.
sign_args=(--force --options runtime --entitlements Resources/SimpleEQ.entitlements --sign "$identity")
if [[ "$identity" != "-" ]]; then
  sign_args+=(--timestamp)
fi
codesign "${sign_args[@]}" "$app_dir"
codesign --verify --strict "$app_dir"
echo "Built $app_dir"
