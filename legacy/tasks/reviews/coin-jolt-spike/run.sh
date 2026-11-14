#!/usr/bin/env bash
set -euo pipefail

readonly script_dir="$(cd "$(dirname "$0")" && pwd)"
readonly source_file="$script_dir/Sources/main.cpp"
readonly expected_tag="v5.6.0"
readonly expected_commit="e77f175595e64cb44218cc9d9d56fc365ad0e36a"
readonly expected_license_sha="800abe35d64ad9defd636ff1ee8c961e06f0ebca3ef8d10083e8aa0e8ef86ac3"

if [[ "${1:-}" == "--compile-one" ]]; then
    readonly platform="$2"
    readonly index="$3"
    readonly cpp_file="$4"
    readonly object_file="$SPIKE_BUILD_DIR/objects/$index.o"
    common_flags=(
        -std=c++17 -O3 -DNDEBUG -DJPH_CROSS_PLATFORM_DETERMINISTIC
        -ffp-model=precise -ffp-contract=off -fno-rtti -fno-exceptions
        -fvisibility=hidden -I"$SPIKE_JOLT_ROOT"
    )
    if [[ "$platform" == "ios" ]]; then
        xcrun --sdk iphoneos clang++ "${common_flags[@]}" \
            -target arm64-apple-ios17.0 -isysroot "$SPIKE_IOS_SDK" \
            -c "$cpp_file" -o "$object_file"
    else
        clang++ "${common_flags[@]}" -arch arm64 -c "$cpp_file" -o "$object_file"
    fi
    exit 0
fi

readonly temporary_root="$(mktemp -d /private/tmp/poch-jolt-spike-XXXXXX)"
cleanup() {
    rm -rf "$temporary_root"
}
trap cleanup EXIT INT TERM

readonly upstream_root="$temporary_root/JoltPhysics"
git clone --quiet --depth 1 --branch "$expected_tag" \
    https://github.com/jrouwe/JoltPhysics.git "$upstream_root"

actual_commit="$(git -C "$upstream_root" rev-parse HEAD)"
actual_tag="$(git -C "$upstream_root" describe --tags --exact-match)"
actual_license_sha="$(shasum -a 256 "$upstream_root/LICENSE" | awk '{print $1}')"
[[ "$actual_commit" == "$expected_commit" ]]
[[ "$actual_tag" == "$expected_tag" ]]
[[ "$actual_license_sha" == "$expected_license_sha" ]]

export SPIKE_JOLT_ROOT="$upstream_root"
export SPIKE_IOS_SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
export SPIKE_SCRIPT="$script_dir/run.sh"
readonly parallelism="$(sysctl -n hw.logicalcpu)"

compile_jolt() {
    local platform="$1"
    local build_dir="$temporary_root/build-$platform"
    mkdir -p "$build_dir/objects"
    export SPIKE_BUILD_DIR="$build_dir"

    find "$upstream_root/Jolt" -name '*.cpp' -type f | LC_ALL=C sort \
        | awk '{print NR, $0}' \
        | xargs -P "$parallelism" -n 2 bash -c \
            '"$SPIKE_SCRIPT" --compile-one "$0" "$1" "$2"' "$platform"

    xcrun ar rcs "$build_dir/libJolt.a" "$build_dir"/objects/*.o
    printf '%s\n' "$build_dir"
}

printf 'Pinned %s at %s\n' "$actual_tag" "$actual_commit" \
    | tee "$script_dir/build-macos.log"
printf 'LICENSE SHA-256 %s\n' "$actual_license_sha" \
    | tee -a "$script_dir/build-macos.log"

mac_build="$(compile_jolt macos)"
clang++ -std=c++17 -O3 -DNDEBUG -DJPH_CROSS_PLATFORM_DETERMINISTIC \
    -ffp-model=precise -ffp-contract=off -fno-rtti -fno-exceptions \
    -fvisibility=hidden -arch arm64 -I"$upstream_root" \
    "$source_file" "$mac_build/libJolt.a" \
    -o "$mac_build/coin-jolt-spike" 2>&1 | tee -a "$script_dir/build-macos.log"

set +e
"$mac_build/coin-jolt-spike" "$script_dir/runtime-result.json" \
    2>&1 | tee -a "$script_dir/build-macos.log"
runtime_status=${PIPESTATUS[0]}
set -e

ios_build="$(compile_jolt ios)"
set +e
xcrun --sdk iphoneos clang++ -std=c++17 -O3 -DNDEBUG \
    -DJPH_CROSS_PLATFORM_DETERMINISTIC -ffp-model=precise -ffp-contract=off \
    -fno-rtti -fno-exceptions -fvisibility=hidden \
    -target arm64-apple-ios17.0 -isysroot "$SPIKE_IOS_SDK" \
    -I"$upstream_root" "$source_file" "$ios_build/libJolt.a" \
    -Wl,-dead_strip -o "$ios_build/coin-jolt-spike-ios" \
    >"$script_dir/build-ios.log" 2>&1
ios_status=$?
set -e

if [[ $ios_status -eq 0 ]]; then
    {
        printf 'IOS_COMPILE_LINK=GREEN\n'
        file "$ios_build/coin-jolt-spike-ios"
        xcrun vtool -show-build "$ios_build/coin-jolt-spike-ios"
    } >>"$script_dir/build-ios.log" 2>&1
else
    printf 'IOS_COMPILE_LINK=RED\n' >>"$script_dir/build-ios.log"
fi

{
    printf 'tag=%s\n' "$actual_tag"
    printf 'commit=%s\n' "$actual_commit"
    printf 'license=MIT\n'
    printf 'license_sha256=%s\n' "$actual_license_sha"
    printf 'compiler=%s\n' "$(clang++ --version | head -1)"
    printf 'macos_runtime_status=%s\n' "$runtime_status"
    printf 'ios_compile_link_status=%s\n' "$ios_status"
    printf 'temporary_build_removed_on_exit=true\n'
} >"$script_dir/build-metadata.txt"

exit "$runtime_status"
