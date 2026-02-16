/*
 * Unit Tests for LED Toggle Logic Module
 *
 * Tests the pure toggle logic in led_toggle.c without hardware.
 * Uses Zephyr ztest framework on native_sim target (Linux/Docker).
 *
 * Coverage:
 *   FR-001: Initial LED state (all off)
 *   FR-002: Button N → LED N mapping (1:1)
 *   FR-003: Toggle on each press
 *   FR-005: Independent per-pair operation
 *   FR-006: Press-edge detection only
 *   FR-007: Single toggle on long press
 *
 * SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
 */

#include <zephyr/ztest.h>
#include <dk_buttons_and_leds.h>

#include "led_toggle.h"

/* ---------- Suite setup: reset state before each test ---------- */

static void before_each(void *f)
{
	ARG_UNUSED(f);
	led_toggle_reset();
}

ZTEST_SUITE(led_toggle_init, NULL, NULL, before_each, NULL, NULL);
ZTEST_SUITE(led_toggle_single, NULL, NULL, before_each, NULL, NULL);
ZTEST_SUITE(led_toggle_multi, NULL, NULL, before_each, NULL, NULL);
ZTEST_SUITE(led_toggle_edge, NULL, NULL, before_each, NULL, NULL);

/* ================================================================
 * Suite: led_toggle_init — FR-001 初期状態テスト
 * ================================================================ */

/* FR-001: reset後の状態は0（全LED消灯） */
ZTEST(led_toggle_init, test_reset_sets_all_leds_off)
{
	zassert_equal(led_toggle_get_state(), 0,
		      "After reset, LED state must be 0");
}

/* FR-001: reset後にhad_pressはfalse */
ZTEST(led_toggle_init, test_reset_clears_press_flag)
{
	zassert_equal(led_toggle_had_press(), 0,
		      "After reset, had_press must be false");
}

/* FR-001: 何らかの状態からresetすると0に戻る */
ZTEST(led_toggle_init, test_reset_from_nonzero_state)
{
	/* まずLED1をONにする */
	led_toggle_process(DK_BTN1_MSK, DK_BTN1_MSK);
	zassert_not_equal(led_toggle_get_state(), 0);

	/* リセット */
	led_toggle_reset();
	zassert_equal(led_toggle_get_state(), 0,
		      "Reset must return to all-off state");
}

/* ================================================================
 * Suite: led_toggle_single — FR-002, FR-003 単一ボタントグルテスト
 * ================================================================ */

/* FR-003: Button1押下でLED1が点灯 */
ZTEST(led_toggle_single, test_button1_toggles_led1_on)
{
	uint32_t state = led_toggle_process(DK_BTN1_MSK, DK_BTN1_MSK);

	zassert_equal(state, DK_LED1_MSK,
		      "Button 1 press should turn LED 1 ON");
	zassert_equal(led_toggle_get_state(), DK_LED1_MSK);
	zassert_equal(led_toggle_had_press(), 1);
}

/* FR-003: Button1再押下でLED1が消灯 */
ZTEST(led_toggle_single, test_button1_toggles_led1_off)
{
	led_toggle_process(DK_BTN1_MSK, DK_BTN1_MSK); /* ON */
	uint32_t state = led_toggle_process(DK_BTN1_MSK, DK_BTN1_MSK); /* OFF */

	zassert_equal(state, 0,
		      "Second Button 1 press should turn LED 1 OFF");
}

/* FR-002: Button2 → LED2 */
ZTEST(led_toggle_single, test_button2_toggles_led2)
{
	uint32_t state = led_toggle_process(DK_BTN2_MSK, DK_BTN2_MSK);

	zassert_equal(state, DK_LED2_MSK,
		      "Button 2 press should turn LED 2 ON");
}

/* FR-002: Button3 → LED3 */
ZTEST(led_toggle_single, test_button3_toggles_led3)
{
	uint32_t state = led_toggle_process(DK_BTN3_MSK, DK_BTN3_MSK);

	zassert_equal(state, DK_LED3_MSK,
		      "Button 3 press should turn LED 3 ON");
}

/* FR-002: Button4 → LED4 */
ZTEST(led_toggle_single, test_button4_toggles_led4)
{
	uint32_t state = led_toggle_process(DK_BTN4_MSK, DK_BTN4_MSK);

	zassert_equal(state, DK_LED4_MSK,
		      "Button 4 press should turn LED 4 ON");
}

/* FR-003: 10回連続トグルの正確性（SC-003 連打耐性） */
ZTEST(led_toggle_single, test_ten_consecutive_toggles)
{
	for (int i = 0; i < 10; i++) {
		led_toggle_process(DK_BTN1_MSK, DK_BTN1_MSK);
	}

	/* 10回トグル = 偶数回 → 最終状態はOFF */
	zassert_equal(led_toggle_get_state(), 0,
		      "10 toggles (even) should result in LED OFF");
}

/* FR-003: 奇数回トグルの正確性 */
ZTEST(led_toggle_single, test_odd_toggles_result_in_on)
{
	for (int i = 0; i < 7; i++) {
		led_toggle_process(DK_BTN1_MSK, DK_BTN1_MSK);
	}

	/* 7回トグル = 奇数回 → 最終状態はON */
	zassert_equal(led_toggle_get_state(), DK_LED1_MSK,
		      "7 toggles (odd) should result in LED ON");
}

/* ================================================================
 * Suite: led_toggle_multi — FR-005 独立動作テスト
 * ================================================================ */

/* FR-005: Button1操作がLED2に影響しない */
ZTEST(led_toggle_multi, test_button1_does_not_affect_led2)
{
	led_toggle_process(DK_BTN1_MSK, DK_BTN1_MSK);

	zassert_true(led_toggle_get_state() & DK_LED1_MSK,
		     "LED 1 should be ON");
	zassert_false(led_toggle_get_state() & DK_LED2_MSK,
		      "LED 2 should remain OFF");
	zassert_false(led_toggle_get_state() & DK_LED3_MSK,
		      "LED 3 should remain OFF");
	zassert_false(led_toggle_get_state() & DK_LED4_MSK,
		      "LED 4 should remain OFF");
}

/* FR-005: 複数ボタンを順次操作して独立性を確認 */
ZTEST(led_toggle_multi, test_independent_sequential_operation)
{
	/* Button 1 → LED 1 ON */
	led_toggle_process(DK_BTN1_MSK, DK_BTN1_MSK);
	zassert_equal(led_toggle_get_state(), DK_LED1_MSK);

	/* Button 3 → LED 1 ON, LED 3 ON */
	led_toggle_process(DK_BTN3_MSK, DK_BTN3_MSK);
	zassert_equal(led_toggle_get_state(), DK_LED1_MSK | DK_LED3_MSK,
		      "LED 1 and LED 3 should both be ON");

	/* Button 1 → LED 1 OFF, LED 3 ON */
	led_toggle_process(DK_BTN1_MSK, DK_BTN1_MSK);
	zassert_equal(led_toggle_get_state(), DK_LED3_MSK,
		      "LED 1 OFF, LED 3 should remain ON");
}

/* FR-005: 全LED ON → Button2のみ → LED2のみOFF */
ZTEST(led_toggle_multi, test_all_on_then_toggle_one_off)
{
	/* 全ボタンを押して全LED ON */
	led_toggle_process(DK_BTN1_MSK, DK_BTN1_MSK);
	led_toggle_process(DK_BTN2_MSK, DK_BTN2_MSK);
	led_toggle_process(DK_BTN3_MSK, DK_BTN3_MSK);
	led_toggle_process(DK_BTN4_MSK, DK_BTN4_MSK);

	uint32_t all_on = DK_LED1_MSK | DK_LED2_MSK | DK_LED3_MSK | DK_LED4_MSK;

	zassert_equal(led_toggle_get_state(), all_on, "All LEDs should be ON");

	/* Button 2 → LED 2 OFF */
	led_toggle_process(DK_BTN2_MSK, DK_BTN2_MSK);
	zassert_equal(led_toggle_get_state(),
		      DK_LED1_MSK | DK_LED3_MSK | DK_LED4_MSK,
		      "Only LED 2 should be OFF after toggling Button 2");
}

/* FR-005: 複数ボタン同時押し */
ZTEST(led_toggle_multi, test_simultaneous_button_press)
{
	uint32_t both_btns = DK_BTN1_MSK | DK_BTN3_MSK;

	uint32_t state = led_toggle_process(both_btns, both_btns);

	zassert_equal(state, DK_LED1_MSK | DK_LED3_MSK,
		      "Simultaneous Button 1+3 should toggle LED 1+3");
	zassert_false(state & DK_LED2_MSK, "LED 2 should remain OFF");
	zassert_false(state & DK_LED4_MSK, "LED 4 should remain OFF");
}

/* ================================================================
 * Suite: led_toggle_edge — FR-006, FR-007 エッジ検出テスト
 * ================================================================ */

/* FR-006: ボタンリリース（button_state=0）では反応しない */
ZTEST(led_toggle_edge, test_release_does_not_toggle)
{
	/* リリースイベント: has_changed=BTN1, button_state=0 (released) */
	led_toggle_process(0, DK_BTN1_MSK);

	zassert_equal(led_toggle_get_state(), 0,
		      "Button release should not change LED state");
	zassert_equal(led_toggle_had_press(), 0,
		      "Button release should not be detected as press");
}

/* FR-007: 長押し（has_changed=0, button_state=BTN1）では反応しない */
ZTEST(led_toggle_edge, test_held_button_does_not_retoggle)
{
	/* 最初の押下 */
	led_toggle_process(DK_BTN1_MSK, DK_BTN1_MSK);
	zassert_equal(led_toggle_get_state(), DK_LED1_MSK, "First press: ON");

	/* ボタン保持中（has_changed=0 → pressed=0） */
	led_toggle_process(DK_BTN1_MSK, 0);
	zassert_equal(led_toggle_get_state(), DK_LED1_MSK,
		      "Holding button should not re-toggle");
	zassert_equal(led_toggle_had_press(), 0,
		      "Holding should not count as press");
}

/* FR-006: 変化のないボタンは無視 */
ZTEST(led_toggle_edge, test_no_change_no_toggle)
{
	led_toggle_process(0, 0);

	zassert_equal(led_toggle_get_state(), 0,
		      "No button change should not affect state");
	zassert_equal(led_toggle_had_press(), 0);
}

/* FR-006: 押下と同時にリリースが混在するケース */
ZTEST(led_toggle_edge, test_mixed_press_and_release)
{
	/* Button1を先にONにしておく */
	led_toggle_process(DK_BTN1_MSK, DK_BTN1_MSK);
	zassert_equal(led_toggle_get_state(), DK_LED1_MSK);

	/* Button1をリリース(has_changed=BTN1, state=0) + Button2を押下(has_changed=BTN2, state=BTN2) */
	/* combined: button_state=BTN2, has_changed=BTN1|BTN2 */
	uint32_t state = led_toggle_process(DK_BTN2_MSK,
					    DK_BTN1_MSK | DK_BTN2_MSK);

	/* Button1リリースは無視、Button2押下のみ反応 */
	zassert_equal(state, DK_LED1_MSK | DK_LED2_MSK,
		      "Should toggle LED2 ON, LED1 stays ON (release ignored)");
}

/* Edge case: 全ボタン同時押下 */
ZTEST(led_toggle_edge, test_all_buttons_simultaneous)
{
	uint32_t all_btns = DK_BTN1_MSK | DK_BTN2_MSK | DK_BTN3_MSK | DK_BTN4_MSK;
	uint32_t all_leds = DK_LED1_MSK | DK_LED2_MSK | DK_LED3_MSK | DK_LED4_MSK;

	uint32_t state = led_toggle_process(all_btns, all_btns);

	zassert_equal(state, all_leds,
		      "All 4 buttons pressed simultaneously should turn all LEDs ON");
}
