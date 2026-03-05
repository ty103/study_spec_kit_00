#!/usr/bin/env bash
# ↑ 「シバン（shebang）」と呼ばれる行。このスクリプトを bash（シェル）で実行することを指定している。
#   /usr/bin/env bash とすることで、環境に合った bash を自動的に見つけて使う。

# =============================================================================
# test.sh — ユニットテスト実行スクリプト
#
# ■ このスクリプトが行うこと（概要）
#   このスクリプトは、組み込みファームウェアの「ユニットテスト（単体テスト）」を
#   PC 上で実行するためのものです。
#
#   通常、組み込みソフトウェアは実際のハードウェア（マイコンボード）上で動かしますが、
#   テストのたびにボードに書き込むのは時間がかかります。そこで、PC 上でマイコンの
#   動作を模倣（シミュレーション）してテストを実行します。
#
# ■ 使われている主な技術用語
#
#   ● ztest（ゼットテスト）
#     Zephyr RTOS が提供するテストフレームワーク（テストを書くための仕組み）。
#     C 言語でテストケースを記述し、期待通りに関数が動くか確認できる。
#     一般的なプログラミングでいう JUnit (Java) や pytest (Python) に相当する。
#
#   ● Twister（ツイスター）
#     Zephyr RTOS が提供するテスト実行ツール（テストランナー）。
#     ztest で書いたテストを自動的にビルド（コンパイル）し、実行し、結果をまとめてくれる。
#     複数のテストスイートをまとめて実行でき、レポートも生成する。
#
#   ● native_sim（ネイティブシム）
#     Zephyr のシミュレーション用プラットフォーム。実際のマイコンボードではなく、
#     PC の CPU 上で Zephyr アプリケーションを直接実行できる仮想的なボード。
#     テストを高速に実行できるため、ユニットテストに最適。
#
#   ● Zephyr RTOS（ゼファー・アールティーオーエス）
#     組み込み機器向けのリアルタイムオペレーティングシステム（RTOS）。
#     マイコン上でタスクの管理やハードウェア制御を行うための基盤ソフトウェア。
#
#   ● West（ウェスト）
#     Zephyr プロジェクトの公式メタツール。ビルド、フラッシュ（書き込み）、
#     テスト実行など、Zephyr 開発に必要なコマンドを統合的に提供する。
#
#   ● Docker（ドッカー）
#     アプリケーションをコンテナ（隔離された実行環境）で動かすためのツール。
#     このスクリプトは Linux 環境を前提としているため、macOS や Windows では
#     Docker コンテナ内で実行する。
#
# ■ スクリプト全体の流れ
#   このスクリプトは、以下のステップを上から順に実行します。
#
#   ステップ 1: シェルの安全設定
#     → エラー発生時に即座に停止するなど、安全に動作するための設定を行う。
#
#   ステップ 2: ディレクトリパスの取得
#     → スクリプト自身の場所をもとに、プロジェクトやワークスペースの
#       ルートディレクトリの絶対パスを算出する。
#
#   ステップ 3: コマンドライン引数の解析
#     → --verbose や --filter などのオプションを読み取り、変数に格納する。
#
#   ステップ 4: 環境変数の設定（ZEPHYR_BASE）
#     → Zephyr RTOS のソースコードの場所を設定し、存在するか確認する。
#
#   ステップ 5: Git safe.directory の設定（Docker 環境用）
#     → Docker コンテナ内で Git がリポジトリにアクセスできるよう許可を設定する。
#
#   ステップ 6: Python 依存パッケージのインストール
#     → Twister が必要とする Python ライブラリが未インストールなら自動で入れる。
#
#   ステップ 7: テストの実行（west twister）
#     → 前回の結果を削除し、west twister コマンドでテストをビルド・実行する。
#       これがこのスクリプトの本題。
#
#   ステップ 8: テスト結果の表示
#     → 成功（✅）または失敗（❌）のメッセージを表示し、
#       テスト結果の終了コードをスクリプトの終了コードとして返す。
#
# ■ 使い方
#   ./scripts/test.sh                               # すべてのユニットテストを実行
#   ./scripts/test.sh --verbose                      # 詳細な出力を表示して実行
#   ./scripts/test.sh --filter "led_toggle_edge"     # 特定のテストスイートだけ実行
#   ./scripts/test.sh --coverage                     # カバレッジ計測付きで実行
#   ./scripts/test.sh --clean                        # ビルド成果物を削除してフルビルド
#
# ■ 実行環境
#   このスクリプトは Linux 環境（Docker コンテナ内 または WSL）で実行する想定。
#   macOS の場合は以下のコマンドで Docker 経由で実行する：
#     docker compose run --rm test
# =============================================================================

# --- シェルの安全設定 ---------------------------------------------------------
# set コマンドでシェルの動作モードを設定する。
#   -e : コマンドがエラー（終了コード 0 以外）になったら、即座にスクリプトを中断する
#   -u : 未定義の変数を使おうとしたらエラーにする（タイプミス防止）
#   -o pipefail : パイプ（|）で繋いだコマンドのうち、途中でエラーが出ても検出する
# これらを設定することで、問題を早期に発見し、誤った状態で処理が続くのを防ぐ。
set -euo pipefail

# --- ディレクトリパスの取得 ---------------------------------------------------
# スクリプト自身の場所から、プロジェクトやワークスペースの絶対パスを算出する。
# こうすることで、どのディレクトリからスクリプトを実行しても正しく動作する。

# SCRIPT_DIR : このスクリプト（test.sh）が置かれているディレクトリの絶対パス
#   ${BASH_SOURCE[0]} → 実行中のスクリプトファイルのパス
#   dirname → そのファイルが含まれるディレクトリ名を取得
#   cd ... && pwd → そのディレクトリに移動して絶対パスを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# PROJECT_ROOT : プロジェクトのルートディレクトリ（scripts/ の1つ上の階層）
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# WORKSPACE_ROOT : ワークスペース全体のルート（プロジェクトの1つ上の階層）
#   external/ フォルダ（Zephyr 本体など）もここに含まれる
WORKSPACE_ROOT="$(cd "${PROJECT_ROOT}/.." && pwd)"

# --- コマンドライン引数の解析 -------------------------------------------------
# スクリプト実行時に指定されたオプション（引数）を読み取る。
# 例: ./scripts/test.sh --verbose --filter "led_toggle"
#
# $# : 引数の残り個数。0 になるまでループで1つずつ処理する。
# $1 : 現在処理中の引数の値。
# shift : 引数リストを1つ左にずらす（次の引数を $1 にする）。

VERBOSE=""       # 詳細表示フラグ。--verbose が指定されたら "-v" が入る
COVERAGE=""     # カバレッジ計測フラグ。--coverage が指定されたら有効
CLEAN=""        # クリーンビルドフラグ。--clean が指定されたらビルド成果物を削除
EXTRA_ARGS=""    # その他の追加引数をまとめて格納する変数

while [[ $# -gt 0 ]]; do
    case $1 in
        --verbose|-v)
            # --verbose または -v が指定された場合、Twister に -v オプションを渡す
            VERBOSE="-v"
            shift  # 次の引数へ進む
            ;;
        --coverage)
            # --coverage が指定された場合、Twister にカバレッジ計測オプションを渡す
            COVERAGE="true"
            shift
            ;;
        --clean)
            # --clean が指定された場合、前回のビルド成果物を削除してフルビルドする
            # 通常はインクリメンタルビルド（差分ビルド）で高速に実行するが、
            # ビルドに問題がある場合やクリーンな状態から始めたい場合に使う
            CLEAN="true"
            shift
            ;;
        *)
            # 上記以外の引数はすべて EXTRA_ARGS に追加（Twister にそのまま渡される）
            # 例: --filter "led_toggle_edge" など
            EXTRA_ARGS="${EXTRA_ARGS} $1"
            shift
            ;;
    esac
done

# --- 環境変数の設定 -----------------------------------------------------------
# ZEPHYR_BASE : Zephyr RTOS のソースコードがあるディレクトリのパス。
#   Twister や West が Zephyr の各種ツールやライブラリを見つけるために必要。
#   すでに環境変数として設定されていればそれを使い、未設定なら
#   ワークスペース内の external/zephyr を使う。
#
#   ${変数名:-デフォルト値} は bash の構文で、
#   「変数が未設定ならデフォルト値を使う」という意味。
#
#   export すると、このスクリプトから呼び出される子プロセス（west など）にも
#   この変数が引き継がれる。
export ZEPHYR_BASE="${ZEPHYR_BASE:-${WORKSPACE_ROOT}/external/zephyr}"

# ZEPHYR_BASE のディレクトリが実際に存在するかチェック。
# 存在しない場合はエラーメッセージを表示して終了する。
#   -d : ディレクトリが存在するかテストする条件式
#   >&2 : エラー出力（標準エラー出力）にメッセージを送る
#   exit 1 : 終了コード 1（異常終了）でスクリプトを終了
if [[ ! -d "${ZEPHYR_BASE}" ]]; then
    echo "ERROR: ZEPHYR_BASE not found at ${ZEPHYR_BASE}" >&2
    exit 1
fi

# --- Git safe.directory の設定（Docker 環境用）-------------------------------
#
# ● なぜテストの実行に Git が関係するのか？
#   West や Twister は内部で git コマンドを使用している。
#   例えば、ワークスペースのルートディレクトリを探したり、
#   Zephyr やプロジェクトのバージョン情報を取得する際に git を実行する。
#   そのため、Git が正常に動作しないとテストの実行自体が失敗してしまう。
#
# ● Docker 環境で何が問題になるのか？
#   Docker コンテナ内でテストを実行するとき、ホスト PC のファイルを
#   コンテナ内に「マウント（共有）」して使う。
#   すると、ファイルの所有者がホスト PC のユーザー（例: uid=501）のままだが、
#   コンテナ内では root（uid=0）として実行することになる。
#
#   Git にはセキュリティ対策として、「自分以外のユーザーが所有するリポジトリは
#   操作を拒否する」という仕組みがある（CVE-2022-24765 への対策）。
#   この仕組みにより、コンテナ内で git コマンドが失敗してしまう。
#
# ● このコードが行うこと
#   Git に「このディレクトリは信頼できるので、所有者が違ってもアクセスを許可する」
#   と伝える設定（safe.directory）を追加する。
#   ワークスペース内にあるすべての .git フォルダ（＝Git リポジトリ）を探して、
#   それぞれを safe.directory に登録する。
#
# ● 実行条件（Docker 環境かどうかの判定）:
#   /.dockerenv ファイルが存在する → Docker コンテナ内で実行されている証拠
#   または、root ユーザー（$EUID -eq 0）なのに root 以外が所有する .git がある
#   → どちらかに該当する場合のみ、この設定を行う。
#   通常の PC 上で直接実行している場合は、この処理はスキップされる。
#
# ● || true について
#   git config コマンドが失敗してもスクリプトを止めないための記述。
#   この設定は「あると安全」程度のものなので、失敗しても致命的ではない。
if [[ -f /.dockerenv ]] || [[ $EUID -eq 0 && $(find "${WORKSPACE_ROOT}" -maxdepth 1 -name ".git" -not -user root 2>/dev/null | wc -l) -gt 0 ]]; then
    find "${WORKSPACE_ROOT}" -name ".git" -type d 2>/dev/null | while read -r gitdir; do
        repo_dir="$(dirname "$gitdir")"
        git config --global --add safe.directory "$repo_dir" 2>/dev/null || true
    done
fi

# --- Python 依存パッケージのインストール -------------------------------------
# Twister（テスト実行ツール）は内部で Python スクリプトを使用しており、
# いくつかの Python ライブラリが必要。
#   elftools : ELF 形式（実行ファイルの形式）を解析するライブラリ
#   ply      : 字句解析・構文解析ライブラリ（Kconfig の解析などに使用）
#
# python3 -c "import ..." でライブラリが使えるか確認し、
# 使えなければ pip3 でインストールする。
#   ! : 条件を反転（インポートに失敗したら true になる）
#   || : 左のコマンドが失敗したら右を実行する（フォールバック）
#   --quiet : インストール時の出力を抑制する
if ! python3 -c "import elftools" 2>/dev/null || ! python3 -c "import ply" 2>/dev/null; then
    echo "Installing Zephyr Python dependencies..."
    pip3 install --quiet -r "${ZEPHYR_BASE}/scripts/requirements-base.txt" 2>/dev/null || \
    pip3 install --quiet ply pyyaml pykwalify packaging colorama pyelftools 2>/dev/null || true
fi

# --- テストの実行 -------------------------------------------------------------
# ここからが本題。Twister を使ってユニットテストをビルド・実行する。

# --- カバレッジ計測の準備 -----------------------------------------------------
# --coverage が指定された場合、gcovr がインストールされているか確認し、
# 未インストールなら自動でインストールする。
#   gcovr : GCC のカバレッジデータ（.gcda/.gcno）から HTML/XML レポートを生成するツール。
COVERAGE_ARGS=""
if [[ "${COVERAGE}" == "true" ]]; then
    if ! command -v gcovr &>/dev/null; then
        echo "gcovr をインストールしています..."
        pip3 install --quiet gcovr 2>/dev/null || true
    fi
    # Twister に渡すカバレッジオプションを組み立てる
    #   --coverage              : カバレッジ計測を有効にする（gcc に -fprofile-arcs -ftest-coverage を付与）
    #   --coverage-tool gcovr   : レポート生成に gcovr を使用する
    #   --coverage-basedir      : カバレッジ計測のルートディレクトリを src/ に限定する
    #   --coverage-formats      : 出力形式を指定する（カンマ区切り）
    #                             html : ブラウザで開けるカバレッジレポート
    #                             txt  : ターミナルに表示できるテキストレポート
    COVERAGE_ARGS="--coverage --coverage-tool gcovr --coverage-basedir ${PROJECT_ROOT}/src --coverage-formats html,txt"
fi

# テスト開始のヘッダーを表示
echo "============================================="
if [[ "${COVERAGE}" == "true" ]]; then
    echo " Running unit tests with COVERAGE (native_sim + ztest)"
else
    echo " Running unit tests (native_sim + ztest)"
fi
echo " ZEPHYR_BASE: ${ZEPHYR_BASE}"
echo "============================================="

# ワークスペースルートからプロジェクトルートへの相対パスを計算する。
#   ${変数#パターン} は bash の構文で、変数の値の先頭から「パターン」に一致する部分を
#   削除した残りを返す。
#   例: PROJECT_ROOT="/home/user/workspace/study_spec_kit_00"
#       WORKSPACE_ROOT="/home/user/workspace"
#       → PROJECT_REL_PATH="study_spec_kit_00"
PROJECT_REL_PATH="${PROJECT_ROOT#${WORKSPACE_ROOT}/}"

# West コマンドは Zephyr のワークスペースルートから実行する必要があるため、
# カレントディレクトリ（作業ディレクトリ）をワークスペースルートに変更する。
cd "${WORKSPACE_ROOT}"

# --- ビルド成果物の管理 -------------------------------------------------------
# デフォルトではインクリメンタルビルド（差分ビルド）を使用する。
# 前回のビルド成果物（twister-out/）を残しておくことで、CMake の再構成を
# スキップし、変更があったファイルだけを再コンパイルできる。
# これにより、2回目以降の実行時間を大幅に短縮できる（約1分30秒 → 数十秒）。
#
# --clean が指定された場合のみ、ビルド成果物を完全に削除してフルビルドする。
if [[ "${CLEAN}" == "true" ]]; then
    echo "クリーンビルド: 前回のビルド成果物を削除します..."
    rm -rf "${PROJECT_REL_PATH}"/twister-out*
fi

# === west twister コマンド（テスト実行の中核）===
# west twister を実行してユニットテストをビルド・実行する。
#
# 各オプションの意味:
#   -T "パス"    : テストコードが置かれているディレクトリを指定する
#                  ここでは tests/unit/ 以下のすべてのテストが対象
#   -p native_sim : テストを実行するプラットフォーム（ターゲットボード）を指定する
#                   native_sim は PC 上でシミュレーション実行するための仮想ボード
#   -O "パス"    : テスト結果の出力先ディレクトリを指定する
#   ${VERBOSE}   : --verbose が指定されていれば "-v" が展開され、詳細ログが出る
#   ${EXTRA_ARGS}: その他の追加オプション（--filter など）がここに入る
#   2>&1         : 標準エラー出力（エラーメッセージ）を標準出力に統合する
#                  （すべての出力を1つの画面にまとめて表示するため）
#
# \ （バックスラッシュ）は「次の行に続く」という意味。
# 長いコマンドを見やすく複数行に分けて書くために使う。
# === west twister の高速化オプション ===
#   -n (--no-clean)    : ビルドディレクトリを再利用する
#                        前回のビルド成果物があれば差分ビルドになる
#   -x=USE_CCACHE=1    : ccache（コンパイルキャッシュ）を有効にする
#                        同じソースの再コンパイルをキャッシュからスキップする
west twister \
    -T "${PROJECT_REL_PATH}/tests/unit" \
    -p native_sim \
    -O "${PROJECT_REL_PATH}/twister-out" \
    -n \
    -x=USE_CCACHE=1 \
    ${VERBOSE} \
    ${COVERAGE_ARGS} \
    ${EXTRA_ARGS} \
    2>&1

# $? は直前に実行したコマンドの「終了コード」を取得する特殊変数。
#   0 : 成功（すべてのテストが合格）
#   0 以外 : 失敗（テストが不合格、またはビルドエラーなど）
EXIT_CODE=$?

# --- テスト結果の表示 ---------------------------------------------------------
# テスト結果に応じて、成功または失敗のメッセージを表示する。
echo ""
echo "============================================="
if [[ ${EXIT_CODE} -eq 0 ]]; then
    # -eq : 数値の等価比較（equal の略）
    echo " ✅ All tests PASSED"
    if [[ "${COVERAGE}" == "true" ]]; then
        COVERAGE_TXT="${PROJECT_REL_PATH}/twister-out/coverage/coverage.txt"
        if [[ -f "${COVERAGE_TXT}" ]]; then
            echo ""
            echo " 📊 カバレッジサマリー:"
            echo " ---------------------------------------------"
            cat "${COVERAGE_TXT}"
            echo " ---------------------------------------------"
        fi
        echo ""
        echo " 📊 カバレッジレポート (詳細):"
        echo "   HTML: twister-out/coverage/index.html"
    fi
else
    echo " ❌ Tests FAILED (exit code: ${EXIT_CODE})"
    echo ""
    echo " See detailed logs:"
    echo "   twister-out/native_sim/app.led_toggle_button.unit/handler.log"
fi
echo "============================================="

# スクリプトの終了コードとして、Twister の結果をそのまま返す。
# これにより、CI（継続的インテグレーション）パイプラインなどで
# テスト結果を自動的に判定できる。
exit ${EXIT_CODE}
