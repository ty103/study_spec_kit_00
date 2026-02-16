/*
 * Stub header for dk_buttons_and_leds — unit testing on native_sim.
 *
 * Provides bitmask constants and typedefs used by led_toggle.c
 * without requiring the full nRF DK library (which needs nrfx/GPIO hardware).
 *
 * SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
 */

#ifndef DK_BUTTON_AND_LEDS_H__
#define DK_BUTTON_AND_LEDS_H__

#include <stdint.h>
#include <zephyr/sys/util.h>  /* BIT() macro */

#ifdef __cplusplus
extern "C" {
#endif

/* LED indices and masks */
#define DK_NO_LEDS_MSK    (0)
#define DK_LED1           0
#define DK_LED2           1
#define DK_LED3           2
#define DK_LED4           3
#define DK_LED1_MSK       BIT(DK_LED1)
#define DK_LED2_MSK       BIT(DK_LED2)
#define DK_LED3_MSK       BIT(DK_LED3)
#define DK_LED4_MSK       BIT(DK_LED4)
#define DK_ALL_LEDS_MSK   (DK_LED1_MSK | DK_LED2_MSK | \
                           DK_LED3_MSK | DK_LED4_MSK)

/* Button indices and masks */
#define DK_NO_BTNS_MSK   (0)
#define DK_BTN1          0
#define DK_BTN2          1
#define DK_BTN3          2
#define DK_BTN4          3
#define DK_BTN1_MSK      BIT(DK_BTN1)
#define DK_BTN2_MSK      BIT(DK_BTN2)
#define DK_BTN3_MSK      BIT(DK_BTN3)
#define DK_BTN4_MSK      BIT(DK_BTN4)
#define DK_ALL_BTNS_MSK  (DK_BTN1_MSK | DK_BTN2_MSK | \
                          DK_BTN3_MSK | DK_BTN4_MSK)

/* Callback type */
typedef void (*button_handler_t)(uint32_t button_state, uint32_t has_changed);

#ifdef __cplusplus
}
#endif

#endif /* DK_BUTTON_AND_LEDS_H__ */
