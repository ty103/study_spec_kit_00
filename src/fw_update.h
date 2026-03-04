#ifndef FW_UPDATE_H_
#define FW_UPDATE_H_

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
	FW_UPDATE_STATE_IDLE = 0,
	FW_UPDATE_STATE_WAITING,
	FW_UPDATE_STATE_TRANSFERRING,
	FW_UPDATE_STATE_VERIFYING,
	FW_UPDATE_STATE_NOTIFY_SUCCESS,
	FW_UPDATE_STATE_NOTIFY_FAILURE,
} fw_update_state_t;

typedef enum {
	FW_UPDATE_EVT_BUTTON4_PRESS = 0,
	FW_UPDATE_EVT_TRANSFER_START,
	FW_UPDATE_EVT_TRANSFER_COMPLETE,
	FW_UPDATE_EVT_VERIFY_SUCCESS,
	FW_UPDATE_EVT_VERIFY_FAILURE,
	FW_UPDATE_EVT_TIMEOUT,
	FW_UPDATE_EVT_UART_DISCONNECT,
	FW_UPDATE_EVT_NOTIFY_DONE,
} fw_update_event_t;

typedef struct {
	bool led1_on;
	bool led2_on;
	bool led3_on;
	bool led4_on;
	bool led4_blink;
	uint32_t led4_blink_interval_ms;
} fw_update_led_cmd_t;

#define FW_UPDATE_TIMEOUT_MS              30000U
#define FW_UPDATE_BLINK_INTERVAL_MS       100U
#define FW_UPDATE_SUCCESS_DURATION_MS     3000U
#define FW_UPDATE_FAILURE_BLINK_COUNT     5U

void fw_update_init(void);
fw_update_state_t fw_update_get_state(void);
fw_update_state_t fw_update_process_event(fw_update_event_t event);
void fw_update_get_led_cmd(fw_update_led_cmd_t *cmd);
bool fw_update_is_button_allowed(uint32_t button_mask);
bool fw_update_check_timeout(uint32_t elapsed_ms);

#ifdef __cplusplus
}
#endif

#endif /* FW_UPDATE_H_ */
