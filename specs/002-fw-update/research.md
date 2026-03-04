# Research: FW更新機能

**Feature**: 002-fw-update  
**Date**: 2026-02-27  
**Status**: Complete

## 調査概要

FW更新機能の実装に必要な技術調査を実施した。NCS v3.x / Zephyr RTOS のMCUmgr + MCUbootスタックを中心に、設定方法、メモリ影響、PC側ツール、イメージ確認APIについて調査した。

---

## 1. MCUmgr SMP over UART の設定

### Decision: NCS標準のMCUmgr UART トランスポートを使用

### Rationale

- Zephyr / NCS に標準で組み込まれており、Kconfigのみで有効化可能
- CMakeLists.txtの変更は不要（ビルドシステムが自動的にリンク）
- 追加スレッド不要 — UART割り込みでフレーム受信、system work queueで処理
- nRF52840DKでは `uart0` がデフォルトのMCUmgr UARTインスタンス（DTS `zephyr,uart-mcumgr`）

### Alternatives Considered

- **カスタムUARTプロトコル**: 独自実装が必要でバグリスクが高い。PC側ツールも自作必要。却下
- **MCUmgr Shell トランスポート**: Shell機能全体を有効化する必要があり、Flash/RAMオーバーヘッドが大きい。却下
- **BLE DFU**: 仕様でUARTが指定されている。BLEスタックのメモリ消費が大きい。却下

### 必要な設定

#### prj.conf（アプリケーション側）

```ini
# --- MCUmgr コア ---
CONFIG_MCUMGR=y
CONFIG_NET_BUF=y
CONFIG_ZCBOR=y
CONFIG_CRC=y

# --- Flash / ストリームFlash ---
CONFIG_FLASH=y
CONFIG_FLASH_MAP=y
CONFIG_STREAM_FLASH=y

# --- MCUboot 対応バイナリ生成 ---
CONFIG_BOOTLOADER_MCUBOOT=y

# --- イメージ管理コマンドグループ ---
CONFIG_IMG_MANAGER=y
CONFIG_MCUMGR_GRP_IMG=y

# --- OS管理コマンドグループ（reset用）---
CONFIG_MCUMGR_GRP_OS=y

# --- UART トランスポート ---
CONFIG_BASE64=y
CONFIG_MCUMGR_TRANSPORT_UART=y
CONFIG_CONSOLE=y

# --- スタックサイズ ---
CONFIG_SYSTEM_WORKQUEUE_STACK_SIZE=2304
CONFIG_MAIN_STACK_SIZE=2176
```

### UART共有に関する注意

nRF52840DKでは `uart0` がコンソール出力とMCUmgr UARTの両方に使われる。MCUmgr UART トランスポートを有効化すると、コンソールログ出力との併用になる。SMP フレームはBase64エンコードされ `\n` 区切りのため、ログ出力と混在しても解析可能。

### リファレンスファイル

- Zephyr smp_svrサンプル: `external/zephyr/samples/subsys/mgmt/mcumgr/smp_svr/`
- UARTオーバーレイ: `external/zephyr/samples/subsys/mgmt/mcumgr/smp_svr/overlay-serial.conf`
- UART MCUmgrドライバ: `external/zephyr/drivers/console/uart_mcumgr.c`

---

## 2. MCUboot の sysbuild 設定

### Decision: sysbuild でMCUbootを有効化し、SWAP_USING_MOVE モードを使用

### Rationale

- NCS v3.xではsysbuildが標準的なマルチイメージビルド方法
- NCSデフォルトの `SWAP_USING_MOVE` モードは、scratch パーティション不要でFlash効率が良い
- swap方式はファームウェア更新の信頼性を確保（電源断でも復旧可能）

### Alternatives Considered

- **OVERWRITE_ONLY**: ロールバック不可。仕様ではconfirmを即座に行うためロールバック機能は実質不要だが、将来の拡張性を考慮しswap方式を選択
- **SWAP_USING_SCRATCH**: 追加のscratchパーティションが必要でFlash消費が増える。却下
- **DIRECT_XIP**: slot0/slot1からの直接実行。特殊なリンカスクリプト調整が必要。却下

### 必要な設定

#### sysbuild.conf

```ini
SB_CONFIG_BOOTLOADER_MCUBOOT=y
```

または、ビルドコマンドで指定：
```bash
west build -b nrf52840dk/nrf52840 -- -DSB_CONFIG_BOOTLOADER_MCUBOOT=y
```

### nRF52840 フラッシュパーティション構成

| パーティション | アドレス | サイズ | 用途 |
|---|---|---|---|
| `boot_partition` (MCUboot) | `0x00000000` | 48KB | ブートローダー |
| `slot0_partition` (primary) | `0x0000C000` | 472KB | アプリケーション（実行中） |
| `slot1_partition` (secondary) | `0x00082000` | 472KB | DFU用イメージ格納 |
| `storage_partition` | `0x000F8000` | 32KB | NVS等 |

```
0x00000000 ┌─────────────────────┐
           │   MCUboot (48KB)    │
0x0000C000 ├─────────────────────┤
           │  slot0 / Primary    │
           │     (472KB)         │
0x00082000 ├─────────────────────┤
           │  slot1 / Secondary  │
           │     (472KB)         │
0x000F8000 ├─────────────────────┤
           │   storage (32KB)    │
0x00100000 └─────────────────────┘  ← 1MB
```

### リファレンスファイル

- NCS sysbuild.conf: `external/nrf/samples/zephyr/subsys/mgmt/mcumgr/smp_svr/sysbuild.conf`
- パーティションDTS: `external/zephyr/dts/vendor/nordic/nrf52840_partition.dtsi`
- MCUboot boardコンフィグ: `external/nrf/samples/zephyr/subsys/mgmt/mcumgr/smp_svr/sysbuild/mcuboot/boards/nrf52840dk_nrf52840.conf`

---

## 3. MCUboot イメージ確認（confirm）API

### Decision: `boot_write_img_confirmed()` を `main()` で起動直後に呼び出す

### Rationale

- Zephyr標準APIであり、追加依存なし
- MCUmgrのイメージ管理グループも内部的に同じAPIを使用
- 初回プログラミング時（magic未設定）は `boot_is_img_confirmed()` が `true` を返すため、不要な書き込みを回避可能

### 実装パターン

```c
#include <zephyr/dfu/mcuboot.h>

/* main() 内で起動直後に呼び出す */
if (!boot_is_img_confirmed()) {
    int rc = boot_write_img_confirmed();
    if (rc) {
        LOG_ERR("イメージ確認に失敗: %d", rc);
    } else {
        LOG_INF("新しいイメージを確認しました");
    }
}
```

### 必要なKconfig

```ini
CONFIG_IMG_MANAGER=y
CONFIG_BOOTLOADER_MCUBOOT=y
```

### リファレンスファイル

- APIヘッダ: `external/zephyr/include/zephyr/dfu/mcuboot.h`
- API実装: `external/zephyr/subsys/dfu/boot/mcuboot.c`

---

## 4. メモリバジェット分析

### 4.1 MCUboot による影響

- **MCUbootブートローダー自体**: 別パーティション（48KB）に格納。アプリケーションスロットとは独立
- **アプリケーション最大サイズ**: slot0の472KB（MCUbootなしの場合の約46%）
- **セカンダリスロット**: 472KBがDFU用に予約される

### 4.2 MCUmgr のアプリケーション側オーバーヘッド（推定値）

| コンポーネント | Flash 推定 | RAM 推定 |
|---|---|---|
| MCUmgr コア + SMP | ~5-8KB | ~1-2KB |
| IMG管理コマンドグループ | ~3-5KB | ~0.5-1KB |
| OS管理コマンドグループ | ~2-3KB | ~0.5KB |
| UART トランスポート | ~2-3KB | ~1KB（SMPバッファ） |
| Flash/StreamFlash | ~3-5KB | ~0.5KB |
| Base64/CRC | ~1-2KB | ~0.1KB |
| **合計（推定）** | **~16-26KB** | **~4-5KB** |

### 4.3 スタックサイズ

| スレッド/コンポーネント | サイズ | 根拠 |
|---|---|---|
| `CONFIG_MAIN_STACK_SIZE` | 2176 bytes | MCUmgrサンプル準拠。FW更新モード管理ロジック含む |
| `CONFIG_SYSTEM_WORKQUEUE_STACK_SIZE` | 2304 bytes | MCUmgr SMP処理用。サンプル準拠 |

### 4.4 バジェット判定

| リソース | 上限 | 利用可能量 | 閾値(80%) | 判定 |
|---|---|---|---|---|
| Flash (slot0) | 472KB | 472KB | 377KB | ✅ 現アプリ + MCUmgr (~26KB) で十分余裕あり |
| RAM | 256KB | 256KB | 204KB | ✅ 現アプリ + MCUmgr (~5KB) で十分余裕あり |

### 4.5 実測結果（T046）

実測コマンド（2026-02-27）:

```bash
west build -d build-mem/study_spec_kit_00 -t rom_report
west build -d build-mem/study_spec_kit_00 -t ram_report
```

実測値:

| リソース | 実測値 | 閾値 | 判定 |
|---|---|---|---|
| Flash（ROM report） | 59,800 B（約58.4 KB） | 377 KB（slot0の80%） | ✅ PASS |
| RAM（RAM report） | 17,850 B（約17.4 KB） | 204 KB（全RAMの80%） | ✅ PASS |

補足:

- `west build` 通常ビルド時のサマリでも同等値（FLASH 約59.8KB / RAM 約17.8KB）を確認
- NFR-001 / NFR-002 の閾値を十分下回っており、原則VI（メモリバジェット管理）を満たす

---

## 5. PC側ツール（mcumgr CLI）

### Decision: mcumgr CLIを評価・開発用ツールとして使用

### Rationale

- NCS公式ドキュメントで推奨されている評価用ツール
- Go言語で書かれており、macOS / Linux で動作
- SMP over UART をネイティブサポート

### インストール方法

```bash
go install github.com/apache/mynewt-mcumgr-cli/mcumgr@latest
```

### DFU 操作フロー

```bash
# 1. 接続設定の保存
mcumgr conn add nrf52 type="serial" connstring="dev=/dev/tty.usbmodem*,baud=115200,mtu=512"

# 2. 現在のイメージ一覧を確認
mcumgr -c nrf52 image list

# 3. 新しいイメージをアップロード
mcumgr -c nrf52 image upload build/zephyr/app_update.bin

# 4. テストアップグレードをマーク
mcumgr -c nrf52 image test <hash>

# 5. デバイスをリセット
mcumgr -c nrf52 reset
```

アプリケーション側で `boot_write_img_confirmed()` を呼ぶため、手順5のconfirmは不要。

### リファレンスファイル

- NCSドキュメント: `external/nrf/doc/nrf/app_dev/bootloaders_dfu/dfu_tools_mcumgr_cli.rst`

---

## 6. FW更新モード管理ロジック設計方針

### Decision: `fw_update.c` / `fw_update.h` として状態機械を実装

### Rationale

- 原則Iに基づき、ハードウェア非依存の純粋ロジックとして分離
- 状態遷移（通常動作 ↔ FW更新待ち）、タイムアウト判定、ボタンフィルタリングはすべてテスト可能な純粋関数として設計可能
- LED通知パターンの生成もハードウェア非依存

### 状態遷移

```
                  ボタン4押下
    ┌──────────┐ ──────────► ┌────────────────┐
    │ 通常動作 │              │  FW更新待ち    │
    │          │ ◄────────── │  (LED4高速点滅) │
    └──────────┘  キャンセル  └────┬───────────┘
         ▲        /タイムアウト     │
         │                         │ MCUmgr通信開始
         │                         ▼
         │                    ┌────────────────┐
         │                    │  FW転送中      │
         │                    │  (LED4高速点滅) │
         │                    └────┬───────────┘
         │                         │ 転送完了
         │                         ▼
         │   失敗             ┌────────────────┐
         ├───(LED4 5回点滅)── │  検証中        │
         │                    └────┬───────────┘
         │                         │ 成功
         │                         ▼
         │                    ┌────────────────┐
         └───(再起動)──────── │  適用・再起動  │
                              │  (LED4 3秒点灯) │
                              └────────────────┘
```

### MCUmgrサービスの有効化/無効化

MCUmgr SMPサーバーはアプリケーション起動時から常駐するが、FW更新待ち状態でない場合はイメージアップロードコマンドを受け付けないようにアプリケーション層で制御する方法を検討する必要がある。

**方針**: MCUmgrのイメージグループにはアップロードを制限するフック機構がある（`img_mgmt_upload_check`等）。FW更新待ち状態でない場合はアップロードを拒否するカスタムチェック関数を登録する。

---

## 7. UART共有の考慮事項

### Decision: MCUmgr UART とコンソールログの共存を許容

### Rationale

- nRF52840DKでは `uart0` がコンソールとMCUmgr UARTの両方に使用される
- SMP フレームはBase64エンコード + `\n` 区切りのため、ログ出力と混在しても解析可能
- 専用UARTを使用するにはハードウェア変更（2本目のUART接続）が必要で、開発ボードの制約から現実的でない

### 注意点

- FW転送中はログ出力を抑制するとスループットが向上する可能性がある
- デバッグ時はRTTロギング（`CONFIG_LOG_BACKEND_RTT=y`）の併用を検討

---

## 8. FWサイズ超過時の挙動（T044b）

### Decision: slot1容量超過イメージはMCUmgr IMG管理で拒否される

### 調査結果

- `external/zephyr/include/zephyr/mgmt/mcumgr/grp/img_mgmt/img_mgmt.h` の `img_mgmt_err_code_t` に、サイズ超過を表す `IMG_MGMT_ERR_INVALID_IMAGE_TOO_LARGE` が定義されている
- `external/zephyr/subsys/mgmt/mcumgr/grp/img_mgmt/src/img_mgmt.c` には、verbose error文字列として `img too large` が実装されている
- 同実装は書き込み対象スロット（未使用slot）とフラッシュ領域サイズを管理しており、容量不整合時はIMG管理エラーとして応答する設計

### 結論

- 本機能では、`slot1(472KB)` を超えるイメージ送信時にアプリ側で独自サイズ判定を追加しなくても、MCUmgr IMG管理レイヤーで拒否される
- 運用上は、失敗通知（LED4 5回点滅）へ遷移する統合処理（`UART_DISCONNECT`/IMGエラー時）を `main.c` 側で担保する
