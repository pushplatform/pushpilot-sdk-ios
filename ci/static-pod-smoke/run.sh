#!/usr/bin/env bash
set -euo pipefail
export LANG="${LANG:-en_US.UTF-8}"
export LC_ALL="${LC_ALL:-en_US.UTF-8}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi

rm -rf StaticPodSmoke.xcodeproj StaticPodSmoke.xcworkspace Pods Podfile.lock DerivedData
xcodegen generate
pod install --silent
xcodebuild \
  -workspace StaticPodSmoke.xcworkspace \
  -scheme StaticPodSmoke \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$ROOT/DerivedData" \
  CODE_SIGNING_ALLOWED=NO \
  build
echo "static CocoaPods smoke passed"
