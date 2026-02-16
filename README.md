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

## 書き込み・実行

```bash
west flash
```

nRF52840DK を USB で接続した状態で実行してください。

## 動作確認

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
├── CMakeLists.txt          # Zephyr ビルド定義
├── prj.conf                # Kconfig 設定
├── west.yml                # West マニフェスト（NCS v2.6.3）
├── README.md               # このファイル
├── scripts/
│   └── env.sh              # ツールチェーン環境セットアップ
├── src/
│   └── main.c              # アプリケーションコード
└── specs/
    └── 001-led-toggle-button/
        ├── spec.md          # 機能仕様書
        ├── plan.md          # 実装計画
        ├── tasks.md         # タスク一覧
        ├── research.md      # 技術調査
        ├── data-model.md    # データモデル
        ├── quickstart.md    # 詳細テスト手順
        └── contracts/       # インターフェース契約
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

## ライセンス

Nordic-5-Clause
