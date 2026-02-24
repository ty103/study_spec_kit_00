#!/usr/bin/env bash
# =============================================================================
# memory-report.sh — メモリ使用量レポート生成・閾値チェック
#
# 用途:
#   ./scripts/memory-report.sh              # レポート生成（コンソール出力）
#   ./scripts/memory-report.sh --markdown   # Markdown ファイルに出力
#   ./scripts/memory-report.sh --json       # JSON サマリを標準出力
#   ./scripts/memory-report.sh --ci         # CI モード（閾値超過で exit 1）
#
# 前提:
#   - ビルド済みであること（west build 完了後に実行）
#   - source scripts/env.sh 済み（west コマンドが使える状態）
#
# 出力:
#   - コンソール: 色付きのメモリ使用量サマリ
#   - --markdown: specs/<feature>/memory-report.md を生成
#   - --json: 構造化データを stdout に出力
#
# 閾値（constitution.md VI. メモリバジェット管理に基づく）:
#   - RAM:   256KB の 80% = 204KB (208,896 bytes)
#   - Flash: 1MB  の 80% = 819KB (838,860 bytes)
# =============================================================================

set -euo pipefail

# --- 定数 -------------------------------------------------------------------
RAM_TOTAL_KB=256
FLASH_TOTAL_KB=1024
RAM_THRESHOLD_PERCENT=80
FLASH_THRESHOLD_PERCENT=80

RAM_TOTAL_BYTES=$((RAM_TOTAL_KB * 1024))
FLASH_TOTAL_BYTES=$((FLASH_TOTAL_KB * 1024))
RAM_THRESHOLD_BYTES=$((RAM_TOTAL_BYTES * RAM_THRESHOLD_PERCENT / 100))
FLASH_THRESHOLD_BYTES=$((FLASH_TOTAL_BYTES * FLASH_THRESHOLD_PERCENT / 100))

# --- パス解決 ----------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORKSPACE_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"

BUILD_DIR="${PROJECT_ROOT}/build/study_spec_kit_00"
ROM_JSON="${BUILD_DIR}/rom.json"
RAM_JSON="${BUILD_DIR}/ram.json"

# --- 引数解析 ----------------------------------------------------------------
OUTPUT_MODE="console"  # console | markdown | json | ci

while [[ $# -gt 0 ]]; do
    case $1 in
        --markdown|-m)
            OUTPUT_MODE="markdown"
            shift
            ;;
        --json|-j)
            OUTPUT_MODE="json"
            shift
            ;;
        --ci)
            OUTPUT_MODE="ci"
            shift
            ;;
        --build-dir)
            BUILD_DIR="$2"
            ROM_JSON="${BUILD_DIR}/rom.json"
            RAM_JSON="${BUILD_DIR}/ram.json"
            shift 2
            ;;
        --help|-h)
            echo "使用方法: $0 [--markdown|--json|--ci] [--build-dir <path>]"
            echo ""
            echo "オプション:"
            echo "  --markdown, -m   Markdown ファイルに出力"
            echo "  --json, -j       JSON サマリを stdout に出力"
            echo "  --ci             CI モード（閾値超過で exit 1）"
            echo "  --build-dir      ビルドディレクトリを指定"
            echo "  --help, -h       このヘルプを表示"
            exit 0
            ;;
        *)
            echo "不明なオプション: $1" >&2
            exit 1
            ;;
    esac
done

# --- レポート生成 ------------------------------------------------------------
echo "メモリレポートを生成中..." >&2

cd "${WORKSPACE_ROOT}"

# rom_report / ram_report を実行（JSON 自動生成）
# 既存 JSON があっても常に最新のビルドからレポートを再生成する
echo "  west build -t rom_report ..." >&2
west build -t rom_report --build-dir "${BUILD_DIR}" > /dev/null 2>&1
echo "  west build -t ram_report ..." >&2
west build -t ram_report --build-dir "${BUILD_DIR}" > /dev/null 2>&1

# JSON ファイル存在確認
if [[ ! -f "${ROM_JSON}" ]]; then
    echo "エラー: ${ROM_JSON} が見つかりません。ビルドを先に実行してください。" >&2
    exit 1
fi
if [[ ! -f "${RAM_JSON}" ]]; then
    echo "エラー: ${RAM_JSON} が見つかりません。ビルドを先に実行してください。" >&2
    exit 1
fi

# --- JSON パース（Python ワンライナー）---------------------------------------
REPORT_DATA="$(python3 -c "
import json, sys, os

rom_path = '${ROM_JSON}'
ram_path = '${RAM_JSON}'

rom = json.load(open(rom_path))
ram = json.load(open(ram_path))

rom_bytes = rom['total_size']
ram_bytes = ram['total_size']

def top_children(data, n=5):
    children = data.get('symbols', {}).get('children', [])
    sorted_c = sorted(children, key=lambda c: c.get('size', 0), reverse=True)
    return '|'.join(f\"{c['name']}:{c.get('size',0)}\" for c in sorted_c[:n])

rom_top = top_children(rom)
ram_top = top_children(ram)

print(f'{rom_bytes}')
print(f'{ram_bytes}')
print(rom_top)
print(ram_top)
")"

ROM_BYTES="$(echo "${REPORT_DATA}" | sed -n '1p')"
RAM_BYTES="$(echo "${REPORT_DATA}" | sed -n '2p')"
ROM_TOP="$(echo "${REPORT_DATA}" | sed -n '3p')"
RAM_TOP="$(echo "${REPORT_DATA}" | sed -n '4p')"

# --- 計算 --------------------------------------------------------------------
ROM_PERCENT=$((ROM_BYTES * 100 / FLASH_TOTAL_BYTES))
RAM_PERCENT=$((RAM_BYTES * 100 / RAM_TOTAL_BYTES))

ROM_THRESHOLD_PASS="true"
RAM_THRESHOLD_PASS="true"
[[ ${ROM_BYTES} -gt ${FLASH_THRESHOLD_BYTES} ]] && ROM_THRESHOLD_PASS="false"
[[ ${RAM_BYTES} -gt ${RAM_THRESHOLD_BYTES} ]] && RAM_THRESHOLD_PASS="false"

ROM_KB="$(echo "scale=2; ${ROM_BYTES} / 1024" | bc)"
RAM_KB="$(echo "scale=2; ${RAM_BYTES} / 1024" | bc)"
ROM_THRESHOLD_KB="$(echo "scale=0; ${FLASH_THRESHOLD_BYTES} / 1024" | bc)"
RAM_THRESHOLD_KB="$(echo "scale=0; ${RAM_THRESHOLD_BYTES} / 1024" | bc)"

# --- 出力 --------------------------------------------------------------------
REPORT_DATE="$(date '+%Y-%m-%d %H:%M:%S')"

case "${OUTPUT_MODE}" in
    console)
        echo ""
        echo "============================================="
        echo " メモリ使用量レポート"
        echo " 日時: ${REPORT_DATE}"
        echo "============================================="
        echo ""
        echo "┌──────────┬───────────┬─────────┬──────────┬──────────┐"
        echo "│ 区分     │ 使用量    │ 全容量  │ 使用率   │ 閾値判定 │"
        echo "├──────────┼───────────┼─────────┼──────────┼──────────┤"
        if [[ "${ROM_THRESHOLD_PASS}" == "true" ]]; then
            printf "│ Flash    │ %7s KB│ %4d KB │ %5s%%   │ ✅ PASS  │\n" "${ROM_KB}" "${FLASH_TOTAL_KB}" "${ROM_PERCENT}"
        else
            printf "│ Flash    │ %7s KB│ %4d KB │ %5s%%   │ ❌ FAIL  │\n" "${ROM_KB}" "${FLASH_TOTAL_KB}" "${ROM_PERCENT}"
        fi
        if [[ "${RAM_THRESHOLD_PASS}" == "true" ]]; then
            printf "│ RAM      │ %7s KB│ %4d KB │ %5s%%   │ ✅ PASS  │\n" "${RAM_KB}" "${RAM_TOTAL_KB}" "${RAM_PERCENT}"
        else
            printf "│ RAM      │ %7s KB│ %4d KB │ %5s%%   │ ❌ FAIL  │\n" "${RAM_KB}" "${RAM_TOTAL_KB}" "${RAM_PERCENT}"
        fi
        echo "└──────────┴───────────┴─────────┴──────────┴──────────┘"
        echo ""
        echo "閾値: Flash < ${ROM_THRESHOLD_KB} KB (${FLASH_THRESHOLD_PERCENT}%), RAM < ${RAM_THRESHOLD_KB} KB (${RAM_THRESHOLD_PERCENT}%)"
        echo ""
        echo "--- Flash 内訳（上位モジュール）---"
        echo "${ROM_TOP}" | tr '|' '\n' | while IFS=: read -r name size; do
            size_kb="$(echo "scale=2; ${size} / 1024" | bc)"
            printf "  %-20s %8s bytes (%s KB)\n" "${name}" "${size}" "${size_kb}"
        done
        echo ""
        echo "--- RAM 内訳（上位モジュール）---"
        echo "${RAM_TOP}" | tr '|' '\n' | while IFS=: read -r name size; do
            size_kb="$(echo "scale=2; ${size} / 1024" | bc)"
            printf "  %-20s %8s bytes (%s KB)\n" "${name}" "${size}" "${size_kb}"
        done
        echo ""

        if [[ "${ROM_THRESHOLD_PASS}" == "false" ]] || [[ "${RAM_THRESHOLD_PASS}" == "false" ]]; then
            echo "⚠️  閾値超過を検出しました。Complexity Tracking テーブルに正当化を記録してください。"
            exit 1
        else
            echo "✅ メモリ使用量は閾値内です。"
        fi
        ;;

    markdown)
        MARKDOWN_DIR="${PROJECT_ROOT}/specs/001-led-toggle-button"
        MARKDOWN_FILE="${MARKDOWN_DIR}/memory-report.md"

        if [[ "${ROM_THRESHOLD_PASS}" == "true" ]]; then
            ROM_STATUS="✅ PASS"
        else
            ROM_STATUS="❌ FAIL"
        fi
        if [[ "${RAM_THRESHOLD_PASS}" == "true" ]]; then
            RAM_STATUS="✅ PASS"
        else
            RAM_STATUS="❌ FAIL"
        fi

        cat > "${MARKDOWN_FILE}" << MDEOF
# メモリ使用量レポート

**生成日時**: ${REPORT_DATE}
**ビルドディレクトリ**: \`${BUILD_DIR}\`
**ターゲット**: nRF52840DK (PCA10056)
**根拠**: constitution.md VI. メモリバジェット管理

## サマリ

| 区分 | 使用量 | 全容量 | 使用率 | 閾値 (${FLASH_THRESHOLD_PERCENT}%) | 判定 |
|------|--------|--------|--------|--------|------|
| Flash (ROM) | ${ROM_KB} KB (${ROM_BYTES} bytes) | ${FLASH_TOTAL_KB} KB | ${ROM_PERCENT}% | ${ROM_THRESHOLD_KB} KB | ${ROM_STATUS} |
| RAM | ${RAM_KB} KB (${RAM_BYTES} bytes) | ${RAM_TOTAL_KB} KB | ${RAM_PERCENT}% | ${RAM_THRESHOLD_KB} KB | ${RAM_STATUS} |

## Flash 内訳（上位モジュール）

| モジュール | サイズ (bytes) | サイズ (KB) |
|-----------|---------------|-------------|
MDEOF
        echo "${ROM_TOP}" | tr '|' '\n' | while IFS=: read -r name size; do
            size_kb="$(echo "scale=2; ${size} / 1024" | bc)"
            echo "| ${name} | ${size} | ${size_kb} KB |" >> "${MARKDOWN_FILE}"
        done

        cat >> "${MARKDOWN_FILE}" << MDEOF

## RAM 内訳（上位モジュール）

| モジュール | サイズ (bytes) | サイズ (KB) |
|-----------|---------------|-------------|
MDEOF
        echo "${RAM_TOP}" | tr '|' '\n' | while IFS=: read -r name size; do
            size_kb="$(echo "scale=2; ${size} / 1024" | bc)"
            echo "| ${name} | ${size} | ${size_kb} KB |" >> "${MARKDOWN_FILE}"
        done

        cat >> "${MARKDOWN_FILE}" << MDEOF

## 閾値ポリシー

- **Flash**: ${FLASH_TOTAL_KB} KB の ${FLASH_THRESHOLD_PERCENT}%（${ROM_THRESHOLD_KB} KB）を超過した場合、Complexity Tracking テーブルに正当化を記録する（MUST）
- **RAM**: ${RAM_TOTAL_KB} KB の ${RAM_THRESHOLD_PERCENT}%（${RAM_THRESHOLD_KB} KB）を超過した場合、Complexity Tracking テーブルに正当化を記録する（MUST）
- 根拠: \`.specify/memory/constitution.md\` — 原則 VI. メモリバジェット管理
MDEOF

        echo "✅ Markdown レポートを生成しました: ${MARKDOWN_FILE}" >&2
        ;;

    json)
        ROM_PASS_PY="True"
        RAM_PASS_PY="True"
        [[ "${ROM_THRESHOLD_PASS}" == "false" ]] && ROM_PASS_PY="False"
        [[ "${RAM_THRESHOLD_PASS}" == "false" ]] && RAM_PASS_PY="False"

        python3 -c "
import json

data = {
    'report_date': '${REPORT_DATE}',
    'target': 'nRF52840DK',
    'flash': {
        'used_bytes': ${ROM_BYTES},
        'total_bytes': ${FLASH_TOTAL_BYTES},
        'used_percent': ${ROM_PERCENT},
        'threshold_percent': ${FLASH_THRESHOLD_PERCENT},
        'threshold_bytes': ${FLASH_THRESHOLD_BYTES},
        'pass': ${ROM_PASS_PY}
    },
    'ram': {
        'used_bytes': ${RAM_BYTES},
        'total_bytes': ${RAM_TOTAL_BYTES},
        'used_percent': ${RAM_PERCENT},
        'threshold_percent': ${RAM_THRESHOLD_PERCENT},
        'threshold_bytes': ${RAM_THRESHOLD_BYTES},
        'pass': ${RAM_PASS_PY}
    },
    'overall_pass': ${ROM_PASS_PY} and ${RAM_PASS_PY}
}
print(json.dumps(data, indent=2))
"
        ;;

    ci)
        echo "=============================================" >&2
        echo " メモリバジェットチェック（CI モード）" >&2
        echo "=============================================" >&2
        echo "" >&2
        echo "  Flash: ${ROM_KB} KB / ${FLASH_TOTAL_KB} KB (${ROM_PERCENT}%) — 閾値 ${ROM_THRESHOLD_KB} KB" >&2
        echo "  RAM:   ${RAM_KB} KB / ${RAM_TOTAL_KB} KB (${RAM_PERCENT}%) — 閾値 ${RAM_THRESHOLD_KB} KB" >&2
        echo "" >&2

        EXIT_CODE=0
        if [[ "${ROM_THRESHOLD_PASS}" == "false" ]]; then
            echo "❌ Flash 閾値超過: ${ROM_KB} KB > ${ROM_THRESHOLD_KB} KB" >&2
            EXIT_CODE=1
        fi
        if [[ "${RAM_THRESHOLD_PASS}" == "false" ]]; then
            echo "❌ RAM 閾値超過: ${RAM_KB} KB > ${RAM_THRESHOLD_KB} KB" >&2
            EXIT_CODE=1
        fi

        if [[ ${EXIT_CODE} -eq 0 ]]; then
            echo "✅ メモリバジェット: PASS" >&2
        fi

        exit ${EXIT_CODE}
        ;;
esac
