#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROOF_DIR=${SCRIPT_DIR:h}
cd "$PROOF_DIR"

if [[ -n "${MATERIAL_LOCK_SIMULATOR_UDID:-}" ]]; then
  SIMULATOR_UDID="$MATERIAL_LOCK_SIMULATOR_UDID"
else
  SIMULATOR_UDID=$(xcrun simctl list devices available --json | \
    plutil -extract devices json -o - - | \
    jq -r '[to_entries[] | .value[] | select(.name == "iPhone 17 Pro")][0].udid')
fi

if [[ -z "$SIMULATOR_UDID" || "$SIMULATOR_UDID" == "null" ]]; then
  print -u2 "Kein verfügbarer iPhone-17-Pro-Simulator gefunden."
  exit 2
fi

xcodegen generate --spec project.yml
xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
xcrun simctl bootstatus "$SIMULATOR_UDID" -b

xcodebuild \
  -project CardMotionMaterialLockV2.xcodeproj \
  -scheme CardMotionMaterialLockV2 \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -derivedDataPath .derived \
  -quiet \
  test

APP_PATH="$PROOF_DIR/.derived/Build/Products/Debug-iphonesimulator/CardMotionMaterialLockV2.app"
BUNDLE_ID="com.tobc.reviews.card-motion-material-lock-v2"
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" --export-evidence

DATA_CONTAINER=$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)
for _ in {1..240}; do
  if [[ -f "$DATA_CONTAINER/Documents/CardMaterialLockEvidenceV2/export.complete" ]]; then
    break
  fi
  sleep 0.25
done

if [[ ! -f "$DATA_CONTAINER/Documents/CardMaterialLockEvidenceV2/export.complete" ]]; then
  print -u2 "Wallclock-Evidence-Export wurde nicht fertig."
  exit 3
fi

mkdir -p Evidence
find Evidence -type f -depth -delete
cp "$DATA_CONTAINER/Documents/CardMaterialLockEvidenceV2/"* Evidence/

jq '{syntheticProgressUsed, captureFramesPerSecond, fixedStepSeconds, homographyCalibrationRMSPixels, stableRestCornerDeviationPixels, targetRegion, productMaterial, targetCardShortEdgePixels, diagnosticGraphicsVisible, firstContactFrameIndex, stableRestFrameCount, frameCount: (.frames | length)}' Evidence/manifest.json
sips -g pixelWidth -g pixelHeight \
  Evidence/402x874-material-lock-000.png \
  Evidence/uncut-material-lock-sequence-402x874.png \
  Evidence/tight-first-edge-contact-strip-402x874.png
ls -lh Evidence/wallclock-material-lock-402x874.mp4
