#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PROJECT="$ROOT/Poch1441.xcodeproj"
DEVICE_ID="${1:-${POCH_QA_SE_UDID:-}}"

if [[ -z "$DEVICE_ID" ]]; then
    DEVICE_COUNT="$(xcrun simctl list devices available -j | jq '[.devices[][] | select(.isAvailable == true and .name == "iPhone SE (3rd generation)")] | length')"
    if [[ "$DEVICE_COUNT" != "1" ]]; then
        echo "FAIL: genau ein verfügbares 'iPhone SE (3rd generation)'-Ziel erwartet, gefunden: $DEVICE_COUNT" >&2
        echo "Aufruf mit expliziter UDID: $0 <SE-UDID>" >&2
        exit 2
    fi
    DEVICE_ID="$(xcrun simctl list devices available -j | jq -r '.devices[][] | select(.isAvailable == true and .name == "iPhone SE (3rd generation)") | .udid')"
fi

DEVICE_NAME="$(xcrun simctl list devices available -j | jq -r --arg id "$DEVICE_ID" '.devices[][] | select(.udid == $id) | .name' | head -n 1)"
if [[ "$DEVICE_NAME" != "iPhone SE (3rd generation)" ]]; then
    echo "FAIL: $DEVICE_ID ist kein verfügbares iPhone SE (3rd generation), sondern '${DEVICE_NAME:-unbekannt}'." >&2
    exit 2
fi

if [[ ! -d "$PROJECT" ]]; then
    echo "FAIL: Projekt fehlt: $PROJECT" >&2
    exit 2
fi

MIN_FREE_KB=524288
AVAILABLE_KB="$(df -Pk "$ROOT" | awk 'NR == 2 { print $4 }')"
if [[ ! "$AVAILABLE_KB" =~ ^[0-9]+$ ]] || (( AVAILABLE_KB < MIN_FREE_KB )); then
    echo "FAIL: mindestens 512 MiB freier Speicher für den isolierten UI-Test erforderlich; verfügbar: ${AVAILABLE_KB:-unbekannt} KiB." >&2
    exit 73
fi

DEVICE_STATE="$(xcrun simctl list devices available -j | jq -r --arg id "$DEVICE_ID" '.devices[][] | select(.udid == $id) | .state' | head -n 1)"
if [[ "$DEVICE_STATE" != "Booted" ]]; then
    xcrun simctl boot "$DEVICE_ID"
fi
xcrun simctl bootstatus "$DEVICE_ID" -b

STAMP="$(date +%Y%m%d-%H%M%S)-$$"
RESULT_ROOT="${POCH_QA_RESULT_ROOT:-$ROOT/artifacts/qa/ax-xxxl-landscape-$STAMP}"
RESULT_BUNDLE="$RESULT_ROOT/TestResults.xcresult"
ATTACHMENTS="$RESULT_ROOT/attachments"
DERIVED_DATA="$(mktemp -d "${TMPDIR:-/tmp}/poch1441-ax-xxxl-landscape.XXXXXX")"
cleanup() {
    if [[ -d "$DERIVED_DATA" ]]; then
        find "$DERIVED_DATA" -depth -delete
    fi
}
trap cleanup EXIT
mkdir -p "$RESULT_ROOT"

echo "AX-XXXL-Landscape-Gate"
echo "Gerät: $DEVICE_NAME ($DEVICE_ID)"
echo "Result-Bundle: $RESULT_BUNDLE"
echo "DerivedData: $DERIVED_DATA"

TEST_LOG="$RESULT_ROOT/xcodebuild.log"
SCREENSHOT="$RESULT_ROOT/first-run-learning-xxxl-landscape.png"
RAW_SCREENSHOT="$RESULT_ROOT/first-run-learning-xxxl-landscape-raw.png"
(
    set -o pipefail
    xcodebuild \
        -project "$PROJECT" \
        -scheme Poch1441 \
        -destination "platform=iOS Simulator,id=$DEVICE_ID" \
        -derivedDataPath "$DERIVED_DATA" \
        -resultBundlePath "$RESULT_BUNDLE" \
        test \
        -only-testing:Poch1441UITests/FirstRunUITests/testLearningFlowStaysZonedAtAccessibilityXXXLInLandscape \
        CODE_SIGNING_ALLOWED=NO 2>&1 | tee "$TEST_LOG"
) &
XCODEBUILD_PID=$!

CAPTURED=0
for _ in {1..2400}; do
    if rg -q "first-run-learning-xxxl-landscape-capture-ready" "$TEST_LOG" 2>/dev/null; then
        xcrun simctl io "$DEVICE_ID" screenshot --type=png "$RAW_SCREENSHOT" >/dev/null
        CAPTURED=1
        break
    fi
    if ! kill -0 "$XCODEBUILD_PID" 2>/dev/null; then
        break
    fi
    sleep 0.1
done

set +e
wait "$XCODEBUILD_PID"
XCODEBUILD_STATUS=$?
set -e
if (( XCODEBUILD_STATUS != 0 )); then
    exit "$XCODEBUILD_STATUS"
fi
if (( CAPTURED != 1 )); then
    echo "FAIL: Capture-Fenster des laufenden Landscape-Tests wurde nicht erreicht." >&2
    exit 1
fi

raw_width="$(sips -g pixelWidth "$RAW_SCREENSHOT" | awk '/pixelWidth/ { print $2 }')"
raw_height="$(sips -g pixelHeight "$RAW_SCREENSHOT" | awk '/pixelHeight/ { print $2 }')"
if (( raw_width < raw_height )); then
    sips --rotate 270 "$RAW_SCREENSHOT" --out "$SCREENSHOT" >/dev/null
else
    cp "$RAW_SCREENSHOT" "$SCREENSHOT"
fi

mkdir -p "$ATTACHMENTS"
xcrun xcresulttool export attachments \
    --path "$RESULT_BUNDLE" \
    --output-path "$ATTACHMENTS"

jq -e '
    [.[].attachments[]]
    | ([.[] | select(.suggestedHumanReadableName | startswith("first-run-learning-xxxl-landscape-initial-frames_"))] | length == 1)
      and
      ([.[] | select(.suggestedHumanReadableName | startswith("first-run-learning-xxxl-landscape-bottom-frames_"))] | length == 1)
' "$ATTACHMENTS/manifest.json" >/dev/null

width="$(sips -g pixelWidth "$SCREENSHOT" | awk '/pixelWidth/ { print $2 }')"
height="$(sips -g pixelHeight "$SCREENSHOT" | awk '/pixelHeight/ { print $2 }')"
if [[ ! "$width" =~ ^[0-9]+$ ]] || [[ ! "$height" =~ ^[0-9]+$ ]]; then
    echo "FAIL: Simulator-Framebuffer nicht lesbar: $SCREENSHOT" >&2
    exit 1
fi
if (( width <= height )); then
    echo "FAIL: Simulator-Framebuffer ist ${width}x${height} px und damit kein Landscape-Beleg." >&2
    exit 1
fi
if (( width * 100 < height * 170 || width * 100 > height * 190 )); then
    echo "FAIL: Simulator-Framebuffer hat mit ${width}x${height} px nicht den erwarteten SE-Landscape-Aspekt." >&2
    exit 1
fi

echo "PASS: AX-XXXL-Landscape-Gate mit initialem Gesamtframe, Bottom-Reveal und direktem Landscape-Simulatorframe."
echo "Belege: $RESULT_ROOT"
