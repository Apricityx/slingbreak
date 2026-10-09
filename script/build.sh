#!/usr/bin/env bash
# build.sh - Slingbreak Android build entrypoint
#
# Usage:
#   ./script/build.sh [debug|release|test|lint|check]
#
# Environment:
#   GRADLE_BIN  Gradle wrapper path (default: ./android/gradlew)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ANDROID_DIR="$PROJECT_DIR/android"
GRADLE_BIN="${GRADLE_BIN:-$ANDROID_DIR/gradlew}"

usage() {
    sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
}

command="${1:-debug}"
if [[ "$#" -gt 0 ]]; then shift; fi

case "$command" in
    help|-h|--help)
        usage
        printf '\nCommands: debug, release, test, lint, check\n'
        printf 'Use script/build-debug-install.sh to build and install the ABI-matched debug APK.\n'
        exit 0
        ;;
    debug|release|test|lint|check) ;;
    *)
        printf 'Unknown build command: %s\n\n' "$command" >&2
        usage >&2
        exit 2
        ;;
esac

if [[ ! -x "$GRADLE_BIN" ]]; then
    printf 'Gradle wrapper is not executable: %s\n' "$GRADLE_BIN" >&2
    printf 'Run: chmod +x %q\n' "$GRADLE_BIN" >&2
    exit 1
fi

case "$command" in
    debug)
        (cd "$ANDROID_DIR" && "$GRADLE_BIN" :app:assembleDebug "$@")
        ;;
    release)
        (cd "$ANDROID_DIR" && "$GRADLE_BIN" :app:distributeRelease "$@")
        ;;
    test)
        (cd "$ANDROID_DIR" && "$GRADLE_BIN" :app:testReleaseUnitTest "$@")
        ;;
    lint)
        (cd "$ANDROID_DIR" && "$GRADLE_BIN" :app:lintRelease "$@")
        ;;
    check)
        (cd "$ANDROID_DIR" && "$GRADLE_BIN" :app:testReleaseUnitTest :app:lintRelease :app:assembleReleaseAndroidTest "$@")
        ;;
esac
