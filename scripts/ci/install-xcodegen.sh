#!/usr/bin/env bash
# Installs a pinned XcodeGen release (reproducible); falls back to Homebrew.
set -euo pipefail
VERSION="${XCODEGEN_VERSION:-2.42.0}"
DEST="$RUNNER_TEMP/xcodegen"
if curl -fsSL --retry 3 -o "$RUNNER_TEMP/xcodegen.zip" "https://github.com/yonaskolb/XcodeGen/releases/download/${VERSION}/xcodegen.zip"; then
  rm -rf "$DEST"
  unzip -q "$RUNNER_TEMP/xcodegen.zip" -d "$RUNNER_TEMP/xcodegen-unzip"
  mv "$RUNNER_TEMP/xcodegen-unzip/xcodegen" "$DEST"
  echo "$DEST/bin" >> "$GITHUB_PATH"
  "$DEST/bin/xcodegen" --version
else
  echo "Pinned download failed; installing XcodeGen with Homebrew"
  brew install xcodegen
  xcodegen --version
fi
