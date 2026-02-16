/*
 * LED Toggle Logic Module - Implementation
 *
 * Pure logic: no direct hardware access. All dk_buttons_and_leds
 * bitmask constants are used, but actual GPIO calls remain in main.c.
 *
 * SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
 */

#include "led_toggle.h"
#include <dk_buttons_and_leds.h>

/* LED state managed as a bitmask (data-model: ビットマスク管理)
 * Bit 0: LED 1, Bit 1: LED 2, Bit 2: LED 3, Bit 3: LED 4
 * Initial value: 0x00 (all LEDs off) per FR-001
 */
static uint32_t led_state;

/* Flag: did the last process() call detect a press? */
static int last_had_press;

/* Button-LED pair mapping for loop-based toggle (FR-002) */
static const uint32_t btn_masks[LED_TOGGLE_NUM_PAIRS] = {
	DK_BTN1_MSK, DK_BTN2_MSK, DK_BTN3_MSK, DK_BTN4_MSK
};
static const uint32_t led_masks[LED_TOGGLE_NUM_PAIRS] = {
	DK_LED1_MSK, DK_LED2_MSK, DK_LED3_MSK, DK_LED4_MSK
};

void led_toggle_reset(void)
{
	led_state = 0;
	last_had_press = 0;
}

uint32_t led_toggle_get_state(void)
{
	return led_state;
}

uint32_t led_toggle_process(uint32_t button_state, uint32_t has_changed)
{
	/* Detect press-edge only: changed AND currently pressed (FR-006, FR-007) */
	uint32_t pressed = has_changed & button_state;

	if (!pressed) {
		last_had_press = 0;
		return led_state;
	}

	last_had_press = 1;

	for (int i = 0; i < LED_TOGGLE_NUM_PAIRS; i++) {
		if (pressed & btn_masks[i]) {
			led_state ^= led_masks[i]; /* FR-003: toggle */
		}
	}

	return led_state;
}

int led_toggle_had_press(void)
{
	return last_had_press;
}
