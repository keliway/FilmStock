#!/usr/bin/env bash
#
# run_e2e_tests.sh
# End-to-End Automated Test Runner for Analog FilmStock
#
# Usage:
#   bash run_e2e_tests.sh              # Run all Unit/Integration + End-to-End UI tests
#   bash run_e2e_tests.sh --unit       # Run only Swift Testing Unit & Integration tests
#   bash run_e2e_tests.sh --ui         # Run only XCUITest End-to-End UI tests
#   bash run_e2e_tests.sh --dest "platform=iOS Simulator,name=iPhone 18 Pro"
#

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT="${REPO_ROOT}/Analog FilmStock.xcodeproj"
SCHEME="FilmStock"
DESTINATION="${DESTINATION:-}"
MODE="all"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --unit)
            MODE="unit"
            shift
            ;;
        --ui)
            MODE="ui"
            shift
            ;;
        --all)
            MODE="all"
            shift
            ;;
        --dest|--destination)
            DESTINATION="$2"
            shift 2
            ;;
        -h|--help)
            sed -n '2,10p' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Auto-detect an available iPhone Simulator if DESTINATION was not explicitly supplied
if [[ -z "${DESTINATION}" ]]; then
    BOOTED_UDID="$(xcrun simctl list devices booted | grep -Eo '[0-9A-F-]{36}' | head -n 1 || true)"
    if [[ -n "${BOOTED_UDID}" ]]; then
        DESTINATION="platform=iOS Simulator,id=${BOOTED_UDID}"
    else
        FIRST_IPHONE_UDID="$(xcrun simctl list devices available | grep 'iPhone' | grep -Eo '[0-9A-F-]{36}' | head -n 1 || true)"
        if [[ -n "${FIRST_IPHONE_UDID}" ]]; then
            DESTINATION="platform=iOS Simulator,id=${FIRST_IPHONE_UDID}"
        else
            DESTINATION="platform=iOS Simulator,name=iPhone 18 Pro"
        fi
    fi
fi

echo "========================================================"
echo " Analog FilmStock — End-to-End Test Runner"
echo " Project:     ${PROJECT}"
echo " Scheme:      ${SCHEME}"
echo " Destination: ${DESTINATION}"
echo " Mode:        ${MODE}"
echo "========================================================"

TEST_FILTER_ARGS=()
if [[ "${MODE}" == "unit" ]]; then
    TEST_FILTER_ARGS=(-only-testing:FilmStockTests)
elif [[ "${MODE}" == "ui" ]]; then
    TEST_FILTER_ARGS=(-only-testing:FilmStockUITests)
fi

xcodebuild test \
    -project "${PROJECT}" \
    -scheme "${SCHEME}" \
    -destination "${DESTINATION}" \
    -parallel-testing-enabled NO \
    "${TEST_FILTER_ARGS[@]}"

echo "✅ All requested FilmStock tests completed successfully."
