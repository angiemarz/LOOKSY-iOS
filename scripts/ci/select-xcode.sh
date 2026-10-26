#!/usr/bin/env bash
# Uses the newest stable Xcode installed on the runner (no betas).
set -euo pipefail
CANDIDATE=$(ls -d /Applications/Xcode_*.app 2>/dev/null | grep -v -i -E "beta|rc" | sort -t_ -k2 -V | tail -n 1 || true)
if [ -n "$CANDIDATE" ]; then
  echo "Selecting $CANDIDATE"
  sudo xcode-select -s "$CANDIDATE/Contents/Developer"
fi
xcodebuild -version
swift --version
xcrun --sdk iphoneos --show-sdk-version
