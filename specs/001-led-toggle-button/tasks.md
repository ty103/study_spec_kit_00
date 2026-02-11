# Tasks: nRF52840DK LED トグル（ボタン操作）

**Input**: Design documents from `/specs/001-led-toggle-button/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: テストは明示的に要求されていないため、テストタスクは含まない。動作確認は quickstart.md のテストチェックリストで実施する。

**Organization**: タスクはユーザーストーリーごとにグループ化し、各ストーリーの独立した実装・テストを可能にする。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **組み込みファームウェア（single project）**: `CMakeLists.txt`, `prj.conf`, `src/` at repository root

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: nRF Connect SDK / Zephyr プロジェクトの初期化と基本構成

- [ ] T001 Create project directory structure with `src/` directory
- [ ] T002 [P] Create CMake build definition in `CMakeLists.txt` with Zephyr package, project name `led_toggle_button`, and `src/main.c` as target source
- [ ] T003 [P] Create Kconfig settings in `prj.conf` with `CONFIG_GPIO=y`, `CONFIG_DK_LIBRARY=y`, `CONFIG_LOG=y`

**Checkpoint**: `west build -b nrf52840dk/nrf52840` が成功すること（main.c がスタブでも）

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: アプリケーションの骨格 — LED初期化・ボタン初期化のフレームワーク

**⚠️ CRITICAL**: ユーザーストーリーの実装は、この Phase の完了後に開始する

- [ ] T004 Create application entry point in `src/main.c` with Zephyr kernel include, dk_buttons_and_leds include, LOG_MODULE_REGISTER, and empty `main()` function
- [ ] T005 Implement LED initialization in `src/main.c`: call `dk_leds_init()` in `main()` with error check and LOG_ERR on failure (FR-001)
- [ ] T006 Implement button initialization in `src/main.c`: define empty `button_handler()` callback, call `dk_buttons_init(button_handler)` in `main()` with error check and LOG_ERR on failure
- [ ] T007 Declare LED state variable `static uint32_t led_state` initialized to 0 in `src/main.c` (data-model: ビットマスク管理)

**Checkpoint**: ビルド成功、書き込み後にデバイスが起動し全LED消灯、ボタン押下でコールバック到達（ログ確認）

---

## Phase 3: User Story 1 — ボタン押下でLEDトグル (Priority: P1) 🎯 MVP

**Goal**: Button 1 を押すたびに LED 1 がトグルする。最小限の1ボタン-1LED動作の実現。

**Independent Test**: nRF52840DK に書き込み、Button 1 を押して LED 1 が点灯/消灯を繰り返すことを目視確認する。

### Implementation for User Story 1

- [ ] T008 [US1] Implement press-edge detection in `button_handler()` in `src/main.c`: compute `uint32_t pressed = has_changed & button_state` to detect only button-press events (FR-006, FR-007)
- [ ] T009 [US1] Implement LED toggle for Button 1 in `button_handler()` in `src/main.c`: when `pressed & DK_BTN1_MSK`, toggle `led_state ^= DK_LED1_MSK` and call `dk_set_leds(led_state)` (FR-003)
- [ ] T010 [US1] Add LOG_INF for button press and LED state change events in `button_handler()` in `src/main.c` for debugging

**Checkpoint**: Button 1 → LED 1 トグル動作確認。押下のみ反応、長押しで1回のみ、デバウンス動作正常。

---

## Phase 4: User Story 2 — 起動時の初期状態 (Priority: P2)

**Goal**: 電源投入・リセット直後にすべての LED が消灯した状態で起動する。

**Independent Test**: デバイスの電源を切り→入れし、LED 1〜4 がすべて消灯していることを目視確認する。リセットボタンでも同様。

### Implementation for User Story 2

- [ ] T011 [US2] Verify and enforce LED off state after initialization in `main()` in `src/main.c`: add explicit `dk_set_leds(0)` call after `dk_leds_init()` to guarantee all LEDs start OFF (FR-001)
- [ ] T012 [US2] Add LOG_INF startup message in `main()` in `src/main.c` printing "LED Toggle Button application started" and initial `led_state` value for boot confirmation

**Checkpoint**: 電源投入時に全LED消灯＋起動ログ出力。リセットボタン押下後も全LED消灯に復帰。

---

## Phase 5: User Story 3 — 複数ボタンの独立動作 (Priority: P3)

**Goal**: Button 1〜4 がそれぞれ LED 1〜4 を独立してトグル制御する。

**Independent Test**: 各ボタンを個別に操作し、対応する LED のみがトグルされ、他の LED に影響がないことを確認する。

### Implementation for User Story 3

- [ ] T013 [P] [US3] Extend `button_handler()` in `src/main.c` to handle Button 2: when `pressed & DK_BTN2_MSK`, toggle `led_state ^= DK_LED2_MSK` and call `dk_set_leds(led_state)` (FR-002, FR-005)
- [ ] T014 [P] [US3] Extend `button_handler()` in `src/main.c` to handle Button 3: when `pressed & DK_BTN3_MSK`, toggle `led_state ^= DK_LED3_MSK` and call `dk_set_leds(led_state)` (FR-002, FR-005)
- [ ] T015 [P] [US3] Extend `button_handler()` in `src/main.c` to handle Button 4: when `pressed & DK_BTN4_MSK`, toggle `led_state ^= DK_LED4_MSK` and call `dk_set_leds(led_state)` (FR-002, FR-005)
- [ ] T016 [US3] Refactor `button_handler()` in `src/main.c` to use loop over button-LED pairs array instead of repeated if-statements for maintainability (optional improvement)

**Checkpoint**: 4つのボタンすべてが対応する LED を独立トグル。同時押し・連打でも正常動作。

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: コード品質の向上と最終検証

- [ ] T017 [P] Add file header comment with license, project description, and FR reference in `src/main.c`
- [ ] T018 [P] Verify `prj.conf` contains all required settings and add `CONFIG_DK_LIBRARY_BUTTON_SCAN_INTERVAL=15` for spec FR-004 debounce requirement in `prj.conf`
- [ ] T019 Run quickstart.md full test checklist on nRF52840DK hardware (10 test items)
- [ ] T020 Verify clean build with `west build -b nrf52840dk/nrf52840 --pristine` produces zero warnings

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存なし — 即座に開始可能
- **Foundational (Phase 2)**: Setup完了後 — すべてのユーザーストーリーをブロック
- **User Stories (Phase 3-5)**: Foundational Phase 完了後に開始可能
  - US1 (Phase 3): Foundational に依存。他のストーリーに依存しない
  - US2 (Phase 4): Foundational に依存。他のストーリーに依存しない
  - US3 (Phase 5): US1 (Phase 3) に依存（Button 1のトグルロジックを拡張するため）
- **Polish (Phase 6)**: US1〜US3 すべて完了後

### User Story Dependencies

- **User Story 1 (P1)**: Phase 2 完了後に開始可能。MVP として独立動作可能
- **User Story 2 (P2)**: Phase 2 完了後に開始可能。US1 と並行実装可能
- **User Story 3 (P3)**: US1 の T008-T009 完了後に開始（ボタンハンドラの押下エッジ検出ロジックを拡張するため）

### Within Each User Story

- コア実装 → ログ追加 → 動作確認
- ストーリー完了後にチェックポイントで検証

### Parallel Opportunities

- **Phase 1**: T002, T003 は並行実行可能（異なるファイル）
- **Phase 3-4**: US1 と US2 は並行実行可能（US2 は main() 内の初期化部分、US1 はコールバック部分で独立）
- **Phase 5**: T013, T014, T015 は並行実行可能（同一関数内だが独立した if ブロック）
- **Phase 6**: T017, T018 は並行実行可能（異なるファイル）

---

## Parallel Example: User Story 3

```bash
# Launch all button handler extensions together:
Task: "Extend button_handler() to handle Button 2 in src/main.c"
Task: "Extend button_handler() to handle Button 3 in src/main.c"
Task: "Extend button_handler() to handle Button 4 in src/main.c"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup（CMakeLists.txt + prj.conf）
2. Complete Phase 2: Foundational（main.c 骨格 + 初期化）
3. Complete Phase 3: User Story 1（Button 1 → LED 1 トグル）
4. **STOP and VALIDATE**: Button 1 を押して LED 1 がトグルすることを確認
5. これだけで動作するMVPが完成

### Incremental Delivery

1. Setup + Foundational → ビルド成功・起動確認
2. User Story 1 → Button 1 → LED 1 トグル（MVP! 🎯）
3. User Story 2 → 起動時全LED消灯の保証
4. User Story 3 → 4ボタン×4LED 全ペア動作
5. Polish → コード品質・最終検証

### Single Developer Strategy

本プロジェクトは単一ファイル（`src/main.c`）の小規模プロジェクトのため：

1. Phase 1-2 を順次実行（T001〜T007）
2. Phase 3 (US1) を完了 → MVPとして検証
3. Phase 4 (US2) を完了 → 初期状態を検証
4. Phase 5 (US3) を完了 → 全ペア動作を検証
5. Phase 6 (Polish) → 最終仕上げ

---

## Notes

- [P] tasks = 異なるファイルまたは独立したコード領域、依存関係なし
- [Story] ラベルでタスクを特定のユーザーストーリーに紐づけ
- 各ユーザーストーリーは独立して完了・テスト可能
- タスクまたは論理グループごとにコミット
- チェックポイントで独立してストーリーを検証
- 全 FR（FR-001〜FR-007）がタスク内で参照されていることを確認済み
