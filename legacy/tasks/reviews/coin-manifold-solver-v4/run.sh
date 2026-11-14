#!/usr/bin/env bash
set -euo pipefail

readonly script_dir="$(cd "$(dirname "$0")" && pwd)"
readonly scratch="$(mktemp -d /private/tmp/poch-manifold-v4-XXXXXX)"
cleanup() {
    rm -rf "$scratch"
}
trap cleanup EXIT INT TERM

cd "$script_dir"
swift test -c release --scratch-path "$scratch" 2>&1 | tee test.log

set +e
swift run -c release --scratch-path "$scratch" --skip-build \
    CoinManifoldSpike "$script_dir/runtime-result.json" 2>&1 | tee runtime.log
readonly runtime_status=${PIPESTATUS[0]}
set -e
printf 'runtime_exit_status=%s\n' "$runtime_status" | tee -a runtime.log
exit "$runtime_status"
