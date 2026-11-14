#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
PROOF_DIR=${SCRIPT_DIR:h}
cd "$PROOF_DIR"

MODE=${1:-static}
if [[ "$MODE" != "static" && "$MODE" != "full" ]]; then
  print -u2 "Nutzung: ./Scripts/run.sh [static|full]"
  exit 2
fi

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

if [[ "${MATERIAL_LOCK_SKIP_BUILD:-0}" != "1" ]]; then
  xcodebuild \
    -project CardMotionMaterialLockV4.xcodeproj \
    -scheme CardMotionMaterialLockV4 \
    -sdk iphonesimulator \
    -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
    -derivedDataPath .derived \
    -quiet \
    test
fi

APP_PATH="$PROOF_DIR/.derived/Build/Products/Debug-iphonesimulator/CardMotionMaterialLockV4.app"
BUNDLE_ID="com.tobc.reviews.card-motion-material-lock-v4"
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"

if [[ "$MODE" == "static" ]]; then
  EXPORT_ARGUMENT="--export-static-evidence"
  CONTAINER_DIRECTORY="CardMaterialLockStaticEvidenceV4"
else
  EXPORT_ARGUMENT="--export-evidence"
  CONTAINER_DIRECTORY="CardMaterialLockEvidenceV4"
fi
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" "$EXPORT_ARGUMENT"

DATA_CONTAINER=$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)
for _ in {1..240}; do
  if [[ -f "$DATA_CONTAINER/Documents/$CONTAINER_DIRECTORY/export.complete" ]]; then
    break
  fi
  sleep 0.25
done

if [[ ! -f "$DATA_CONTAINER/Documents/$CONTAINER_DIRECTORY/export.complete" ]]; then
  print -u2 "$MODE-Evidence-Export wurde nicht fertig."
  exit 3
fi

if [[ "$MODE" == "static" ]]; then
  mkdir -p Evidence/Static
  find Evidence/Static -type f -depth -delete
  cp "$DATA_CONTAINER/Documents/$CONTAINER_DIRECTORY/"* Evidence/Static/
  jq . Evidence/Static/static-manifest.json
  sips -g pixelWidth -g pixelHeight \
    Evidence/Static/402x874-static-source-v4.png \
    Evidence/Static/402x874-static-rest-v4.png \
    Evidence/Static/static-source-rest-pair-v4-402x874.png
else
  mkdir -p Evidence
  find Evidence -maxdepth 1 -type f -delete
  cp "$DATA_CONTAINER/Documents/$CONTAINER_DIRECTORY/"* Evidence/
  jq '{syntheticProgressUsed, captureFramesPerSecond, fixedStepSeconds, homographyCalibrationRMSPixels, stableRestCornerDeviationPixels, targetRegion, frozenContractReferences, frozenContractSHA256, frozenW2ContractSHA256, productMaterial, targetCardShortEdgePixels, diagnosticGraphicsVisible, firstContactFrameIndex, stableRestFrameCount, frameCount: (.frames | length)}' Evidence/manifest.json
  sips -g pixelWidth -g pixelHeight \
    Evidence/402x874-material-lock-v4-000.png \
    Evidence/uncut-material-lock-v4-sequence-402x874.png \
    Evidence/tight-first-edge-contact-v4-strip-402x874.png
  ls -lh Evidence/wallclock-material-lock-v4-402x874.mp4
fi
