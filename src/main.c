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
#include <zephyr/dfu/mcuboot.h>
#include <zephyr/sys/reboot.h>
#include <errno.h>
#include <dk_buttons_and_leds.h>
#include <zephyr/logging/log.h>

#include "fw_update.h"
#include "led_toggle.h"

LOG_MODULE_REGISTER(led_toggle, LOG_LEVEL_INF);

static struct k_work_delayable fw_timeout_work;
static struct k_work_delayable fw_led_work;
static uint32_t fw_waiting_start_ms;
static bool fw_led4_level;
static uint32_t fw_failure_toggle_count;

static void apply_leds_from_mode(void)
{
	fw_update_state_t state = fw_update_get_state();
	fw_update_led_cmd_t cmd = { 0 };
	uint32_t mask = led_toggle_get_state();

	if (state == FW_UPDATE_STATE_IDLE) {
		dk_set_leds(mask);
		return;
	}

	fw_update_get_led_cmd(&cmd);
	mask = 0U;

	if (cmd.led1_on) {
		mask |= DK_LED1_MSK;
	}
	if (cmd.led2_on) {
		mask |= DK_LED2_MSK;
	}
	if (cmd.led3_on) {
		mask |= DK_LED3_MSK;
	}
	if (cmd.led4_on) {
		mask |= DK_LED4_MSK;
	}
	if (cmd.led4_blink && fw_led4_level) {
		mask |= DK_LED4_MSK;
	}

	dk_set_leds(mask);
}

static void schedule_led_worker(void)
{
	fw_update_state_t state = fw_update_get_state();

	if (state == FW_UPDATE_STATE_WAITING ||
	    state == FW_UPDATE_STATE_TRANSFERRING ||
	    state == FW_UPDATE_STATE_NOTIFY_FAILURE) {
		(void)k_work_reschedule(&fw_led_work,
			K_MSEC(FW_UPDATE_BLINK_INTERVAL_MS));
	} else {
		(void)k_work_cancel_delayable(&fw_led_work);
	}
}

static void finish_notify_success(void)
{
	(void)fw_update_process_event(FW_UPDATE_EVT_NOTIFY_DONE);
	LOG_INF("Firmware update success notification completed. Rebooting.");
	sys_reboot(SYS_REBOOT_WARM);
}

static void fw_led_work_handler(struct k_work *work)
{
	ARG_UNUSED(work);

	fw_update_state_t state = fw_update_get_state();

	if (state == FW_UPDATE_STATE_WAITING ||
	    state == FW_UPDATE_STATE_TRANSFERRING) {
		fw_led4_level = !fw_led4_level;
		apply_leds_from_mode();
		schedule_led_worker();
		return;
	}

	if (state == FW_UPDATE_STATE_NOTIFY_FAILURE) {
		fw_led4_level = !fw_led4_level;
		fw_failure_toggle_count++;
		apply_leds_from_mode();

		if (fw_failure_toggle_count >= (FW_UPDATE_FAILURE_BLINK_COUNT * 2U)) {
			LOG_WRN("Firmware update failure notification completed. Returning to normal operation.");
			(void)fw_update_process_event(FW_UPDATE_EVT_NOTIFY_DONE);
			fw_failure_toggle_count = 0U;
			fw_led4_level = false;
			apply_leds_from_mode();
			return;
		}

		schedule_led_worker();
		return;
	}

	if (state == FW_UPDATE_STATE_NOTIFY_SUCCESS) {
		finish_notify_success();
	}
}

static void fw_timeout_work_handler(struct k_work *work)
{
	ARG_UNUSED(work);

	fw_update_state_t state = fw_update_get_state();

	if (state != FW_UPDATE_STATE_WAITING) {
		return;
	}

	uint32_t elapsed = k_uptime_get_32() - fw_waiting_start_ms;
	if (fw_update_check_timeout(elapsed)) {
		LOG_WRN("Firmware update waiting timeout: %u ms", elapsed);
		fw_led4_level = false;
		apply_leds_from_mode();
		return;
	}

	(void)k_work_reschedule(&fw_timeout_work, K_MSEC(100));
}

static int fw_update_upload_check(void)
{
	if (fw_update_get_state() != FW_UPDATE_STATE_WAITING) {
		LOG_WRN("Upload rejected because the system is not in firmware update waiting state");
		return -EACCES;
	}

	(void)fw_update_process_event(FW_UPDATE_EVT_TRANSFER_START);
	LOG_INF("Firmware transfer started");
	apply_leds_from_mode();
	return 0;
}

static void fw_update_handle_uart_disconnect(void)
{
	if (fw_update_get_state() != FW_UPDATE_STATE_TRANSFERRING) {
		return;
	}

	(void)fw_update_process_event(FW_UPDATE_EVT_UART_DISCONNECT);
	fw_failure_toggle_count = 0U;
	fw_led4_level = false;
	LOG_ERR("UART disconnect detected. Handling firmware update as failure");
	apply_leds_from_mode();
	schedule_led_worker();
}

static void button_handler(uint32_t button_state, uint32_t has_changed)
{
	uint32_t pressed = has_changed & button_state;
	fw_update_state_t before = fw_update_get_state();

	if (pressed & DK_BTN4_MSK) {
		if (fw_update_is_button_allowed(DK_BTN4_MSK)) {
			fw_update_state_t after =
				fw_update_process_event(FW_UPDATE_EVT_BUTTON4_PRESS);

			if (before == FW_UPDATE_STATE_IDLE &&
			    after == FW_UPDATE_STATE_WAITING) {
				fw_waiting_start_ms = k_uptime_get_32();
				fw_led4_level = false;
				LOG_INF("Entered firmware update waiting mode");
				(void)k_work_reschedule(&fw_timeout_work, K_MSEC(100));
				schedule_led_worker();
			} else if (before == FW_UPDATE_STATE_WAITING &&
				   after == FW_UPDATE_STATE_IDLE) {
				LOG_INF("Firmware update waiting mode canceled");
				(void)k_work_cancel_delayable(&fw_timeout_work);
				(void)k_work_cancel_delayable(&fw_led_work);
				fw_led4_level = false;
			}
		} else {
			LOG_WRN("Button 4 operation is invalid in the current state");
		}
	}

	if (pressed & (DK_BTN1_MSK | DK_BTN2_MSK | DK_BTN3_MSK)) {
		if (fw_update_is_button_allowed(pressed)) {
			uint32_t filtered_state = button_state &
				(DK_BTN1_MSK | DK_BTN2_MSK | DK_BTN3_MSK);
			uint32_t filtered_changed = has_changed &
				(DK_BTN1_MSK | DK_BTN2_MSK | DK_BTN3_MSK);
			uint32_t new_state = led_toggle_process(filtered_state,
						       filtered_changed);

			if (led_toggle_had_press()) {
				LOG_INF("Normal LED operation: state=0x%08x", new_state);
			}
		} else {
			LOG_WRN("Ignoring Buttons 1-3 during firmware update");
		}
	}

	fw_update_state_t state = fw_update_get_state();
	if (state == FW_UPDATE_STATE_NOTIFY_SUCCESS) {
		apply_leds_from_mode();
		(void)k_work_reschedule(&fw_led_work,
			K_MSEC(FW_UPDATE_SUCCESS_DURATION_MS));
	} else {
		apply_leds_from_mode();
		schedule_led_worker();
	}
}

int main(void)
{
	int err;

	LOG_INF("LED Toggle Button application started");
	k_work_init_delayable(&fw_timeout_work, fw_timeout_work_handler);
	k_work_init_delayable(&fw_led_work, fw_led_work_handler);

	fw_update_init();

	if (!boot_is_img_confirmed()) {
		err = boot_write_img_confirmed();
		if (err) {
			LOG_ERR("MCUboot confirm failed: %d", err);
		} else {
			LOG_INF("MCUboot confirm completed");
		}
	}

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
	LOG_INF("Press Button 4 to enter firmware update waiting mode");

	ARG_UNUSED(fw_update_upload_check);
	ARG_UNUSED(fw_update_handle_uart_disconnect);

	return 0;
}
