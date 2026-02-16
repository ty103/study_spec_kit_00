#!/usr/bin/env bash
# =============================================================================
# test.sh — Run ztest unit tests via Twister (native_sim)
#
# Usage:
#   ./scripts/test.sh              # Run all unit tests
#   ./scripts/test.sh --verbose    # Verbose output
#   ./scripts/test.sh --filter "led_toggle_edge"  # Filter by suite name
#
# This script is designed to run inside Docker (Linux) or WSL.
# On macOS, use: docker compose run --rm test
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"

# --- Parse arguments ---------------------------------------------------------
VERBOSE=""
EXTRA_ARGS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            VERBOSE="-v"
            shift
            ;;
        *)
            EXTRA_ARGS="${EXTRA_ARGS} $1"
            shift
            ;;
    esac
done

# --- Environment setup -------------------------------------------------------
export ZEPHYR_BASE="${ZEPHYR_BASE:-${WORKSPACE_ROOT}/external/zephyr}"

if [[ ! -d "${ZEPHYR_BASE}" ]]; then
    echo "ERROR: ZEPHYR_BASE not found at ${ZEPHYR_BASE}" >&2
    exit 1
fi

# Install Zephyr Python dependencies if needed
if ! python3 -c "import elftools" 2>/dev/null || ! python3 -c "import ply" 2>/dev/null; then
    echo "Installing Zephyr Python dependencies..."
    pip3 install --quiet -r "${ZEPHYR_BASE}/scripts/requirements-base.txt" 2>/dev/null || \
    pip3 install --quiet ply pyyaml pykwalify packaging colorama pyelftools 2>/dev/null || true
fi

# --- Run tests ---------------------------------------------------------------
echo "============================================="
echo " Running unit tests (native_sim + ztest)"
echo " ZEPHYR_BASE: ${ZEPHYR_BASE}"
echo "============================================="

cd "${PROJECT_ROOT}"

# Clean previous results
rm -rf twister-out twister-out.*

west twister \
    -T tests/unit \
    -p native_sim \
    ${VERBOSE} \
    ${EXTRA_ARGS} \
    2>&1

EXIT_CODE=$?

echo ""
echo "============================================="
if [[ ${EXIT_CODE} -eq 0 ]]; then
    echo " ✅ All tests PASSED"
else
    echo " ❌ Tests FAILED (exit code: ${EXIT_CODE})"
    echo ""
    echo " See detailed logs:"
    echo "   twister-out/native_sim/app.led_toggle_button.unit/handler.log"
fi
echo "============================================="

exit ${EXIT_CODE}
