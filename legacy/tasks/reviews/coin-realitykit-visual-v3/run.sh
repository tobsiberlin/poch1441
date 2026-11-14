#!/bin/zsh
set -euo pipefail

ROOT_DIR="${0:A:h}"
UDID="${1:-D1923D48-6E8D-4157-B703-8B05CC334D08}"
DERIVED="/private/tmp/coin-realitykit-visual-v3-derived"
BUNDLE="com.tobc.reviews.coin-realitykit-visual-v3"

cd "$ROOT_DIR"
xcodegen generate --spec project.yml
xcodebuild -project CoinRealityKitVisualV3.xcodeproj -scheme CoinRealityKitVisualV3 -sdk iphonesimulator -destination "platform=iOS Simulator,id=$UDID" -derivedDataPath "$DERIVED" build
xcrun simctl uninstall "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install "$UDID" "$DERIVED/Build/Products/Debug-iphonesimulator/CoinRealityKitVisualV3.app"
xcrun simctl launch "$UDID" "$BUNDLE"

CONTAINER="$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)"
for _ in {1..180}; do
  if [[ -f "$CONTAINER/Documents/coin-realitykit-visual-v3/DONE" ]]; then
    break
  fi
  sleep 1
done

if [[ ! -f "$CONTAINER/Documents/coin-realitykit-visual-v3/DONE" ]]; then
  print -u2 "Runner timeout: no DONE marker"
  exit 2
fi

mkdir -p "$ROOT_DIR/artifacts"
rsync -a --delete "$CONTAINER/Documents/coin-realitykit-visual-v3/" "$ROOT_DIR/artifacts/"
python3 "$ROOT_DIR/tools/make_contact_sheets.py" "$ROOT_DIR/artifacts"
print "$ROOT_DIR/artifacts/runtime-result.json"
