#!/usr/bin/env bash
# =============================================================================
# env.sh - Nordic nRF Connect SDK toolchain environment setup
#
# Usage:
#   source scripts/env.sh          # Set up environment variables
#   source scripts/env.sh --check  # Verify environment
#
# This script adds the Nordic toolchain to PATH and sets ZEPHYR_BASE.
# Source this script before running west or any build commands.
# =============================================================================

set -e

# --- Configuration -----------------------------------------------------------
NCS_TOOLCHAIN_BASE="/opt/nordic/ncs/toolchains/e5f4758bcf"

# Detect script location and project root
if [[ -n "${BASH_SOURCE[0]}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [[ -n "${(%):-%x}" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
else
    SCRIPT_DIR="$(pwd)/scripts"
fi
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"

# --- Toolchain PATH ----------------------------------------------------------
TOOLCHAIN_PATHS=(
    "${NCS_TOOLCHAIN_BASE}/bin"
    "${NCS_TOOLCHAIN_BASE}/usr/bin"
    "${NCS_TOOLCHAIN_BASE}/usr/local/bin"
    "${NCS_TOOLCHAIN_BASE}/opt/bin"
    "${NCS_TOOLCHAIN_BASE}/opt/nanopb/generator-bin"
    "${NCS_TOOLCHAIN_BASE}/nrfutil/bin"
    "${NCS_TOOLCHAIN_BASE}/opt/zephyr-sdk/arm-zephyr-eabi/bin"
    "${NCS_TOOLCHAIN_BASE}/opt/zephyr-sdk/riscv64-zephyr-elf/bin"
)

# Build PATH string (prepend toolchain paths)
NEW_PATH=""
for p in "${TOOLCHAIN_PATHS[@]}"; do
    if [[ -d "$p" ]]; then
        NEW_PATH="${NEW_PATH:+${NEW_PATH}:}${p}"
    fi
done

# Only add paths that are not already in PATH
if [[ ":${PATH}:" != *":${NCS_TOOLCHAIN_BASE}/bin:"* ]]; then
    export PATH="${NEW_PATH}:${PATH}"
    echo "✓ Nordic toolchain added to PATH"
else
    echo "✓ Nordic toolchain already in PATH"
fi

# --- ZEPHYR_BASE --------------------------------------------------------------
if [[ -d "${WORKSPACE_ROOT}/external/zephyr" ]]; then
    export ZEPHYR_BASE="${WORKSPACE_ROOT}/external/zephyr"
    echo "✓ ZEPHYR_BASE=${ZEPHYR_BASE}"
else
    echo "⚠ Warning: external/zephyr not found at ${WORKSPACE_ROOT}/external/zephyr"
fi

# --- Verification (--check flag) ----------------------------------------------
if [[ "${1}" == "--check" ]]; then
    echo ""
    echo "=== Environment Check ==="
    echo "PROJECT_ROOT : ${PROJECT_ROOT}"
    echo "WORKSPACE_ROOT: ${WORKSPACE_ROOT}"
    echo "ZEPHYR_BASE  : ${ZEPHYR_BASE:-NOT SET}"
    echo ""

    TOOLS=("west" "cmake" "ninja" "dtc" "arm-zephyr-eabi-gcc")
    ALL_OK=true
    for tool in "${TOOLS[@]}"; do
        location=$(which "$tool" 2>/dev/null || echo "NOT FOUND")
        if [[ "$location" == "NOT FOUND" ]]; then
            echo "✗ ${tool}: NOT FOUND"
            ALL_OK=false
        else
            echo "✓ ${tool}: ${location}"
        fi
    done

    echo ""
    if $ALL_OK; then
        echo "=== All tools found. Environment is ready. ==="
    else
        echo "=== Some tools are missing. Check NCS_TOOLCHAIN_BASE path. ==="
    fi
fi

set +e
