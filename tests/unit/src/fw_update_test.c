#include <zephyr/ztest.h>
#include <dk_buttons_and_leds.h>

#include "fw_update.h"

static void before_each(void *f)
{
	ARG_UNUSED(f);
	fw_update_init();
}

ZTEST_SUITE(fw_update_init, NULL, NULL, before_each, NULL, NULL);
ZTEST_SUITE(fw_update_us1, NULL, NULL, before_each, NULL, NULL);
ZTEST_SUITE(fw_update_us2, NULL, NULL, before_each, NULL, NULL);
ZTEST_SUITE(fw_update_us3, NULL, NULL, before_each, NULL, NULL);
ZTEST_SUITE(fw_update_us4, NULL, NULL, before_each, NULL, NULL);

static void enter_waiting(void)
{
	(void)fw_update_process_event(FW_UPDATE_EVT_BUTTON4_PRESS);
}

static void enter_transferring(void)
{
	enter_waiting();
	(void)fw_update_process_event(FW_UPDATE_EVT_TRANSFER_START);
}

static void enter_verifying(void)
{
	enter_transferring();
	(void)fw_update_process_event(FW_UPDATE_EVT_TRANSFER_COMPLETE);
}

ZTEST(fw_update_init, test_init_starts_idle)
{
	zassert_equal(fw_update_get_state(), FW_UPDATE_STATE_IDLE,
		      "fw_updateは初期状態でIDLEであるべき");
}

ZTEST(fw_update_us1, test_idle_to_waiting_on_button4)
{
	fw_update_state_t state = fw_update_process_event(FW_UPDATE_EVT_BUTTON4_PRESS);

	zassert_equal(state, FW_UPDATE_STATE_WAITING, "IDLE->WAITING遷移失敗");
}

ZTEST(fw_update_us1, test_waiting_to_transferring)
{
	enter_waiting();
	fw_update_state_t state = fw_update_process_event(FW_UPDATE_EVT_TRANSFER_START);

	zassert_equal(state, FW_UPDATE_STATE_TRANSFERRING,
		      "WAITING->TRANSFERRING遷移失敗");
}

ZTEST(fw_update_us1, test_transferring_to_verifying)
{
	enter_transferring();
	fw_update_state_t state =
		fw_update_process_event(FW_UPDATE_EVT_TRANSFER_COMPLETE);

	zassert_equal(state, FW_UPDATE_STATE_VERIFYING,
		      "TRANSFERRING->VERIFYING遷移失敗");
}

ZTEST(fw_update_us1, test_verify_success_flow)
{
	enter_verifying();
	zassert_equal(fw_update_process_event(FW_UPDATE_EVT_VERIFY_SUCCESS),
		      FW_UPDATE_STATE_NOTIFY_SUCCESS,
		      "VERIFYING->NOTIFY_SUCCESS遷移失敗");
	zassert_equal(fw_update_process_event(FW_UPDATE_EVT_NOTIFY_DONE),
		      FW_UPDATE_STATE_IDLE,
		      "NOTIFY_DONE後はIDLEへ復帰するべき");
}

ZTEST(fw_update_us1, test_verify_failure_flow)
{
	enter_verifying();
	zassert_equal(fw_update_process_event(FW_UPDATE_EVT_VERIFY_FAILURE),
		      FW_UPDATE_STATE_NOTIFY_FAILURE,
		      "VERIFYING->NOTIFY_FAILURE遷移失敗");
	zassert_equal(fw_update_process_event(FW_UPDATE_EVT_NOTIFY_DONE),
		      FW_UPDATE_STATE_IDLE,
		      "失敗通知後はIDLEへ復帰するべき");
}

ZTEST(fw_update_us1, test_led_cmd_waiting)
{
	fw_update_led_cmd_t cmd = { 0 };

	enter_waiting();
	fw_update_get_led_cmd(&cmd);

	zassert_false(cmd.led1_on, "LED1は消灯");
	zassert_false(cmd.led2_on, "LED2は消灯");
	zassert_false(cmd.led3_on, "LED3は消灯");
	zassert_false(cmd.led4_on, "LED4固定点灯はしない");
	zassert_true(cmd.led4_blink, "LED4は点滅");
	zassert_equal(cmd.led4_blink_interval_ms, FW_UPDATE_BLINK_INTERVAL_MS,
		      "点滅間隔不一致");
}

ZTEST(fw_update_us1, test_led_cmd_notify_success)
{
	fw_update_led_cmd_t cmd = { 0 };

	enter_verifying();
	(void)fw_update_process_event(FW_UPDATE_EVT_VERIFY_SUCCESS);
	fw_update_get_led_cmd(&cmd);

	zassert_true(cmd.led4_on, "成功通知はLED4点灯");
	zassert_false(cmd.led4_blink, "成功通知は点滅しない");
}

ZTEST(fw_update_us1, test_led_cmd_notify_failure)
{
	fw_update_led_cmd_t cmd = { 0 };

	enter_verifying();
	(void)fw_update_process_event(FW_UPDATE_EVT_VERIFY_FAILURE);
	fw_update_get_led_cmd(&cmd);

	zassert_true(cmd.led4_blink, "失敗通知はLED4点滅");
	zassert_equal(cmd.led4_blink_interval_ms, FW_UPDATE_BLINK_INTERVAL_MS,
		      "失敗点滅間隔不一致");
}

ZTEST(fw_update_us2, test_waiting_cancel_to_idle)
{
	enter_waiting();
	zassert_equal(fw_update_process_event(FW_UPDATE_EVT_BUTTON4_PRESS),
		      FW_UPDATE_STATE_IDLE, "WAITINGキャンセル失敗");
}

ZTEST(fw_update_us2, test_cancel_led_all_off)
{
	fw_update_led_cmd_t cmd = { 0 };

	enter_waiting();
	(void)fw_update_process_event(FW_UPDATE_EVT_BUTTON4_PRESS);
	fw_update_get_led_cmd(&cmd);

	zassert_false(cmd.led1_on, "LED1は消灯");
	zassert_false(cmd.led2_on, "LED2は消灯");
	zassert_false(cmd.led3_on, "LED3は消灯");
	zassert_false(cmd.led4_on, "LED4は消灯");
	zassert_false(cmd.led4_blink, "LED4点滅は停止");
}

ZTEST(fw_update_us2, test_cannot_cancel_while_transferring)
{
	enter_transferring();
	zassert_equal(fw_update_process_event(FW_UPDATE_EVT_BUTTON4_PRESS),
		      FW_UPDATE_STATE_TRANSFERRING,
		      "転送中はキャンセル不可");
}

ZTEST(fw_update_us3, test_timeout_not_triggered_before_30s)
{
	enter_waiting();
	zassert_false(fw_update_check_timeout(29999U), "29999msでは未タイムアウト");
	zassert_equal(fw_update_get_state(), FW_UPDATE_STATE_WAITING,
		      "状態はWAITING維持");
}

ZTEST(fw_update_us3, test_timeout_triggered_at_30s)
{
	enter_waiting();
	zassert_true(fw_update_check_timeout(30000U), "30000msでタイムアウト発生");
	zassert_equal(fw_update_get_state(), FW_UPDATE_STATE_IDLE,
		      "タイムアウト後はIDLE");
}

ZTEST(fw_update_us3, test_timeout_led_all_off_after_cancel)
{
	fw_update_led_cmd_t cmd = { 0 };

	enter_waiting();
	(void)fw_update_check_timeout(30000U);
	fw_update_get_led_cmd(&cmd);

	zassert_false(cmd.led1_on, "LED1は消灯");
	zassert_false(cmd.led2_on, "LED2は消灯");
	zassert_false(cmd.led3_on, "LED3は消灯");
	zassert_false(cmd.led4_on, "LED4は消灯");
	zassert_false(cmd.led4_blink, "LED4点滅は停止");
}

ZTEST(fw_update_us3, test_timeout_ignored_in_idle)
{
	zassert_false(fw_update_check_timeout(30000U), "IDLEではタイムアウト無効");
}

ZTEST(fw_update_us3, test_timeout_ignored_after_transfer_started)
{
	enter_transferring();
	zassert_false(fw_update_check_timeout(60000U),
		      "TRANSFERRINGではタイムアウト無効");
}

ZTEST(fw_update_us4, test_buttons_allowed_in_idle)
{
	zassert_true(fw_update_is_button_allowed(DK_BTN1_MSK), "IDLEでBTN1許可");
	zassert_true(fw_update_is_button_allowed(DK_BTN2_MSK), "IDLEでBTN2許可");
	zassert_true(fw_update_is_button_allowed(DK_BTN3_MSK), "IDLEでBTN3許可");
	zassert_true(fw_update_is_button_allowed(DK_BTN4_MSK), "IDLEでBTN4許可");
}

ZTEST(fw_update_us4, test_waiting_button_restrictions)
{
	enter_waiting();
	zassert_false(fw_update_is_button_allowed(DK_BTN1_MSK), "WAITINGでBTN1禁止");
	zassert_false(fw_update_is_button_allowed(DK_BTN2_MSK), "WAITINGでBTN2禁止");
	zassert_false(fw_update_is_button_allowed(DK_BTN3_MSK), "WAITINGでBTN3禁止");
	zassert_true(fw_update_is_button_allowed(DK_BTN4_MSK), "WAITINGでBTN4許可");
}

ZTEST(fw_update_us4, test_transferring_buttons_all_blocked)
{
	enter_transferring();
	zassert_false(fw_update_is_button_allowed(DK_BTN1_MSK),
		      "TRANSFERRINGでBTN1禁止");
	zassert_false(fw_update_is_button_allowed(DK_BTN2_MSK),
		      "TRANSFERRINGでBTN2禁止");
	zassert_false(fw_update_is_button_allowed(DK_BTN3_MSK),
		      "TRANSFERRINGでBTN3禁止");
	zassert_false(fw_update_is_button_allowed(DK_BTN4_MSK),
		      "TRANSFERRINGでBTN4禁止");
}

ZTEST(fw_update_us4, test_verifying_and_notify_buttons_all_blocked)
{
	enter_verifying();
	zassert_false(fw_update_is_button_allowed(DK_BTN1_MSK),
		      "VERIFYINGでBTN1禁止");
	zassert_false(fw_update_is_button_allowed(DK_BTN4_MSK),
		      "VERIFYINGでBTN4禁止");

	(void)fw_update_process_event(FW_UPDATE_EVT_VERIFY_SUCCESS);
	zassert_false(fw_update_is_button_allowed(DK_BTN1_MSK),
		      "NOTIFY_SUCCESSでBTN1禁止");
	zassert_false(fw_update_is_button_allowed(DK_BTN4_MSK),
		      "NOTIFY_SUCCESSでBTN4禁止");

	fw_update_init();
	enter_verifying();
	(void)fw_update_process_event(FW_UPDATE_EVT_VERIFY_FAILURE);
	zassert_false(fw_update_is_button_allowed(DK_BTN1_MSK),
		      "NOTIFY_FAILUREでBTN1禁止");
	zassert_false(fw_update_is_button_allowed(DK_BTN4_MSK),
		      "NOTIFY_FAILUREでBTN4禁止");
}

ZTEST(fw_update_us1, test_uart_disconnect_transitions_to_failure_notify)
{
	enter_transferring();
	zassert_equal(fw_update_process_event(FW_UPDATE_EVT_UART_DISCONNECT),
		      FW_UPDATE_STATE_NOTIFY_FAILURE,
		      "UART切断はNOTIFY_FAILUREへ遷移するべき");
}
