# Implementation Plan: nRF52840DK LED トグル（ボタン操作）

**Branch**: `001-led-toggle-button` | **Date**: 2026-02-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-led-toggle-button/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

nRF52840DK上の4つのボタン（Button 1〜4）で対応するLED（LED 1〜4）をトグル制御するZephyr/nRF Connect SDKアプリケーション。`dk_buttons_and_leds`ライブラリを使用し、デバウンス内蔵のボタンコールバックでLED状態をビットマスク管理する最小構成プロジェクト。

## Technical Context

**Language/Version**: C (C99/C11) - Zephyr RTOS / nRF Connect SDK  
**Primary Dependencies**: Zephyr RTOS, nRF Connect SDK (`dk_buttons_and_leds` ライブラリ)  
**Storage**: N/A（揮発性メモリのみ、永続化不要）  
**Testing**: 実機テスト（目視確認）、Twister（ビルド検証）  
**Target Platform**: nRF52840DK (PCA10056) - ARM Cortex-M4F  
**Project Type**: single（組み込みファームウェア）  
**Performance Goals**: ボタン押下→LED応答 100ms以下  
**Constraints**: デバウンス15ms（dk_libraryデフォルト10msで実効10〜20ms）、GPIO0ポートのみ使用  
**Scale/Scope**: ボタン4個、LED4個、ソースファイル1個（main.c）

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

> **Note**: 憲法ファイル（`.specify/memory/constitution.md`）はテンプレート状態（未設定）のため、プロジェクト固有のルールは定義されていません。デフォルトの健全性チェックを適用します。

| Gate | Pre-Design | Post-Design | Notes |
|------|-----------|-------------|-------|
| 過度な複雑性がないか | ✅ PASS | ✅ PASS | ソースファイル1個、依存ライブラリ1個 |
| 不要な依存関係がないか | ✅ PASS | ✅ PASS | dk_buttons_and_leds のみ（SDK標準） |
| テスト可能性が確保されているか | ✅ PASS | ✅ PASS | quickstart.mdにテストチェックリスト定義済み |
| スコープが仕様に合致しているか | ✅ PASS | ✅ PASS | FR-001〜FR-007すべてカバー |

## Project Structure

### Documentation (this feature)

```text
specs/[###-feature]/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
CMakeLists.txt         # ビルドシステム定義
prj.conf               # Kconfig設定（DK_LIBRARY, GPIO有効化）
src/
└── main.c             # アプリケーションコード（ボタンコールバック + LEDトグル）
```

**Structure Decision**: 組み込みファームウェアの最小構成。nRF Connect SDK / Zephyrの標準プロジェクトレイアウトに準拠。ソースファイルは`src/main.c`の1ファイルで完結する。app.overlayは不要（DTSにLED/ボタン定義済み）。

## Complexity Tracking

> 憲法チェックに違反なし。複雑性の正当化は不要。
