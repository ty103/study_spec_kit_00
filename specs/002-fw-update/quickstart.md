# Quickstart: FW更新機能

**Feature**: 002-fw-update  
**Date**: 2026-02-27

## 前提条件

- nRF Connect SDK v3.2.2 がインストール済み
- nRF52840DK（PCA10056）が USB 接続されている
- Go 1.18 以降がインストール済み（mcumgr CLI用）
- Docker がインストール済み（テスト実行用）

## ビルド

### 1. MCUboot付きでビルド

```bash
cd /Users/yamajitakashi/nordic/sdd/study_spec_kit_00
west build -b nrf52840dk/nrf52840 -- -DSB_CONFIG_BOOTLOADER_MCUBOOT=y
```

### 2. メモリレポートの確認（原則VI準拠）

```bash
west build -t rom_report
west build -t ram_report
```

### 3. フラッシュ書き込み

```bash
west flash
```

## テスト実行

### ユニットテスト（native_sim）

```bash
# Docker経由（macOS）
docker compose run --rm test

# または直接（Linux）
./scripts/test.sh
```

### テストスイート構成

| ファイル | テスト対象 | 対応するユーザーストーリー |
|---------|---------|----------------------|
| `tests/unit/src/fw_update_test.c` | FW更新モード管理ロジック | US1〜US4 |
| `tests/unit/src/led_toggle_test.c` | LED切り替えロジック（既存） | — |

## FW更新の実行手順

### 1. mcumgr CLI のインストール

```bash
go install github.com/apache/mynewt-mcumgr-cli/mcumgr@latest
```

### 2. シリアル接続の設定

```bash
# macOS の場合（デバイス名は環境により異なる）
mcumgr conn add nrf52 type="serial" connstring="dev=/dev/tty.usbmodem*,baud=115200,mtu=512"
```

### 3. FW更新フロー

```bash
# ステップ1: デバイス上でボタン4を押してFW更新待ちモードに入る
#            → LED1〜3が消灯し、LED4が高速点滅を開始する

# ステップ2: 現在のイメージを確認
mcumgr -c nrf52 image list

# ステップ3: 新しいファームウェアをアップロード
mcumgr -c nrf52 image upload build/zephyr/app_update.bin

# ステップ4: テストマークを設定
mcumgr -c nrf52 image test <hash>

# ステップ5: デバイスをリセット（新FWで起動）
mcumgr -c nrf52 reset

# → LED4が3秒間点灯（成功通知）後、新ファームウェアで再起動
# → アプリケーションが自動的にイメージをconfirm
```

### 3.1 確認手順のスクリプト実行（推奨）

```bash
# 接続設定〜upload〜test/reset まで一括実行
./scripts/mcumgr-verify.sh

# デバイスやイメージを明示する場合
./scripts/mcumgr-verify.sh \
	--dev /dev/tty.usbmodemXXXX \
	--image build/study_spec_kit_00/zephyr/zephyr.signed.bin

# upload確認までで止める場合
./scripts/mcumgr-verify.sh --skip-test-reset
```

### 4. キャンセル操作

```
FW更新待ち状態（LED4高速点滅中）でボタン4を再度押す
→ 全LEDが消灯し、通常動作に復帰する
```

### 5. タイムアウト

```
FW更新待ち状態に入ってから30秒間何も通信しない
→ 自動的に全LEDが消灯し、通常動作に復帰する
```

## 動作確認チェックリスト

- [ ] ボタン4でFW更新待ちモードに入る（LED4高速点滅）
- [ ] FW更新待ち中にボタン1〜3が無視される
- [ ] FW更新待ち中にボタン4でキャンセルできる（全LED消灯）
- [ ] 30秒タイムアウトで自動キャンセルされる
- [ ] mcumgrでファームウェアをアップロードできる
- [ ] 成功時にLED4が3秒間点灯する
- [ ] 失敗時にLED4が5回速く点滅する
- [ ] 新ファームウェアで再起動後、自動confirmされる
- [ ] メモリ使用量がバジェット内（Flash slot0 < 377KB、RAM < 204KB）

## トラブルシューティング

| 症状 | 原因と対処 |
|------|-----------|
| mcumgrが接続できない | UARTデバイスパスを確認。`ls /dev/tty.usb*` で検索 |
| アップロードが拒否される | FW更新待ちモードに入っているか確認（LED4が高速点滅しているか） |
| 更新後に起動しない | MCUbootがswapを完了するまで数秒待つ。JLinkでリカバリフラッシュ可能 |
| LED4が点滅しない | prj.confで`CONFIG_DK_LIBRARY=y`が設定されているか確認 |
