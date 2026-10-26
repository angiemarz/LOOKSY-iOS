#!/usr/bin/env bash
# Runs xcodebuild writing the full log to a file, then prints a readable
# summary. Compiler errors are re-emitted as GitHub annotations.
# Usage: run-xcodebuild.sh <logfile> <xcodebuild args...>
set -uo pipefail
LOG="$1"; shift
mkdir -p "$(dirname "$LOG")"
echo "▶ xcodebuild $*"
xcodebuild "$@" > "$LOG" 2>&1
STATUS=$?
if [ $STATUS -ne 0 ]; then
  echo "::group::Last 120 log lines"
  tail -n 120 "$LOG"
  echo "::endgroup::"
  echo "──────── Compiler / test errors ────────"
  grep -E "(error:|: error|Test Case .* failed|XCTAssert|fatal error)" "$LOG" | sort -u | head -n 80 | while IFS= read -r line; do
    echo "::error::$line"
    echo "$line"
  done
  echo "xcodebuild failed with status $STATUS"
  exit $STATUS
fi
grep -E "(Executed [0-9]+ test|\*\* (BUILD|TEST) SUCCEEDED)" "$LOG" | tail -n 5
echo "xcodebuild succeeded"
