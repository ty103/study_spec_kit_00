# Implementation Plan: FW更新機能

**Branch**: `002-fw-update` | **Date**: 2026-02-27 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-fw-update/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

ボタン4の押下でFW更新待ちモードに遷移し、MCUmgr（SMP over UART）プロトコルを使用してPC側からファームウェアイメージを受信・検証・適用する機能を実装する。NCS標準のMCUboot + MCUmgrスタックを活用し、アプリケーション層でモード切替（ボタン4）、LED表示制御、タイムアウト（30秒）、ボタン操作制限、成功/失敗通知のLEDパターン表示を実装する。

## Technical Context

**Language/Version**: C（C99/C11）  
**Primary Dependencies**: Zephyr RTOS, nRF Connect SDK v3.2.2, MCUboot, MCUmgr（SMP over UART）, `dk_buttons_and_leds` ライブラリ  
**Storage**: Flash（MCUbootデュアルスロット：プライマリ/セカンダリイメージスロット）  
**Testing**: ztest + Twister、`native_sim` ボードターゲット  
**Target Platform**: nRF52840DK（PCA10056）  
**Project Type**: single — 組込みファームウェア（Zephyr RTOS）  
**Performance Goals**: ボタン押下から状態遷移まで1秒以内、FW転送・検証・適用・再起動が3分以内  
**Constraints**: nRF52840 RAM 256KB（80%上限: 204KB）、Flash 1MB（80%上限: 819KB）。MCUboot + MCUmgr追加によるメモリ増加を計測・記録する必要あり  
**Scale/Scope**: 単一デバイス、UARTシリアル接続のPC1台との1対1通信

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 準拠状況 | 詳細 |
|------|---------|------|
| I. ロジック分離 | ✅ PASS | FW更新モード管理ロジック（状態遷移、タイムアウト、ボタン制御、LED通知パターン）を `src/fw_update.c` / `src/fw_update.h` として分離する。MCUmgr/MCUboot連携は `main.c` の統合レイヤーに閉じ込める |
| II. テスト先行 | ✅ PASS | FW更新モード管理の純粋ロジック（状態遷移、タイムアウト判定、ボタンフィルタリング、LED通知パターン生成）はztest + native_simでテスト可能。MCUmgr統合はスタブ化 |
| III. 仕様駆動開発 | ✅ PASS | spec.md → plan.md → tasks.md の順序に従っている。FR-001〜FR-014、SC-001〜SC-006が定義済み |
| IV. クロスプラットフォーム検証 | ✅ PASS | 純粋ロジックはnative_simで検証。docker compose run --rm testで実行。MCUmgr統合テストは実機のみ |
| V. シンプルさと段階的拡張 | ✅ PASS | NCS標準のMCUboot + MCUmgrを活用し、独自プロトコル実装を避ける。必要最小限のアプリケーション層コードのみ追加 |
| VI. メモリバジェット管理 | ✅ PASS（要実測） | research.mdで分析完了。MCUmgrアプリ側オーバーヘッド推定: Flash ~16-26KB, RAM ~4-5KB。slot0最大472KB中の推定使用量は閾値(377KB)以内。スタックサイズ: MAIN=2176, SYSTEM_WQ=2304（MCUmgrサンプル準拠、根拠をresearch.mdに記録済み）。ビルド後に `west build -t rom_report / ram_report` で実測し確認する |

**ゲート判定**: PASS — 全原則に準拠。原則VIのメモリバジェットはresearch.mdで推定分析済み、ビルド後に実測で最終確認する。

## Project Structure

### Documentation (this feature)

```text
specs/002-fw-update/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
src/
├── main.c               # 既存 — ボタンハンドラ統合、MCUmgr初期化・制御追加
├── led_toggle.c         # 既存 — 変更なし
├── led_toggle.h         # 既存 — 変更なし
├── fw_update.c          # 新規 — FW更新モード管理ロジック（状態遷移、タイムアウト、LED通知）
└── fw_update.h          # 新規 — FW更新モード管理のパブリックAPI

tests/unit/
├── src/
│   ├── led_toggle_test.c    # 既存 — 変更なし
│   └── fw_update_test.c     # 新規 — FW更新ロジックのユニットテスト
├── stubs/
│   └── (既存スタブ)
├── CMakeLists.txt           # 更新 — fw_update.c, fw_update_test.cを追加
├── prj.conf                 # 更新 — 必要に応じて設定追加
└── testcase.yaml            # 更新 — FW更新テストスイート追加
```

**Structure Decision**: 既存の単一プロジェクト構造を維持。FW更新モード管理ロジックを `fw_update.c` / `fw_update.h` として原則Iに基づき分離。MCUboot/MCUmgrの有効化はビルド設定（`prj.conf`, `CMakeLists.txt`）の変更で対応し、新規ディレクトリの追加は不要。

## Complexity Tracking

> MCUboot + MCUmgr有効化による複雑性増加を記録

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| MCUboot有効化（sysbuild） | UARTブートローダーによるFW更新の前提条件。FR-007〜FR-009の整合性検証・適用・保護に必須 | 独自ブートローダー実装はNCS標準活用の方針（FR-011）に反し、複雑さが桁違いに増大する |
| MCUmgr SMP over UART追加 | FR-003のUART経由FW受信に必須。NCS標準のDFUプロトコル | 独自UARTプロトコル実装はバグリスクが高く、PC側ツールも自作が必要になる |
