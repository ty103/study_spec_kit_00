/*
 * LED Toggle Button Application for nRF52840DK
 *
 * Toggles LEDs on button press using dk_buttons_and_leds library.
 * Button N toggles LED N (N = 1..4).
 *
 * Functional Requirements: FR-001 through FR-007
 * See specs/001-led-toggle-button/spec.md for full specification.
 *
 * SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
 */

#include <zephyr/kernel.h>
#include <dk_buttons_and_leds.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(led_toggle, LOG_LEVEL_INF);

/* LED state managed as a bitmask (data-model: ビットマスク管理)
 * Bit 0: LED 1, Bit 1: LED 2, Bit 2: LED 3, Bit 3: LED 4
 * Initial value: 0x00 (all LEDs off) per FR-001
 */
static uint32_t led_state;

/* Button-LED pair mapping for loop-based toggle (FR-002) */
static const uint32_t btn_masks[] = {
	DK_BTN1_MSK, DK_BTN2_MSK, DK_BTN3_MSK, DK_BTN4_MSK
};
static const uint32_t led_masks[] = {
	DK_LED1_MSK, DK_LED2_MSK, DK_LED3_MSK, DK_LED4_MSK
};

static void button_handler(uint32_t button_state, uint32_t has_changed)
{
	/* Detect press-edge only: changed AND currently pressed (FR-006, FR-007) */
	uint32_t pressed = has_changed & button_state;

	if (!pressed) {
		return;
	}

	for (int i = 0; i < ARRAY_SIZE(btn_masks); i++) {
		if (pressed & btn_masks[i]) {
			led_state ^= led_masks[i];
			LOG_INF("Button %d pressed → LED %d %s",
				i + 1, i + 1,
				(led_state & led_masks[i]) ? "ON" : "OFF");
		}
	}

	dk_set_leds(led_state);
}

int main(void)
{
	int err;

	LOG_INF("LED Toggle Button application started");

	/* Initialize LEDs - all OFF (FR-001) */
	err = dk_leds_init();
	if (err) {
		LOG_ERR("dk_leds_init failed (err %d)", err);
		return err;
	}

	/* Explicitly set all LEDs off to guarantee initial state (FR-001) */
	dk_set_leds(0);

	/* Initialize buttons with callback (debounce handled by dk_library) */
	err = dk_buttons_init(button_handler);
	if (err) {
		LOG_ERR("dk_buttons_init failed (err %d)", err);
		return err;
	}

	LOG_INF("All LEDs initialized OFF, led_state=0x%08x", led_state);
	LOG_INF("Buttons ready. Press Button N to toggle LED N.");

	return 0;
}
