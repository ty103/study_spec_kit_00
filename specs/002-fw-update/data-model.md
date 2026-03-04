# Data Model: FW更新機能

**Feature**: 002-fw-update  
**Date**: 2026-02-27

## エンティティ定義

### 1. FW更新状態（fw_update_state_t）

FW更新モジュールの動作状態を表す列挙型。

| 状態 | 値 | 説明 |
|------|----|----|
| `FW_UPDATE_STATE_IDLE` | 0 | 通常動作（FW更新待ちでない） |
| `FW_UPDATE_STATE_WAITING` | 1 | FW更新待ち状態（ボタン4押下後、通信待機中） |
| `FW_UPDATE_STATE_TRANSFERRING` | 2 | FW転送中（MCUmgr通信開始後） |
| `FW_UPDATE_STATE_VERIFYING` | 3 | 検証中（転送完了後、MCUbootによる検証） |
| `FW_UPDATE_STATE_NOTIFY_SUCCESS` | 4 | 成功通知中（LED4を3秒間点灯） |
| `FW_UPDATE_STATE_NOTIFY_FAILURE` | 5 | 失敗通知中（LED4を5回速く点滅） |

### 2. FW更新イベント（fw_update_event_t）

状態遷移をトリガーするイベント。

| イベント | 値 | 説明 |
|----------|----|----|
| `FW_UPDATE_EVT_BUTTON4_PRESS` | 0 | ボタン4が押された |
| `FW_UPDATE_EVT_TRANSFER_START` | 1 | MCUmgr通信が開始された |
| `FW_UPDATE_EVT_TRANSFER_COMPLETE` | 2 | FW転送が完了した |
| `FW_UPDATE_EVT_VERIFY_SUCCESS` | 3 | 整合性検証に成功した |
| `FW_UPDATE_EVT_VERIFY_FAILURE` | 4 | 整合性検証に失敗した |
| `FW_UPDATE_EVT_TIMEOUT` | 5 | 30秒タイムアウト発生 |
| `FW_UPDATE_EVT_UART_DISCONNECT` | 6 | UART接続が切断された |
| `FW_UPDATE_EVT_NOTIFY_DONE` | 7 | 通知パターン表示が完了した |

### 3. LED制御指示（fw_update_led_cmd_t）

FW更新モジュールからアプリケーション層に伝達するLED制御指示。

| フィールド | 型 | 説明 |
|-----------|----|----|
| `led1_on` | bool | LED1の点灯状態 |
| `led2_on` | bool | LED2の点灯状態 |
| `led3_on` | bool | LED3の点灯状態 |
| `led4_on` | bool | LED4の点灯状態 |
| `led4_blink` | bool | LED4の点滅有効/無効 |
| `led4_blink_interval_ms` | uint32_t | LED4の点滅間隔（ms） |

## 状態遷移表

| 現在の状態 | イベント | 次の状態 | アクション |
|-----------|---------|---------|-----------|
| IDLE | BUTTON4_PRESS | WAITING | LED1〜3消灯、LED4高速点滅開始、30秒タイマー開始 |
| WAITING | BUTTON4_PRESS | IDLE | LED4点滅停止、全LED消灯、タイマー停止 |
| WAITING | TRANSFER_START | TRANSFERRING | タイマー停止 |
| WAITING | TIMEOUT | IDLE | LED4点滅停止、全LED消灯 |
| WAITING | BTN1/2/3 | WAITING | 操作無視（状態変化なし） |
| TRANSFERRING | TRANSFER_COMPLETE | VERIFYING | — |
| TRANSFERRING | UART_DISCONNECT | NOTIFY_FAILURE | 失敗通知パターン開始 |
| TRANSFERRING | BUTTON4_PRESS | TRANSFERRING | 操作無視（転送継続） |
| VERIFYING | VERIFY_SUCCESS | NOTIFY_SUCCESS | 成功通知パターン開始（LED4を3秒点灯） |
| VERIFYING | VERIFY_FAILURE | NOTIFY_FAILURE | 失敗通知パターン開始（LED4を5回速く点滅） |
| NOTIFY_SUCCESS | NOTIFY_DONE | — | デバイス再起動（MCUboot swap実行） |
| NOTIFY_FAILURE | NOTIFY_DONE | IDLE | 全LED消灯、通常動作に復帰 |

## 関係図

```
┌─────────────────────────────────────────────────────┐
│                    main.c（統合層）                   │
│  ┌──────────────┐  ┌─────────────────┐              │
│  │ dk_buttons   │  │ MCUmgr SMP     │              │
│  │ _and_leds    │  │ (UART)         │              │
│  └──────┬───────┘  └───────┬─────────┘              │
│         │ボタンイベント      │転送イベント              │
│         ▼                   ▼                        │
│  ┌──────────────────────────────────────┐            │
│  │       fw_update.c / fw_update.h      │            │
│  │  ・状態遷移管理                       │            │
│  │  ・タイムアウト判定                   │            │
│  │  ・ボタンフィルタリング               │            │
│  │  ・LED制御指示生成                    │            │
│  └──────────────┬───────────────────────┘            │
│                  │LED制御指示                         │
│                  ▼                                   │
│  ┌──────────────────────────┐                        │
│  │  dk_set_leds() / Timer   │                        │
│  └──────────────────────────┘                        │
│                                                      │
│  ┌──────────────────────────┐                        │
│  │  led_toggle.c（既存）    │ ← IDLE状態時のみ有効    │
│  └──────────────────────────┘                        │
└─────────────────────────────────────────────────────┘
```

## バリデーションルール

- 状態遷移は定義された遷移表に従い、未定義の遷移は無視する（エラーにしない）
- タイムアウト値は30,000ms（30秒）固定
- LED4高速点滅間隔は100ms固定（200ms周期：点灯100ms/消灯100ms）
- 成功通知のLED4点灯時間は3,000ms固定
- 失敗通知のLED4点滅は5回（100ms間隔 = 合計1,000ms）
- ボタン4のチャタリング防止はdk_buttons_and_ledsライブラリの`CONFIG_DK_LIBRARY_BUTTON_SCAN_INTERVAL=15`に依存
