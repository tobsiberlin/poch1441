#!/bin/zsh
set -euo pipefail

SCRIPT_DIR=${0:A:h}
SPIKE_DIR=${SCRIPT_DIR:h}
cd "$SPIKE_DIR"

if [[ -n "${SPIKE_SIMULATOR_UDID:-}" ]]; then
  SIMULATOR_UDID="$SPIKE_SIMULATOR_UDID"
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
  -project CardMotionNativeSpike.xcodeproj \
  -scheme CardMotionNativeSpike \
  -sdk iphonesimulator \
  -destination "platform=iOS Simulator,id=$SIMULATOR_UDID" \
  -derivedDataPath .derived \
  -quiet \
  test

APP_PATH="$SPIKE_DIR/.derived/Build/Products/Debug-iphonesimulator/CardMotionNativeSpike.app"
BUNDLE_ID="com.tobc.reviews.card-motion-native-spike-v2"
xcrun simctl uninstall "$SIMULATOR_UDID" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_UDID" "$BUNDLE_ID" --export-evidence --run-probe

DATA_CONTAINER=$(xcrun simctl get_app_container "$SIMULATOR_UDID" "$BUNDLE_ID" data)
for _ in {1..160}; do
  if [[ -f "$DATA_CONTAINER/Documents/CardMotionEvidenceV2/export.complete" && \
        -f "$DATA_CONTAINER/Documents/realtime-probe.json" ]]; then
    break
  fi
  sleep 0.25
done

if [[ ! -f "$DATA_CONTAINER/Documents/CardMotionEvidenceV2/export.complete" || \
      ! -f "$DATA_CONTAINER/Documents/realtime-probe.json" ]]; then
  print -u2 "Evidence-Export oder Echtzeitprobe wurde nicht fertig."
  exit 3
fi

mkdir -p Evidence
cp "$DATA_CONTAINER/Documents/CardMotionEvidenceV2/"*.png Evidence/
cp "$DATA_CONTAINER/Documents/CardMotionEvidenceV2/manifest.json" Evidence/
cp "$DATA_CONTAINER/Documents/CardMotionEvidenceV2/realtime-contact-sheet.json" Evidence/
cp "$DATA_CONTAINER/Documents/realtime-probe.json" Evidence/

FIXED_COUNT=$(jq '.frames | length' Evidence/manifest.json)
print "Feste Segmentframes: $FIXED_COUNT"
sips -g pixelWidth -g pixelHeight \
  Evidence/390x844-deal-progress-000.png \
  Evidence/667x375-play-progress-100.png \
  Evidence/402x874-return-progress-100.png \
  Evidence/realtime-contact-sheet-402x874.png
jq . Evidence/realtime-contact-sheet.json
jq . Evidence/realtime-probe.json
