#include "fw_update.h"

#include <dk_buttons_and_leds.h>
#include <zephyr/kernel.h>

static fw_update_state_t current_state = FW_UPDATE_STATE_IDLE;

void fw_update_init(void)
{
	current_state = FW_UPDATE_STATE_IDLE;
}

fw_update_state_t fw_update_get_state(void)
{
	return current_state;
}

fw_update_state_t fw_update_process_event(fw_update_event_t event)
{
	switch (current_state) {
	case FW_UPDATE_STATE_IDLE:
		if (event == FW_UPDATE_EVT_BUTTON4_PRESS) {
			current_state = FW_UPDATE_STATE_WAITING;
		}
		break;
	case FW_UPDATE_STATE_WAITING:
		if (event == FW_UPDATE_EVT_BUTTON4_PRESS ||
		    event == FW_UPDATE_EVT_TIMEOUT) {
			current_state = FW_UPDATE_STATE_IDLE;
		} else if (event == FW_UPDATE_EVT_TRANSFER_START) {
			current_state = FW_UPDATE_STATE_TRANSFERRING;
		}
		break;
	case FW_UPDATE_STATE_TRANSFERRING:
		if (event == FW_UPDATE_EVT_TRANSFER_COMPLETE) {
			current_state = FW_UPDATE_STATE_VERIFYING;
		} else if (event == FW_UPDATE_EVT_UART_DISCONNECT) {
			current_state = FW_UPDATE_STATE_NOTIFY_FAILURE;
		}
		break;
	case FW_UPDATE_STATE_VERIFYING:
		if (event == FW_UPDATE_EVT_VERIFY_SUCCESS) {
			current_state = FW_UPDATE_STATE_NOTIFY_SUCCESS;
		} else if (event == FW_UPDATE_EVT_VERIFY_FAILURE) {
			current_state = FW_UPDATE_STATE_NOTIFY_FAILURE;
		}
		break;
	case FW_UPDATE_STATE_NOTIFY_SUCCESS:
		if (event == FW_UPDATE_EVT_NOTIFY_DONE) {
			current_state = FW_UPDATE_STATE_IDLE;
		}
		break;
	case FW_UPDATE_STATE_NOTIFY_FAILURE:
		if (event == FW_UPDATE_EVT_NOTIFY_DONE) {
			current_state = FW_UPDATE_STATE_IDLE;
		}
		break;
	default:
		break;
	}

	return current_state;
}

void fw_update_get_led_cmd(fw_update_led_cmd_t *cmd)
{
	if (cmd == NULL) {
		return;
	}

	cmd->led1_on = false;
	cmd->led2_on = false;
	cmd->led3_on = false;
	cmd->led4_on = false;
	cmd->led4_blink = false;
	cmd->led4_blink_interval_ms = 0U;

	switch (current_state) {
	case FW_UPDATE_STATE_WAITING:
	case FW_UPDATE_STATE_TRANSFERRING:
		cmd->led4_blink = true;
		cmd->led4_blink_interval_ms = FW_UPDATE_BLINK_INTERVAL_MS;
		break;
	case FW_UPDATE_STATE_NOTIFY_SUCCESS:
		cmd->led4_on = true;
		break;
	case FW_UPDATE_STATE_NOTIFY_FAILURE:
		cmd->led4_blink = true;
		cmd->led4_blink_interval_ms = FW_UPDATE_BLINK_INTERVAL_MS;
		break;
	default:
		break;
	}
}

bool fw_update_is_button_allowed(uint32_t button_mask)
{
	if (current_state == FW_UPDATE_STATE_IDLE) {
		return true;
	}

	if (current_state == FW_UPDATE_STATE_WAITING &&
	    (button_mask & DK_BTN4_MSK) != 0U) {
		return true;
	}

	return false;
}

bool fw_update_check_timeout(uint32_t elapsed_ms)
{
	if (current_state != FW_UPDATE_STATE_WAITING) {
		return false;
	}

	if (elapsed_ms >= FW_UPDATE_TIMEOUT_MS) {
		fw_update_process_event(FW_UPDATE_EVT_TIMEOUT);
		return true;
	}

	return false;
}
