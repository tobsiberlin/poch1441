#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
HARNESS_DIR=${SCRIPT_DIR:h}
PROJECT_ROOT=${HARNESS_DIR:h:h:h}
V3_DIR=${HARNESS_DIR:h}/card-deal-rhythm-wallclock-v3
SOURCE_CONTRACT="$PROJECT_ROOT/tasks/reviews/card-deal-rhythm-contract-v1/DealRhythmContract.swift"
COMPILED_CONTRACT="$HARNESS_DIR/Sources/DealRhythmContract.swift"
VIDEO_INSPECTOR_PATH=/tmp/poch1441-card-deal-rhythm-v4-video-inspector
SIMULATOR_UDID=""
BUNDLE_ID="com.tobc.reviews.card-deal-rhythm-wallclock-v4"
cd "$HARNESS_DIR"

cleanup() {
  if [[ -n "$SIMULATOR_UDID" ]]; then
    xcrun simctl terminate "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
  fi
  rm -f "$VIDEO_INSPECTOR_PATH"
  rm -rf "$HARNESS_DIR/.derived"
}
trap cleanup EXIT

if ! cmp -s "$SOURCE_CONTRACT" "$COMPILED_CONTRACT"; then
  print -u2 "V1-Vertragskopie ist nicht byte-identisch. Harness gestoppt."
  exit 2
fi

for relative in \
  Sources/DealRhythmContract.swift \
  Sources/RhythmHarnessModel.swift \
  Sources/RhythmHarnessStage.swift \
  Sources/W2CardBody.swift \
  Scripts/verify_evidence.py \
  Scripts/VideoInspector.swift \
  Scripts/make_encoded_review_strips.py; do
  if ! cmp -s "$V3_DIR/$relative" "$HARNESS_DIR/$relative"; then
    print -u2 "V3-Freeze verletzt: $relative"
    exit 2
  fi
done

if [[ -n "${RHYTHM_SIMULATOR_UDID:-}" ]]; then
  SIMULATOR_UDID="$RHYTHM_SIMULATOR_UDID"
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

xcodebuild \
  -project CardDealRhythmWallclockV4.xcodeproj \
  -scheme CardDealRhythmWallclockV4 \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -derivedDataPath .derived \
  -quiet \
  test

APP_PATH="$HARNESS_DIR/.derived/Build/Products/Debug-iphonesimulator/CardDealRhythmWallclockV4.app"
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" --export-evidence

DATA_CONTAINER=$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)
for _ in {1..720}; do
  if [[ -f "$DATA_CONTAINER/Documents/CardDealRhythmEvidenceV4/export.complete" ]]; then
    break
  fi
  sleep 0.25
done

if [[ ! -f "$DATA_CONTAINER/Documents/CardDealRhythmEvidenceV4/export.complete" ]]; then
  print -u2 "Echter 60-fps-Wallclock-Export wurde nicht fertig."
  exit 4
fi

mkdir -p Evidence
find Evidence -type f -depth -delete
cp "$DATA_CONTAINER/Documents/CardDealRhythmEvidenceV4/"* Evidence/
xcrun swiftc \
  -warnings-as-errors \
  -parse-as-library \
  -framework AVFoundation \
  -framework CoreMedia \
  Scripts/VideoInspector.swift \
  -o "$VIDEO_INSPECTOR_PATH"
VIDEO_INSPECTOR="$VIDEO_INSPECTOR_PATH" python3 Scripts/verify_v4_evidence.py
python3 Scripts/make_encoded_review_strips.py

jq '{viewport, syntheticProgressUsed, productAudioIncluded, materialApprovalClaimed, sequences: [.sequences[] | {sequence, frames: (.frames | length), maximumActiveCards, maximumActiveCardsAtPeel, invisibleWaitSeconds, videoFile}]}' Evidence/manifest.json
jq '{result, sequences: [.sequences[] | {sequence, decodedOrientation, winningMargin, uprightMAE: .scores.upright.meanAbsoluteError}]}' Evidence/orientation-verification.json
for video in Evidence/*-uncut-60fps.mp4; do
  "$VIDEO_INSPECTOR_PATH" "$video"
done

shasum -a 256 Evidence/* > Evidence/SHA256SUMS
