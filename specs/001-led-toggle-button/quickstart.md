# Quickstart: nRF52840DK LED トグル（ボタン操作）

**Feature**: 001-led-toggle-button  
**Date**: 2026-02-11

## 前提条件

- nRF Connect SDK がインストールされていること（`west` コマンドが使えること）
- nRF52840DK (PCA10056) ボードが USB で接続されていること
- J-Link ドライバがインストールされていること

## プロジェクト構成

```
project-root/
├── CMakeLists.txt      # ビルドシステム定義
├── prj.conf            # Kconfig設定
└── src/
    └── main.c          # アプリケーションコード
```

## ビルド

```bash
# ビルド
west build -b nrf52840dk/nrf52840

# クリーンビルド（設定変更後）
west build -b nrf52840dk/nrf52840 --pristine
```

## 書き込み

```bash
west flash
```

## 動作確認

1. ファームウェア書き込み後、nRF52840DK の LED 1〜4 がすべて消灯していることを確認
2. **Button 1** を1回押す → **LED 1** が点灯
3. **Button 1** をもう1回押す → **LED 1** が消灯
4. **Button 2〜4** でも同様に対応する LED がトグルされることを確認
5. 複数の LED を独立して操作できることを確認

## テストチェックリスト

| テスト項目 | 手順 | 期待結果 | 合否 |
|-----------|------|---------|------|
| 初期状態 | 電源投入直後 | LED 1〜4 すべて消灯 | ☐ |
| Button 1 → LED 1 点灯 | Button 1 を1回押す | LED 1 のみ点灯 | ☐ |
| Button 1 → LED 1 消灯 | Button 1 をもう1回押す | LED 1 消灯 | ☐ |
| Button 2 → LED 2 | Button 2 を操作 | LED 2 がトグル | ☐ |
| Button 3 → LED 3 | Button 3 を操作 | LED 3 がトグル | ☐ |
| Button 4 → LED 4 | Button 4 を操作 | LED 4 がトグル | ☐ |
| 独立性 | LED 1 点灯中に Button 3 | LED 3 トグル、LED 1 変化なし | ☐ |
| 連打耐性 | Button 1 を10回連打 | 10回すべてのトグルが反映 | ☐ |
| 長押し | Button 1 を3秒長押し | LED 1 が1回だけトグル | ☐ |
| リセット | リセットボタン押下 | 全LED消灯に戻る | ☐ |

## Kconfig設定一覧

| 設定 | 値 | 説明 |
|------|-----|------|
| `CONFIG_GPIO` | `y` | GPIO サブシステム有効化 |
| `CONFIG_DK_LIBRARY` | `y` | dk_buttons_and_leds ライブラリ有効化 |
| `CONFIG_LOG` | `y` | ログサブシステム有効化（デバッグ用） |

## トラブルシューティング

| 症状 | 原因 | 対処 |
|------|------|------|
| ビルドエラー: `dk_buttons_and_leds.h not found` | nRF Connect SDK が正しく設定されていない | `west update` を実行、SDK パスを確認 |
| ボタンを押しても反応しない | 初期化失敗 | シリアルコンソール（115200bps）でログを確認 |
| LED がチカチカする | チャタリング | prj.conf の `CONFIG_DK_LIBRARY_BUTTON_SCAN_INTERVAL` を増やす |
| 書き込みエラー | J-Link 接続問題 | USB ケーブル再接続、`nrfjprog --reset` を試行 |
