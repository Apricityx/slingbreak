#!/usr/bin/env bash
# build-debug-install.sh - build and install the ABI-matched debug APK
#
# Usage:
#   ./script/build-debug-install.sh [DEVICE_SERIAL]
#   ./script/build-debug-install.sh --device DEVICE_SERIAL
#
# Environment:
#   SLINGBREAK_DEVICE  default ADB serial (empty: discover one authorized device)
#   ADB_BIN            adb executable path
#   GRADLE_BIN         Gradle wrapper path

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ANDROID_DIR="$PROJECT_DIR/android"
GRADLE_BIN="${GRADLE_BIN:-$ANDROID_DIR/gradlew}"
ADB_BIN="${ADB_BIN:-adb}"
DEVICE_SERIAL="${SLINGBREAK_DEVICE-10.126.126.1:5555}"
device_specified=false

usage() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
    printf '\nThe installer builds :app:assembleDebug, selects the device ABI split, and runs adb install -r.\n'
}

while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --device)
            if [[ "$#" -lt 2 || -z "$2" || "$2" == -* ]]; then
                printf -- '--device requires an ADB serial.\n' >&2
                exit 2
            fi
            if [[ "$device_specified" == true ]]; then
                printf 'Expected at most one device serial.\n' >&2
                exit 2
            fi
            DEVICE_SERIAL="$2"
            device_specified=true
            shift 2
            ;;
        --device=*)
            if [[ "$device_specified" == true ]]; then
                printf 'Expected at most one device serial.\n' >&2
                exit 2
            fi
            DEVICE_SERIAL="${1#*=}"
            if [[ -z "$DEVICE_SERIAL" ]]; then
                printf -- '--device requires an ADB serial.\n' >&2
                exit 2
            fi
            device_specified=true
            shift
            ;;
        --)
            shift
            if [[ "$#" -gt 1 || ( "$#" -eq 1 && "$device_specified" == true ) ]]; then
                printf 'Expected at most one device serial.\n' >&2
                exit 2
            fi
            if [[ "$#" -eq 1 ]]; then
                DEVICE_SERIAL="$1"
                shift
            fi
            ;;
        -*)
            printf 'Unknown option: %s\n\n' "$1" >&2
            usage >&2
            exit 2
            ;;
        *)
            if [[ "$#" -gt 1 || "$device_specified" == true ]]; then
                printf 'Expected at most one device serial.\n' >&2
                exit 2
            fi
            DEVICE_SERIAL="$1"
            device_specified=true
            shift
            ;;
    esac
done

if [[ ! -x "$GRADLE_BIN" ]]; then
    printf 'Gradle wrapper is not executable: %s\n' "$GRADLE_BIN" >&2
    printf 'Run: chmod +x %q\n' "$GRADLE_BIN" >&2
    exit 1
fi

if ! command -v "$ADB_BIN" >/dev/null 2>&1; then
    printf 'adb was not found. Set ADB_BIN to its full path if needed.\n' >&2
    exit 1
fi

if [[ -z "$DEVICE_SERIAL" ]]; then
    connected_devices=()
    while IFS= read -r device; do
        connected_devices+=("$device")
    done < <("$ADB_BIN" devices | awk 'NR > 1 && $2 == "device" { print $1 }')
    if [[ "${#connected_devices[@]}" -ne 1 ]]; then
        printf 'Expected exactly one authorized adb device, found %s.\n' "${#connected_devices[@]}" >&2
        "$ADB_BIN" devices >&2
        printf 'Usage: %s <device-serial>\n' "$0" >&2
        exit 1
    fi
    DEVICE_SERIAL="${connected_devices[0]}"
fi

if ! "$ADB_BIN" -s "$DEVICE_SERIAL" get-state 2>/dev/null | grep -qx 'device'; then
    printf 'ADB device is not ready: %s\n' "$DEVICE_SERIAL" >&2
    "$ADB_BIN" devices >&2
    exit 1
fi

printf 'Building debug APK...\n'
(
    cd "$ANDROID_DIR"
    "$GRADLE_BIN" :app:assembleDebug
)

APK_DIR="$ANDROID_DIR/app/build/outputs/apk/debug"
mapfile -t apk_files < <(find "$APK_DIR" -maxdepth 1 -type f -name '*.apk' -print | sort)
if [[ "${#apk_files[@]}" -eq 0 ]]; then
    printf 'No debug APK found in %s\n' "$APK_DIR" >&2
    exit 1
fi

device_abis="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell getprop ro.product.cpu.abilist | tr -d '\r')"
if [[ -z "$device_abis" ]]; then
    device_abis="$("$ADB_BIN" -s "$DEVICE_SERIAL" shell getprop ro.product.cpu.abi | tr -d '\r')"
fi
APK_PATH=""
while IFS= read -r abi; do
    [[ -z "$abi" ]] && continue
    candidate="$APK_DIR/app-${abi}-debug.apk"
    if [[ -f "$candidate" ]]; then
        APK_PATH="$candidate"
        break
    fi
done < <(printf '%s\n' "$device_abis" | tr ',' '\n')

if [[ -z "$APK_PATH" && -f "$APK_DIR/app-universal-debug.apk" ]]; then
    APK_PATH="$APK_DIR/app-universal-debug.apk"
fi

if [[ -z "$APK_PATH" ]]; then
    printf 'No debug APK matches device ABI(s): %s\n' "$device_abis" >&2
    printf 'Available APKs:\n' >&2
    printf '  %s\n' "${apk_files[@]}" >&2
    exit 1
fi

printf 'Installing %s on %s...\n' "$APK_PATH" "$DEVICE_SERIAL"
"$ADB_BIN" -s "$DEVICE_SERIAL" install -r "$APK_PATH"
printf 'Debug APK installed successfully on %s.\n' "$DEVICE_SERIAL"
