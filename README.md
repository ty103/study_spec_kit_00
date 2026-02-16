# LED Toggle Button — nRF52840DK

nRF52840DK 上のボタン（Button 1〜4）を押すたびに、対応する LED（LED 1〜4）の点灯/消灯を切り替える Zephyr アプリケーションです。

## 機能

- **Button N → LED N トグル**（N = 1〜4）
- 押下時のみ反応（リリース時は無視）
- 起動時は全 LED 消灯
- デバウンス 15ms（dk_buttons_and_leds ライブラリ内蔵）
- 各ボタン・LED は独立動作

## 必要なもの

| 項目 | 詳細 |
|---|---|
| ハードウェア | nRF52840DK (PCA10056) |
| SDK | nRF Connect SDK v2.6.3 |
| ツールチェーン | nRF Connect SDK Toolchain（`/opt/nordic/ncs/toolchains/` にインストール済み） |
| J-Link | SEGGER J-Link ドライバ |
| Docker | テスト実行用（macOS の場合は Docker Desktop が必要） |

## セットアップ

### 1. リポジトリをクローン

```bash
git clone <this-repo-url> study_spec_kit_00
```

以降のコマンドは、`git clone` を実行したディレクトリ（＝ワークスペースルート）で実行します。

### 2. West ワークスペースを初期化

```bash
west init -l study_spec_kit_00
```

これにより `.west/` ディレクトリが `study_spec_kit_00/` と同じ階層に作成されます。

### 3. `.west/config` に Zephyr ベースパスを追加

```ini
[manifest]
path = study_spec_kit_00
file = west.yml

[zephyr]
base = external/zephyr
```

> `west init` で `[manifest]` セクションは自動生成されます。`[zephyr]` セクションを手動で追加してください。

### 4. SDK 依存モジュールを取得

```bash
west update --narrow -o=--depth=1
```

> 初回は 10〜20 分かかります。`external/` 配下に Zephyr、MCUboot、nrfxlib 等がクローンされます。

### 5. 環境変数をセットアップ

```bash
source study_spec_kit_00/scripts/env.sh --check
```

このスクリプトは以下を行います：
- Nordic ツールチェーンを `PATH` に追加
- `ZEPHYR_BASE` を `external/zephyr` に設定
- `--check` オプションで必要なツール（west, cmake, ninja, dtc, arm-zephyr-eabi-gcc）の存在を確認

> ⚠️ ビルド前に **毎回** `source` する必要があります。`.bashrc` / `.zshrc` に追記すると便利です。

## ビルド

ワークスペースルート（`study_spec_kit_00/` の親ディレクトリ）で実行します。

```bash
source study_spec_kit_00/scripts/env.sh
west build -b nrf52840dk_nrf52840 study_spec_kit_00 --pristine
```

> ⚠️ **macOS でビルドがハングする場合**: CMake の GDB 検出フェーズで `arm-zephyr-eabi-gdb-py --configuration` がフリーズすることがあります。以下のオプションで回避できます：
> ```bash
> west build -b nrf52840dk_nrf52840 study_spec_kit_00 --pristine -- \
>   -DCMAKE_GDB=/opt/nordic/ncs/toolchains/561dce9adf/opt/zephyr-sdk/arm-zephyr-eabi/bin/arm-zephyr-eabi-gdb
> ```

## 書き込み・実行

```bash
west flash
```

nRF52840DK を USB で接続した状態で実行してください。

## 自動テスト

### 概要

トグルロジック（`src/led_toggle.c`）の単体テストを、Zephyr 公式テストフレームワーク **ztest** + **Twister** で実行します。
テストは **Docker コンテナ内の Linux（x86_64）環境** で `native_sim` ボードターゲットを使って実行されます。

| 項目 | 内容 |
|------|------|
| フレームワーク | Zephyr ztest（`ZTEST_SUITE` / `ZTEST` 新 API） |
| テストランナー | Twister（`west twister`） |
| ボードターゲット | `native_sim`（Linux 上で ELF として実行） |
| テストケース数 | 19（4 スイート） |
| 実行環境 | Docker（linux/amd64）または WSL / Linux ネイティブ |

### テストスイート構成

| スイート名 | テスト数 | カバーする要件 |
|-----------|---------|---------------|
| `led_toggle_init` | 3 | FR-001（初期状態 — 全 LED 消灯） |
| `led_toggle_single` | 7 | FR-002, FR-003, SC-003（1:1 マッピング、トグル、連打耐性） |
| `led_toggle_multi` | 4 | FR-005（独立動作、同時押し） |
| `led_toggle_edge` | 5 | FR-006, FR-007（押下エッジ検出、長押し 1 回のみ） |

### テスト実行方法

#### macOS（Docker 使用）

```bash
# 初回: Docker イメージのビルド（1〜2 分）
docker compose build test

# テスト実行
docker compose run --rm test

# デバッグ用の対話シェル
docker compose run --rm test bash
```

#### Windows / WSL / Linux（Docker 不要）

WSL や Linux 環境では Docker なしで直接実行できます。

```bash
source scripts/env.sh
./scripts/test.sh
```

#### Twister を直接実行

```bash
west twister -T tests/unit -p native_sim
```

### テスト結果の確認

```
INFO - 1 of 1 test configurations passed (100.00%)
✅ All tests PASSED
```

失敗時は以下のログを確認してください：

```
twister-out/native_sim/app.led_toggle_button.unit/handler.log
twister-out/native_sim/app.led_toggle_button.unit/build.log
```

### 設計判断の経緯と制約

#### なぜ Docker が必要か

Zephyr の `native_sim` ボードターゲットは **Linux の ELF バイナリ** としてテストを実行します。
macOS では以下の理由によりネイティブ実行ができません：

1. **`native_sim` は Linux 専用** — Zephyr の `arch/posix` が ELF + Linux syscall に依存しており、macOS の Mach-O バイナリ形式とは互換性がない
2. **`unit_testing` モード** も macOS の Clang では `__attribute__((section(...)))` の構文が Mach-O と非互換でコンパイル不可
3. **Apple Silicon（ARM64）+ x86_64 エミュレーション** — Docker Desktop の Rosetta エミュレーションにより `linux/amd64` コンテナを実行し、32-bit multilib（`gcc-multilib`）を含む完全な x86 Linux 環境を提供

```
macOS (ARM64)
  └─ Docker Desktop (Rosetta x86_64 emulation)
      └─ Ubuntu 22.04 (linux/amd64)
          └─ gcc + gcc-multilib
              └─ west twister -p native_sim
                  └─ ztest ELF binary (x86, 32-bit)
```

#### なぜロジックを分離したか

元の `main.c` はすべてが `static` 関数で、外部からテストできませんでした。
ハードウェア非依存の **純粋ロジック**（ビットマスク操作、エッジ検出）を `led_toggle.c` / `led_toggle.h` に抽出することで：

- テスト対象を `dk_buttons_and_leds` ライブラリから完全に切り離し
- `native_sim` 上で GPIO/nrfx ドライバなしにテスト可能
- スタブヘッダ（`tests/unit/stubs/dk_buttons_and_leds.h`）でマクロ定義のみ提供

#### なぜ `CONFIG_DK_LIBRARY` をテストで無効にしたか

`dk_buttons_and_leds` ライブラリの実体は nRF ハードウェア（nrfx GPIO ドライバ）に依存しており、`native_sim` ではコンパイルできません。
テストではアプリケーションのトグルロジックのみを検証するため、DK ライブラリのビルドは不要です。

#### 制約事項

| 制約 | 詳細 |
|------|------|
| macOS では Docker が必須 | `native_sim` は Linux 専用のため |
| Docker イメージは `linux/amd64` 固定 | Apple Silicon では Rosetta エミュレーションで動作。x86_64 ネイティブ環境より低速（テスト全体で約 40 秒） |
| ハードウェア連携テストはカバー外 | `dk_buttons_and_leds` の初期化・GPIO 制御は実機テスト（`quickstart.md`）で検証 |
| DK ライブラリのモック未実装 | 現時点では純粋ロジックのテストのみ。`main.c` の `button_handler` → `dk_set_leds` 呼び出しは未テスト |

#### チームメンバー向けのプラットフォーム対応表

| 環境 | テスト方法 | Docker 必要？ |
|------|-----------|-------------|
| macOS (Intel) | `docker compose run --rm test` | ✅ 必要 |
| macOS (Apple Silicon) | `docker compose run --rm test` | ✅ 必要（Rosetta） |
| Windows + WSL | `./scripts/test.sh` | ❌ 不要 |
| Linux (x86_64) | `./scripts/test.sh` | ❌ 不要 |
| CI/CD (GitHub Actions 等) | `docker compose run --rm test` | Docker ベース |

## 動作確認（実機手動テスト）

| # | テスト項目 | 手順 | 期待結果 |
|---|-----------|------|---------|
| 1 | 初期状態 | 電源投入直後 | LED 1〜4 すべて消灯 |
| 2 | Button 1 → LED 1 点灯 | Button 1 を1回押す | LED 1 のみ点灯 |
| 3 | Button 1 → LED 1 消灯 | Button 1 をもう1回押す | LED 1 消灯 |
| 4 | Button 2〜4 | 各ボタンを操作 | 対応する LED がトグル |
| 5 | 独立性 | LED 1 点灯中に Button 3 | LED 3 トグル、LED 1 変化なし |
| 6 | 連打耐性 | Button 1 を10回連打 | 10回すべて反映 |
| 7 | 長押し | Button 1 を3秒長押し | 1回だけトグル |
| 8 | リセット | リセットボタン押下 | 全 LED 消灯に戻る |

## プロジェクト構成

```
study_spec_kit_00/
├── CMakeLists.txt              # Zephyr ビルド定義
├── prj.conf                    # Kconfig 設定
├── west.yml                    # West マニフェスト（NCS v2.6.3）
├── README.md                   # このファイル
├── docker-compose.yml          # テスト用 Docker Compose 設定
├── .dockerignore               # Docker ビルド除外設定
├── docker/
│   └── Dockerfile.test         # テスト環境用 Dockerfile (Ubuntu 22.04 + Zephyr SDK)
├── scripts/
│   ├── env.sh                  # ツールチェーン環境セットアップ
│   └── test.sh                 # テスト実行スクリプト
├── src/
│   ├── main.c                  # アプリケーションエントリポイント
│   ├── led_toggle.h            # トグルロジック API（テスト可能モジュール）
│   └── led_toggle.c            # トグルロジック実装（ハードウェア非依存）
├── tests/
│   └── unit/
│       ├── CMakeLists.txt      # テスト用 Zephyr ビルド定義
│       ├── prj.conf            # テスト用 Kconfig
│       ├── testcase.yaml       # Twister テスト設定（native_sim）
│       ├── src/
│       │   └── main.c          # テストケース（19 件、4 スイート）
│       └── stubs/
│           └── dk_buttons_and_leds.h  # DK マクロ定義のスタブヘッダ
└── specs/
    └── 001-led-toggle-button/
        ├── spec.md             # 機能仕様書
        ├── plan.md             # 実装計画
        ├── tasks.md            # タスク一覧
        ├── research.md         # 技術調査
        ├── data-model.md       # データモデル
        ├── quickstart.md       # 詳細テスト手順（実機）
        ├── checklists/         # 仕様品質チェックリスト
        └── contracts/          # インターフェース契約
```

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| `west: command not found` | ツールチェーンが PATH にない | `source scripts/env.sh` を実行 |
| `west: unknown command "build"` | マニフェスト解決失敗 | `west update` を実行して依存を取得 |
| `dk_buttons_and_leds.h not found` | SDK モジュール不足 | `west update` を実行 |
| ボタンを押しても反応しない | 初期化失敗 | シリアルコンソール（115200bps）でログ確認 |
| LED がチカチカする | チャタリング | `CONFIG_DK_LIBRARY_BUTTON_SCAN_INTERVAL` を増やす |
| 書き込みエラー | J-Link 接続問題 | USB 再接続、`nrfjprog --reset` を試行 |
| ビルドが 30 分以上ハング | `gdb-py --configuration` のフリーズ | ビルドセクションの `-DCMAKE_GDB=...` オプションを使用 |
| `docker: command not found` | Docker 未インストール | [Docker Desktop](https://docs.docker.com/desktop/) をインストール |
| `POSIX architecture only works on Linux` | macOS で native_sim を実行 | `docker compose run --rm test` を使用 |
| `bits/libc-header-start.h: No such file` | gcc-multilib 不足 | Docker イメージを再ビルド: `docker compose build test` |
| テストが約 40 秒かかる | Apple Silicon の x86_64 エミュレーション | 正常動作。Linux ネイティブ環境ではより高速 |

## ライセンス

Nordic-5-Clause
