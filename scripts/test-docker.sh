#!/usr/bin/env bash
# =============================================================================
# test-docker.sh — macOS 用テスト実行スクリプト
#
# ■ このスクリプトが行うこと
#   Docker コンテナ（Linux 環境）を起動し、その中で test.sh を実行します。
#   native_sim（PC 上でのシミュレーション実行）は Linux 専用のため、
#   macOS では Docker 経由でテストを実行する必要があります。
#
# ■ 使い方
#   ./scripts/test-docker.sh                              # すべてのテストを実行
#   ./scripts/test-docker.sh --verbose                     # 詳細な出力を表示
#   ./scripts/test-docker.sh --filter "led_toggle_edge"    # 特定のテストだけ実行
#   ./scripts/test-docker.sh --shell                       # コンテナ内でシェルを起動
#
# ■ 前提条件
#   - Docker Desktop がインストールされ、起動していること
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# --- Docker が利用可能か確認 --------------------------------------------------
if ! command -v docker &>/dev/null; then
    echo "ERROR: docker コマンドが見つかりません。" >&2
    echo "Docker Desktop をインストールしてください: https://www.docker.com/products/docker-desktop/" >&2
    exit 1
fi

if ! docker info &>/dev/null; then
    echo "ERROR: Docker デーモンが起動していません。" >&2
    echo "Docker Desktop を起動してください。" >&2
    exit 1
fi

# --- 引数の解析 ---------------------------------------------------------------
SHELL_MODE=false
EXTRA_ARGS=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --shell)
            SHELL_MODE=true
            shift
            ;;
        *)
            EXTRA_ARGS="${EXTRA_ARGS} $1"
            shift
            ;;
    esac
done

# --- テストの実行 -------------------------------------------------------------
cd "${PROJECT_ROOT}"

if [[ "${SHELL_MODE}" == "true" ]]; then
    echo "Docker コンテナ内のシェルを起動します..."
    echo "（終了するには exit と入力してください）"
    docker compose run --rm test bash
else
    echo "============================================="
    echo " Docker 経由でユニットテストを実行します"
    echo "============================================="

    # docker compose run でテスト実行
    #   --rm : コンテナ終了後に自動的に削除する
    #   test : docker-compose.yml で定義されたサービス名
    #
    # 追加引数がない場合:
    #   docker compose run --rm test
    #   → docker-compose.yml の CMD（= scripts/test.sh）がそのまま実行される
    #
    # 追加引数がある場合:
    #   docker compose run --rm test scripts/test.sh --verbose
    #   → CMD を上書きして、引数付きで test.sh を実行する
    if [[ -z "${EXTRA_ARGS}" ]]; then
        docker compose run --rm test
    else
        docker compose run --rm test scripts/test.sh ${EXTRA_ARGS}
    fi
fi
