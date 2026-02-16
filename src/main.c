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

#include "led_toggle.h"

LOG_MODULE_REGISTER(led_toggle, LOG_LEVEL_INF);

static void button_handler(uint32_t button_state, uint32_t has_changed)
{
	uint32_t new_state = led_toggle_process(button_state, has_changed);

	if (!led_toggle_had_press()) {
		return;
	}

	/* Log individual button presses for debugging */
	if (has_changed & button_state & DK_BTN1_MSK) {
		LOG_INF("Button 1 pressed → LED 1 %s",
			(new_state & DK_LED1_MSK) ? "ON" : "OFF");
	}
	if (has_changed & button_state & DK_BTN2_MSK) {
		LOG_INF("Button 2 pressed → LED 2 %s",
			(new_state & DK_LED2_MSK) ? "ON" : "OFF");
	}
	if (has_changed & button_state & DK_BTN3_MSK) {
		LOG_INF("Button 3 pressed → LED 3 %s",
			(new_state & DK_LED3_MSK) ? "ON" : "OFF");
	}
	if (has_changed & button_state & DK_BTN4_MSK) {
		LOG_INF("Button 4 pressed → LED 4 %s",
			(new_state & DK_LED4_MSK) ? "ON" : "OFF");
	}

	dk_set_leds(new_state);
}

int main(void)
{
	int err;

	LOG_INF("LED Toggle Button application started");

	/* Initialize LED toggle logic — all OFF (FR-001) */
	led_toggle_reset();

	/* Initialize LEDs hardware — all OFF (FR-001) */
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

	LOG_INF("All LEDs initialized OFF, led_state=0x%08x",
		led_toggle_get_state());
	LOG_INF("Buttons ready. Press Button N to toggle LED N.");

	return 0;
}
