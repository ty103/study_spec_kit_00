#!/usr/bin/env bash
# =============================================================================
# test-device.sh — 実機（nRF52840DK）でのユニットテスト実行スクリプト
#
# ■ このスクリプトが行うこと
#   nRF52840DK 実機にテストファームウェアを書き込み、ztest を実行します。
#   native_sim のシミュレーションとは異なり、実際のハードウェア上でテストが動きます。
#
#   テスト結果は UART（シリアル通信）経由で PC に送られ、
#   Twister がそれを受信して合格/不合格を判定します。
#
# ■ 使い方
#   ./scripts/test-device.sh                          # デフォルト設定で実行
#   ./scripts/test-device.sh --serial /dev/ttyACM1    # シリアルポートを指定
#   ./scripts/test-device.sh --verbose                 # 詳細な出力を表示
#
# ■ 前提条件
#   - nRF52840DK が USB で接続されていること
#   - J-Link ドライバがインストールされていること
#   - source scripts/env.sh を実行済みであること（ツールチェーン設定）
#
# ■ 注意事項
#   - テスト書き込み中は、通常のアプリケーションが上書きされます。
#     テスト後にアプリを戻すには再度 west build + west flash が必要です。
#   - テスト用 prj.conf（tests/unit/prj.conf）はアプリ用 prj.conf と
#     異なるため、Kconfig に依存する動作差異が生じる可能性があります。
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"

# --- 引数の解析 ---------------------------------------------------------------
SERIAL_PORT=""
VERBOSE=""
EXTRA_ARGS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --serial|-s)
            SERIAL_PORT="$2"
            shift 2
            ;;
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

# --- 環境チェック -------------------------------------------------------------
export ZEPHYR_BASE="${ZEPHYR_BASE:-${WORKSPACE_ROOT}/external/zephyr}"

if [[ ! -d "${ZEPHYR_BASE}" ]]; then
    echo "ERROR: ZEPHYR_BASE が見つかりません: ${ZEPHYR_BASE}" >&2
    echo "先に source scripts/env.sh を実行してください。" >&2
    exit 1
fi

# west コマンドの確認
if ! command -v west &>/dev/null; then
    echo "ERROR: west コマンドが見つかりません。" >&2
    echo "先に source scripts/env.sh を実行してください。" >&2
    exit 1
fi

# --- シリアルポートの自動検出 --------------------------------------------------
if [[ -z "${SERIAL_PORT}" ]]; then
    # macOS と Linux で自動検出を試みる
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS: /dev/tty.usbmodemXXXX を探す
        SERIAL_PORT=$(ls /dev/tty.usbmodem* 2>/dev/null | head -1 || true)
    else
        # Linux: /dev/ttyACM0 を探す
        SERIAL_PORT=$(ls /dev/ttyACM* 2>/dev/null | head -1 || true)
    fi

    if [[ -z "${SERIAL_PORT}" ]]; then
        echo "ERROR: シリアルポートが見つかりません。" >&2
        echo "nRF52840DK が USB で接続されていることを確認してください。" >&2
        echo "手動で指定する場合: ./scripts/test-device.sh --serial /dev/ttyACM0" >&2
        exit 1
    fi

    echo "シリアルポートを自動検出: ${SERIAL_PORT}"
fi

# --- テストの実行 -------------------------------------------------------------
echo "============================================="
echo " 実機テスト実行 (nRF52840DK + ztest)"
echo " ZEPHYR_BASE: ${ZEPHYR_BASE}"
echo " シリアルポート: ${SERIAL_PORT}"
echo "============================================="
echo ""
echo "⚠️  テストファームウェアが書き込まれます。"
echo "   終了後にアプリを戻すには再ビルド＋書き込みが必要です。"
echo ""

# ワークスペースルートからの相対パスを計算
PROJECT_REL_PATH="${PROJECT_ROOT#${WORKSPACE_ROOT}/}"

# West コマンドのためワークスペースルートに移動
cd "${WORKSPACE_ROOT}"

# 前回のテスト結果を削除
rm -rf "${PROJECT_REL_PATH}"/twister-out*

west twister \
    -T "${PROJECT_REL_PATH}/tests/unit" \
    -p nrf52840dk/nrf52840 \
    -O "${PROJECT_REL_PATH}/twister-out" \
    --device-testing \
    --device-serial "${SERIAL_PORT}" \
    ${VERBOSE} \
    ${EXTRA_ARGS} \
    2>&1

EXIT_CODE=$?

echo ""
echo "============================================="
if [[ ${EXIT_CODE} -eq 0 ]]; then
    echo " ✅ 実機テスト PASSED"
else
    echo " ❌ 実機テスト FAILED (exit code: ${EXIT_CODE})"
    echo ""
    echo " 詳細ログ:"
    echo "   twister-out/nrf52840dk_nrf52840/app.led_toggle_button.unit/handler.log"
fi
echo "============================================="

exit ${EXIT_CODE}
