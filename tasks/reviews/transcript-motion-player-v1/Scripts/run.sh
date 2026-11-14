#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
HARNESS_DIR=${SCRIPT_DIR:h}
PROJECT_ROOT=${HARNESS_DIR:h:h:h}
PRODUCT_CONTRACT="$PROJECT_ROOT/App/MotionPlaybackPlan.swift"
EXPECTED_CONTRACT_SHA="8f50b68ff3141ad45f7d9eb751913c9c40af99678c15570a52821413561f6f16"
VIDEO_INSPECTOR_SOURCE="$PROJECT_ROOT/tasks/reviews/card-deal-rhythm-wallclock-v4/Scripts/VideoInspector.swift"
VIDEO_INSPECTOR_PATH=/tmp/poch1441-transcript-player-video-inspector
DERIVED_PATH="$HARNESS_DIR/.derived"
TEST_RESULT_PATH="$HARNESS_DIR/.test-result.xcresult"
TEST_SUMMARY_PATH=/tmp/poch1441-transcript-player-test-summary.json
SIMULATOR_UDID=""
BUNDLE_ID="com.tobc.reviews.transcript-motion-player-v1"
cd "$HARNESS_DIR"

cleanup() {
  if [[ -n "$SIMULATOR_UDID" ]]; then
    xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
  fi
  rm -f "$VIDEO_INSPECTOR_PATH"
  rm -f "$TEST_SUMMARY_PATH"
  if [[ "$DERIVED_PATH" == "$HARNESS_DIR/.derived" && -d "$DERIVED_PATH" ]]; then
    find "$DERIVED_PATH" -depth -delete
  fi
  if [[ "$TEST_RESULT_PATH" == "$HARNESS_DIR/.test-result.xcresult" && -d "$TEST_RESULT_PATH" ]]; then
    find "$TEST_RESULT_PATH" -depth -delete
  fi
}
trap cleanup EXIT

ACTUAL_CONTRACT_SHA=$(shasum -a 256 "$PRODUCT_CONTRACT" | awk '{print $1}')
if [[ "$ACTUAL_CONTRACT_SHA" != "$EXPECTED_CONTRACT_SHA" ]]; then
  print -u2 "MotionPlaybackPlan.swift driftete. Harness fail-fast gestoppt."
  exit 2
fi

if [[ -e "$HARNESS_DIR/Sources/MotionPlaybackPlan.swift" ]]; then
  print -u2 "Eine lokale Vertragskopie ist verboten."
  exit 2
fi

PLAN_COUNT=$(rg -o 'MotionPlaybackPlan\(' Sources -g '*.swift' | wc -l | tr -d ' ')
if [[ "$PLAN_COUNT" != "1" ]]; then
  print -u2 "Harness muss genau einen MotionPlaybackPlan instanziieren."
  exit 2
fi

if ! rg -q '\.\./\.\./\.\./App/MotionPlaybackPlan\.swift' project.yml; then
  print -u2 "Direkte Build-Referenz auf den Produktvertrag fehlt."
  exit 2
fi

if [[ -n "${TRANSCRIPT_PLAYER_SIMULATOR_UDID:-}" ]]; then
  SIMULATOR_UDID="$TRANSCRIPT_PLAYER_SIMULATOR_UDID"
else
  SIMULATOR_UDID=$(xcrun simctl list devices available --json | \
    jq -r '[.devices[][] | select(.name == "iPhone 17 Pro")][0].udid')
fi

if [[ -z "$SIMULATOR_UDID" || "$SIMULATOR_UDID" == "null" ]]; then
  print -u2 "Kein verfügbarer iPhone-17-Pro-Simulator gefunden."
  exit 3
fi

xcodegen generate --spec project.yml
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b

if [[ -d "$TEST_RESULT_PATH" ]]; then
  find "$TEST_RESULT_PATH" -depth -delete
fi

xcodebuild \
  -project TranscriptMotionPlayerV1.xcodeproj \
  -scheme TranscriptMotionPlayerV1 \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -derivedDataPath "$DERIVED_PATH" \
  -resultBundlePath "$TEST_RESULT_PATH" \
  -collect-test-diagnostics never \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 30 \
  -quiet \
  test

xcrun xcresulttool get test-results summary \
  --path "$TEST_RESULT_PATH" > "$TEST_SUMMARY_PATH"

APP_PATH="$HARNESS_DIR/.derived/Build/Products/Debug-iphonesimulator/TranscriptMotionPlayerV1.app"
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" --export-evidence

DATA_CONTAINER=$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)
for _ in {1..720}; do
  if [[ -f "$DATA_CONTAINER/Documents/TranscriptMotionPlayerV1/export.complete" ]]; then
    break
  fi
  sleep 0.25
done

if [[ ! -f "$DATA_CONTAINER/Documents/TranscriptMotionPlayerV1/export.complete" ]]; then
  print -u2 "Wallclock-/Hz-Evidence wurde nicht fertig."
  exit 4
fi

mkdir -p Evidence
find Evidence -type f -depth -delete
cp "$DATA_CONTAINER/Documents/TranscriptMotionPlayerV1/"* Evidence/
jq \
  --arg contractSHA "$ACTUAL_CONTRACT_SHA" \
  --arg testsSHA "$(shasum -a 256 Tests/TranscriptMotionPlayerV1Tests.swift | awk '{print $1}')" \
  '{
    result,
    totalTestCount,
    passedTests,
    failedTests,
    skippedTests,
    productContractSHA256: $contractSHA,
    testSourceSHA256: $testsSHA,
    diagnosticsCollection: "never",
    perTestTimeoutSeconds: 30
  }' "$TEST_SUMMARY_PATH" > Evidence/test-verification.json

xcrun swiftc \
  -warnings-as-errors \
  -parse-as-library \
  -framework AVFoundation \
  -framework CoreMedia \
  "$VIDEO_INSPECTOR_SOURCE" \
  -o "$VIDEO_INSPECTOR_PATH"

python3 Scripts/verify_orientation.py
VIDEO_INSPECTOR="$VIDEO_INSPECTOR_PATH" python3 Scripts/verify_evidence.py
shasum -a 256 Evidence/* > Evidence/SHA256SUMS
jq '{status, standardWallclock, rateSegments, visualVerdict}' Evidence/verification.json
