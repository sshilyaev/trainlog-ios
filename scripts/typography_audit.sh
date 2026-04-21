#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TARGET_DIR="$ROOT_DIR/trainlog"
echo "== Typography audit =="
echo "Target: $TARGET_DIR"

echo
echo "-- raw fixed-size font usage (must be 0 in feature code) --"
grep -RInE --include="*.swift" "Font\\.system\\(|\\.font\\(\\.system\\(" "$TARGET_DIR" || true

echo
echo "-- app typography token usage --"
grep -RInE --include="*.swift" "\\.appTypography\\(" "$TARGET_DIR" || true

echo
echo "-- platform-limited controls (manual review list) --"
grep -RInE --include="*.swift" "DatePicker\\(|Slider\\(|\\.confirmationDialog\\(|\\.appConfirmationDialog\\(" "$TARGET_DIR" || true

