#!/usr/bin/env bash
# Generate the Xcode project, build NotchShelf, and (optionally) launch it.
#   ./build.sh        build only
#   ./build.sh run    build then relaunch the app
set -euo pipefail
cd "$(dirname "$0")"

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building (Debug)"
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf \
  -configuration Debug -derivedDataPath ./build \
  CODE_SIGNING_ALLOWED=NO build | tail -20

APP="./build/Build/Products/Debug/NotchShelf.app"
echo "==> Built: $APP"

if [[ "${1:-}" == "run" ]]; then
  echo "==> Relaunching"
  pkill -x NotchShelf 2>/dev/null || true
  sleep 0.5
  open "$APP"
fi
