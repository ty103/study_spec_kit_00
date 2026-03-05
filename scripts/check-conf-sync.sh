#!/usr/bin/env bash
# ──────────────────────────────────────────────
# check-conf-sync.sh — prj.conf [SYNC] セクション同期チェック
# ──────────────────────────────────────────────
#
# 目的:
#   プロジェクト直下の prj.conf にある [SYNC] セクションの設定が
#   tests/unit/boards/nrf52840dk_nrf52840.conf にも存在するかを検証する。
#   CI（GitHub Actions）や pre-commit フックで使用することを想定。
#
# 使い方:
#   ./scripts/check-conf-sync.sh          # チェックのみ
#   ./scripts/check-conf-sync.sh --fix    # 差分を自動修正
#
# 終了コード:
#   0 — 同期済み（差分なし）
#   1 — 同期ずれを検出
# ──────────────────────────────────────────────
set -euo pipefail

# ─── パス解決 ───
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

APP_CONF="${PROJECT_ROOT}/prj.conf"
TEST_BOARD_CONF="${PROJECT_ROOT}/tests/unit/boards/nrf52840dk_nrf52840.conf"

# ─── [SYNC] セクションの CONFIG_ 行を抽出する関数 ───
# prj.conf の [SYNC] マーカーから [NO-SYNC] マーカーまでのCONFIG行を取得
extract_sync_configs() {
    local file="$1"
    # [SYNC] セクションの開始から [NO-SYNC] セクションの開始までを取り出す
    sed -n '/\[SYNC\].*ロジック関連設定/,/\[NO-SYNC\]/p' "$file" \
        | grep '^CONFIG_' \
        | sort
}

# テストボード conf から CONFIG_ 行を抽出する関数
extract_test_configs() {
    local file="$1"
    grep '^CONFIG_' "$file" | sort
}

# ─── メイン処理 ───

# ファイル存在チェック
if [[ ! -f "$APP_CONF" ]]; then
    echo "❌ エラー: ${APP_CONF} が見つかりません"
    exit 1
fi

if [[ ! -f "$TEST_BOARD_CONF" ]]; then
    echo "❌ エラー: ${TEST_BOARD_CONF} が見つかりません"
    exit 1
fi

# 設定を一時ファイルに抽出
APP_SYNC=$(extract_sync_configs "$APP_CONF")
TEST_SYNC=$(extract_test_configs "$TEST_BOARD_CONF")

# ─── 比較 ───
if [[ "$APP_SYNC" == "$TEST_SYNC" ]]; then
    echo "✅ 同期OK: prj.conf [SYNC] セクションとテスト用ボード conf は一致しています"
    echo ""
    echo "同期対象の設定:"
    echo "$APP_SYNC" | sed 's/^/  /'
    exit 0
fi

# ─── 差分表示 ───
echo "⚠️  同期ずれを検出しました"
echo ""
echo "--- prj.conf [SYNC] セクション ---"
echo "$APP_SYNC"
echo ""
echo "--- tests/unit/boards/nrf52840dk_nrf52840.conf ---"
echo "$TEST_SYNC"
echo ""

# 差分の詳細
echo "差分:"
diff <(echo "$APP_SYNC") <(echo "$TEST_SYNC") || true
echo ""

# ─── --fix モード ───
if [[ "${1:-}" == "--fix" ]]; then
    echo "🔧 自動修正を実行します..."
    
    # ボード conf のヘッダー部分（コメント行）を保持
    HEADER=$(sed -n '1,/^CONFIG_/{ /^CONFIG_/!p; }' "$TEST_BOARD_CONF")
    
    # ヘッダー + 新しい CONFIG 行で上書き
    {
        echo "$HEADER"
        echo "$APP_SYNC"
    } > "$TEST_BOARD_CONF"
    
    echo "✅ ${TEST_BOARD_CONF} を更新しました"
    echo ""
    echo "更新後の内容:"
    cat "$TEST_BOARD_CONF"
    exit 0
fi

echo "💡 自動修正するには: ./scripts/check-conf-sync.sh --fix"
exit 1
