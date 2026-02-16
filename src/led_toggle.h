/*
 * LED Toggle Logic Module
 *
 * Provides testable button-to-LED toggle logic, decoupled from
 * hardware-specific dk_buttons_and_leds calls.
 *
 * Functional Requirements: FR-001 through FR-007
 * See specs/001-led-toggle-button/spec.md for full specification.
 *
 * SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
 */

#ifndef LED_TOGGLE_H_
#define LED_TOGGLE_H_

#include <stdint.h>

/** Number of button-LED pairs on nRF52840DK */
#define LED_TOGGLE_NUM_PAIRS 4

/**
 * @brief Reset LED state to all-off (FR-001).
 *
 * Should be called at initialization to guarantee a known starting state.
 */
void led_toggle_reset(void);

/**
 * @brief Get current LED bitmask state.
 *
 * @return Current led_state bitmask.
 */
uint32_t led_toggle_get_state(void);

/**
 * @brief Process button event and compute new LED state.
 *
 * Detects press-edge (FR-006, FR-007), toggles corresponding LEDs (FR-003),
 * and maintains independent per-pair state (FR-005).
 *
 * @param button_state  Current state of all buttons (bitmask).
 * @param has_changed   Which buttons changed since last callback (bitmask).
 *
 * @return New LED bitmask to apply, or 0 if no press detected (caller
 *         should check with led_toggle_had_press()).
 */
uint32_t led_toggle_process(uint32_t button_state, uint32_t has_changed);

/**
 * @brief Check if the last process() call detected a button press.
 *
 * @return true if at least one button press was detected.
 */
int led_toggle_had_press(void);

#endif /* LED_TOGGLE_H_ */
