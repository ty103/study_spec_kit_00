cmake_minimum_required(VERSION 3.20.0)
find_package(Zephyr REQUIRED HINTS $ENV{ZEPHYR_BASE})
project(led_toggle_button_test)

target_sources(app PRIVATE
  src/main.c
  src/fw_update_test.c
  ${CMAKE_CURRENT_SOURCE_DIR}/../../src/led_toggle.c
  ${CMAKE_CURRENT_SOURCE_DIR}/../../src/fw_update.c
)

# native_sim（シミュレーション）の場合はスタブヘッダを使用する。
# 実機（nrf52840dk 等）の場合は nRF Connect SDK の本物のヘッダが使われるため
# スタブは不要（含めると二重定義になる）。
if("${BOARD}" MATCHES "native_sim")
  target_include_directories(app BEFORE PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/stubs
  )
endif()

target_include_directories(app PRIVATE
  ${CMAKE_CURRENT_SOURCE_DIR}/../../src
)
