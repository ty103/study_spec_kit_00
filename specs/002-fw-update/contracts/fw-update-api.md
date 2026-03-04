# API Contract: fw_update モジュール

**Feature**: 002-fw-update  
**Date**: 2026-02-27  
**Type**: C ヘッダ API（内部モジュール間インターフェース）

## 概要

FW更新モード管理ロジックのパブリックAPI定義。ハードウェア非依存の純粋ロジックとして設計し、`native_sim` でのユニットテストを可能にする。

---

## fw_update.h API定義

```c
/*
 * FW Update Mode Management Module
 *
 * ハードウェア非依存のFW更新モード管理ロジック。
 * 状態遷移、タイムアウト判定、ボタンフィルタリング、LED制御指示を提供する。
 *
 * Functional Requirements: FR-001 through FR-014
 * See specs/002-fw-update/spec.md for full specification.
 *
 * SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
 */

#ifndef FW_UPDATE_H_
#define FW_UPDATE_H_

#include <stdint.h>
#include <stdbool.h>

/* ====== 型定義 ====== */

/** FW更新モジュールの状態 */
typedef enum {
    FW_UPDATE_STATE_IDLE = 0,             /**< 通常動作 */
    FW_UPDATE_STATE_WAITING,              /**< FW更新待ち */
    FW_UPDATE_STATE_TRANSFERRING,         /**< FW転送中 */
    FW_UPDATE_STATE_VERIFYING,            /**< 検証中 */
    FW_UPDATE_STATE_NOTIFY_SUCCESS,       /**< 成功通知中 */
    FW_UPDATE_STATE_NOTIFY_FAILURE,       /**< 失敗通知中 */
} fw_update_state_t;

/** 状態遷移をトリガーするイベント */
typedef enum {
    FW_UPDATE_EVT_BUTTON4_PRESS = 0,      /**< ボタン4押下 */
    FW_UPDATE_EVT_TRANSFER_START,         /**< MCUmgr通信開始 */
    FW_UPDATE_EVT_TRANSFER_COMPLETE,      /**< FW転送完了 */
    FW_UPDATE_EVT_VERIFY_SUCCESS,         /**< 整合性検証成功 */
    FW_UPDATE_EVT_VERIFY_FAILURE,         /**< 整合性検証失敗 */
    FW_UPDATE_EVT_TIMEOUT,                /**< 30秒タイムアウト */
    FW_UPDATE_EVT_UART_DISCONNECT,        /**< UART接続切断 */
    FW_UPDATE_EVT_NOTIFY_DONE,            /**< 通知パターン完了 */
} fw_update_event_t;

/** LED制御指示 */
typedef struct {
    bool led1_on;                         /**< LED1 点灯状態 */
    bool led2_on;                         /**< LED2 点灯状態 */
    bool led3_on;                         /**< LED3 点灯状態 */
    bool led4_on;                         /**< LED4 点灯状態 */
    bool led4_blink;                      /**< LED4 点滅有効 */
    uint32_t led4_blink_interval_ms;      /**< LED4 点滅間隔(ms) */
} fw_update_led_cmd_t;

/* ====== 定数 ====== */

/** FW更新待ちタイムアウト時間 (ms) */
#define FW_UPDATE_TIMEOUT_MS        30000

/** LED4 高速点滅間隔 (ms) — 200ms周期 */
#define FW_UPDATE_BLINK_INTERVAL_MS 100

/** 成功通知のLED4点灯時間 (ms) */
#define FW_UPDATE_SUCCESS_DURATION_MS 3000

/** 失敗通知のLED4点滅回数 */
#define FW_UPDATE_FAILURE_BLINK_COUNT 5

/* ====== 関数 ====== */

/**
 * @brief FW更新モジュールを初期化する。
 *
 * 内部状態をIDLEにリセットする。アプリケーション起動時に呼び出す。
 */
void fw_update_init(void);

/**
 * @brief 現在のFW更新状態を取得する。
 *
 * @return 現在の状態（fw_update_state_t）。
 */
fw_update_state_t fw_update_get_state(void);

/**
 * @brief イベントを処理し、状態遷移を行う。
 *
 * イベントに基づいて状態遷移を実行し、新しい状態を返す。
 * 未定義の遷移（現在の状態で受け付けないイベント）は無視される。
 *
 * @param event  処理するイベント。
 * @return 遷移後の状態。遷移しなかった場合は現在の状態。
 */
fw_update_state_t fw_update_process_event(fw_update_event_t event);

/**
 * @brief 現在の状態に基づくLED制御指示を取得する。
 *
 * @param[out] cmd  LED制御指示の格納先。
 */
void fw_update_get_led_cmd(fw_update_led_cmd_t *cmd);

/**
 * @brief 現在の状態でボタン操作が許可されているか判定する。
 *
 * ボタン1〜3の操作はIDLE状態でのみ許可される。
 * ボタン4の操作はIDLE状態（モード切替開始）とWAITING状態（キャンセル）で許可される。
 *
 * @param button_mask  判定するボタンのビットマスク。
 * @return true: 操作許可、false: 操作拒否（無視すべき）。
 */
bool fw_update_is_button_allowed(uint32_t button_mask);

/**
 * @brief タイムアウトを確認する。
 *
 * 現在の経過時間をもとにタイムアウトを判定する。
 * WAITING状態でタイムアウトが発生した場合、内部的にTIMEOUTイベントを処理する。
 *
 * @param elapsed_ms  FW更新待ち状態に入ってからの経過時間(ms)。
 * @return true: タイムアウトが発生した、false: タイムアウト未発生。
 */
bool fw_update_check_timeout(uint32_t elapsed_ms);

#endif /* FW_UPDATE_H_ */
```

---

## 呼び出しフロー

### 1. 初期化（main.c）

```
main()
  → fw_update_init()
  → boot_is_img_confirmed() / boot_write_img_confirmed()  [MCUboot API]
  → dk_buttons_and_leds_init()
  → MCUmgr SMP サーバー自動起動（Kconfig設定による）
```

### 2. ボタン押下時（button_handler callback）

```
button_handler(button_state, has_changed)
  → fw_update_is_button_allowed(button_mask)
    → false → 操作を無視して return
    → true  → ボタン処理続行
  → [ボタン4の場合] fw_update_process_event(FW_UPDATE_EVT_BUTTON4_PRESS)
  → [ボタン1〜3の場合] led_toggle_process()  (既存ロジック、IDLE状態時のみ)
  → fw_update_get_led_cmd(&cmd) → dk_set_leds() で反映
```

### 3. MCUmgr イベント時（upload check callback）

```
mcumgr_img_upload_check()
  → fw_update_get_state() == FW_UPDATE_STATE_WAITING ?
    → yes → fw_update_process_event(FW_UPDATE_EVT_TRANSFER_START), return ALLOW
    → no  → return DENY
```

### 4. タイムアウト検査（Zephyr timer / work handler）

```
timeout_work_handler()
  → fw_update_check_timeout(elapsed_ms)
    → true → fw_update_get_led_cmd(&cmd) → dk_set_leds() で反映
```

---

## エラーハンドリング規約

| シナリオ | 動作 |
|---------|------|
| 未定義の状態遷移 | 無視（現在の状態を維持、ログ出力） |
| fw_update_get_led_cmd に NULL を渡す | 何もしない（防御的プログラミング） |
| 不正なイベント値 | 無視（現在の状態を維持） |
| MCUmgr通信エラー | UART_DISCONNECT イベントとして処理 |
