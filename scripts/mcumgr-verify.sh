#!/usr/bin/env bash
# =============================================================================
# mcumgr-verify.sh — MCUmgrアップロード確認手順の自動化
#
# Usage:
#   ./scripts/mcumgr-verify.sh
#   ./scripts/mcumgr-verify.sh --dev /dev/tty.usbmodemXXXX
#   ./scripts/mcumgr-verify.sh --image build/study_spec_kit_00/zephyr/zephyr.signed.bin
#   ./scripts/mcumgr-verify.sh --skip-test-reset
#
# このスクリプトは以下を実行する:
#  1) mcumgr接続設定
#  2) image list 取得（アップロード前）
#  3) image upload 実行
#  4) image list 再取得（アップロード後）
#  5) 可能なら image test + reset 実行（--skip-test-resetで省略）
#
# 引数なし実行時の既定値:
#  - 接続名: nrf52
#  - シリアル: Button 4 押下後に /dev/tty.usbmodem* を自動選択（最新列挙を優先）
#  - 通信設定: baud=115200, mtu=512
#  - イメージ: 以下の順で存在する最初のbinを使用
#      1) build/study_spec_kit_00/zephyr/zephyr.signed.bin
#      2) build/zephyr/app_update.bin
#      3) build/study_spec_kit_00/zephyr/zephyr.bin
#
# 引数なし実行時に「書き込まれる」もの:
#  - mcumgr conn add により、接続プロファイル nrf52 を作成/更新
#  - mcumgr image upload により、イメージをslot1へ書き込み
#  - （条件成立時）mcumgr image test + reset により、次回起動対象の設定/再起動を実施
#    ※ slot0/slot1 hashが同一の場合は test/reset を自動スキップ
#
# 注意:
#  - アップロード前にデバイスをFW更新待ちモード（LED4高速点滅）へ遷移してください。
#  - macOS前提で /dev/tty.usbmodem* を自動探索します。
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

CONN_NAME="nrf52"
DEVICE_PATH=""
BAUD="115200"
MTU="512"
IMAGE_PATH=""
SKIP_TEST_RESET="false"
AUTO_YES="false"
AUTO_DETECT_DEVICE="true"

usage() {
    cat <<'EOF'
Usage:
  ./scripts/mcumgr-verify.sh [options]

Options:
  --conn <name>         接続名 (default: nrf52)
  --dev <path>          シリアルデバイスパス (default: 自動探索)
  --baud <rate>         ボーレート (default: 115200)
  --mtu <size>          MTU (default: 512)
  --image <path>        アップロード対象bin (default: 自動探索)
  --skip-test-reset     image test/reset を実行しない
  -y, --yes             対話確認をスキップ
  -h, --help            このヘルプを表示
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --conn)
            CONN_NAME="$2"
            shift 2
            ;;
        --dev)
            DEVICE_PATH="$2"
            AUTO_DETECT_DEVICE="false"
            shift 2
            ;;
        --baud)
            BAUD="$2"
            shift 2
            ;;
        --mtu)
            MTU="$2"
            shift 2
            ;;
        --image)
            IMAGE_PATH="$2"
            shift 2
            ;;
        --skip-test-reset)
            SKIP_TEST_RESET="true"
            shift
            ;;
        -y|--yes)
            AUTO_YES="true"
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "ERROR: 未知のオプション: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# go install で導入した mcumgr を見つけられるよう GOPATH/bin を PATH に追加
if command -v go >/dev/null 2>&1; then
    GO_BIN_DIR="$(go env GOPATH 2>/dev/null)/bin"
    if [[ -n "${GO_BIN_DIR}" && -d "${GO_BIN_DIR}" && ":${PATH}:" != *":${GO_BIN_DIR}:"* ]]; then
        export PATH="${PATH}:${GO_BIN_DIR}"
    fi
fi

if ! command -v mcumgr >/dev/null 2>&1; then
    echo "ERROR: mcumgr が見つかりません。PATHを確認してください。" >&2
    exit 1
fi

detect_device_path() {
    local candidates=()

    while IFS= read -r dev; do
        candidates+=("$dev")
    done < <(ls -1t /dev/tty.usbmodem* 2>/dev/null || true)

    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "ERROR: /dev/tty.usbmodem* が見つかりません。--dev で指定してください。" >&2
        exit 1
    fi

    DEVICE_PATH="${candidates[0]}"

    if [[ ${#candidates[@]} -gt 1 ]]; then
        echo "INFO: 複数の候補を検出したため、最新列挙デバイスを選択します: ${DEVICE_PATH}"
    fi
}

if [[ -z "${IMAGE_PATH}" ]]; then
    IMAGE_CANDIDATES=(
        "${PROJECT_ROOT}/build/study_spec_kit_00/zephyr/zephyr.signed.bin"
        "${PROJECT_ROOT}/build/zephyr/app_update.bin"
        "${PROJECT_ROOT}/build/study_spec_kit_00/zephyr/zephyr.bin"
    )

    for candidate in "${IMAGE_CANDIDATES[@]}"; do
        if [[ -f "${candidate}" ]]; then
            IMAGE_PATH="${candidate}"
            break
        fi
    done
fi

if [[ -z "${IMAGE_PATH}" || ! -f "${IMAGE_PATH}" ]]; then
    echo "ERROR: アップロード対象イメージが見つかりません。--image で指定してください。" >&2
    echo "候補例:" >&2
    echo "  build/study_spec_kit_00/zephyr/zephyr.signed.bin" >&2
    echo "  build/zephyr/app_update.bin" >&2
    exit 1
fi

echo "============================================="
echo " MCUmgr Upload Verification"
echo "---------------------------------------------"
echo " conn : ${CONN_NAME}"
if [[ "${AUTO_DETECT_DEVICE}" == "true" ]]; then
    echo " dev  : (Button 4 押下後に自動検出)"
else
    echo " dev  : ${DEVICE_PATH}"
fi
echo " baud : ${BAUD}"
echo " mtu  : ${MTU}"
echo " image: ${IMAGE_PATH}"
echo "============================================="

if [[ "${AUTO_YES}" != "true" ]]; then
    echo ""
    echo "デバイスで Button 4 を押し、LED4が高速点滅（FW更新待ち）であることを確認してください。"
    read -r -p "準備できたら Enter を押してください... " _
fi

if [[ "${AUTO_DETECT_DEVICE}" == "true" ]]; then
    detect_device_path
    echo "選択されたデバイス: ${DEVICE_PATH}"
fi

echo "[1/5] 接続設定を更新します..."
mcumgr conn del "${CONN_NAME}" >/dev/null 2>&1 || true
mcumgr conn add "${CONN_NAME}" type="serial" connstring="dev=${DEVICE_PATH},baud=${BAUD},mtu=${MTU}" >/dev/null

before_file="$(mktemp)"
after_file="$(mktemp)"
trap 'rm -f "${before_file}" "${after_file}"' EXIT

echo "[2/5] アップロード前の image list を取得します..."
mcumgr -c "${CONN_NAME}" image list | tee "${before_file}"

echo "[3/5] イメージをアップロードします..."
mcumgr -c "${CONN_NAME}" image upload "${IMAGE_PATH}"

echo "[4/5] アップロード後の image list を取得します..."
mcumgr -c "${CONN_NAME}" image list | tee "${after_file}"

if [[ "${SKIP_TEST_RESET}" == "true" ]]; then
    echo "[5/5] --skip-test-reset 指定のため image test/reset は省略しました。"
    echo "完了: アップロード確認まで実施済みです。"
    exit 0
fi

slot0_hash="$(awk '
    /slot=0/ { in_slot0=1; in_slot1=0; next }
    /slot=1/ { in_slot1=1; in_slot0=0; next }
    in_slot0 && /^[[:space:]]*hash:[[:space:]]/ { print $2; exit }
' "${after_file}")"

slot1_hash="$(awk '
    /slot=1/ { in_slot1=1; next }
    in_slot1 && /^[[:space:]]*hash:[[:space:]]/ { print $2; exit }
' "${after_file}")"

candidate_hash="${slot1_hash}"

if [[ -z "${candidate_hash}" ]]; then
    echo "WARNING: slot1 hash を抽出できませんでした。image test/reset はスキップします。"
    echo "アップロード確認は完了しています。"
    exit 0
fi

if [[ -n "${slot0_hash}" && "${slot0_hash}" == "${slot1_hash}" ]]; then
    echo "INFO: slot0 と slot1 の hash が同一です。"
    echo "      同一イメージのため image test/reset はスキップします。"
    echo "      （新しいバイナリをビルドして再実行すると test/reset まで確認できます）"
    exit 0
fi

echo "[5/5] image test + reset を実行します..."
echo "  test hash: ${candidate_hash}"
mcumgr -c "${CONN_NAME}" image test "${candidate_hash}"
mcumgr -c "${CONN_NAME}" reset

echo ""
echo "完了: アップロード〜test〜reset を実行しました。"
echo "再起動後、必要に応じて以下で確認してください:"
echo "  mcumgr -c ${CONN_NAME} image list"
