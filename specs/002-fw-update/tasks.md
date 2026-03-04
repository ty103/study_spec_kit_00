# Tasks: FW更新機能

**Input**: Design documents from `/specs/002-fw-update/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Constitution原則IIに基づきTDD必須。テストを先に作成し、失敗を確認してから実装する。

**Organization**: タスクはユーザーストーリー単位でグルーピングされ、各ストーリーの独立した実装・テストを可能にする。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並行実行可能（異なるファイル、依存なし）
- **[Story]**: 対応するユーザーストーリー（US1, US2, US3, US4）

---

## Phase 1: Setup（プロジェクト設定）

**Purpose**: MCUboot + MCUmgr の有効化とビルド設定の構築

- [X] T001 MCUboot有効化のためsysbuild.confを作成し `SB_CONFIG_BOOTLOADER_MCUBOOT=y` を設定する in sysbuild.conf
- [X] T002 prj.confにMCUmgr SMP over UART関連のKconfig設定を追加する in prj.conf
- [X] T003 CMakeLists.txtに `src/fw_update.c` をソースファイルとして追加する in CMakeLists.txt
- [X] T004 [P] テスト用CMakeLists.txtに `fw_update.c` と `fw_update_test.c` を追加する in tests/unit/CMakeLists.txt
- [X] T005 [P] テスト用testcase.yamlにFW更新テストスイートを追加する in tests/unit/testcase.yaml

---

## Phase 2: Foundational（基盤構築）

**Purpose**: 全ユーザーストーリーの前提となるfw_updateモジュールの骨格とテストインフラ

**⚠️ CRITICAL**: 全ユーザーストーリーの実装はこのフェーズ完了後に開始する

- [X] T006 fw_update.hヘッダファイルを作成する（型定義: fw_update_state_t, fw_update_event_t, fw_update_led_cmd_t、定数定義、関数宣言） in src/fw_update.h
- [X] T007 fw_update.cのスケルトン実装を作成する（fw_update_init, fw_update_get_state の最小実装） in src/fw_update.c
- [X] T008 fw_update_test.cのテストスイート骨格を作成する（ZTEST_SUITE登録、初期化テスト: init後にIDLE状態であることを確認） in tests/unit/src/fw_update_test.c
- [X] T009 ビルド確認 — `native_sim` ターゲットでテストがコンパイル・実行され、初期化テストがPASSすることを確認する

**Checkpoint**: fw_updateモジュールの骨格が完成し、テストインフラが動作する状態

---

## Phase 3: User Story 1 — FW更新の開始と完了 (Priority: P1) 🎯 MVP

**Goal**: ボタン4の押下でFW更新待ちモードに遷移し、MCUmgr経由のFW転送→検証→適用→再起動の一連のフローを実現する

**Independent Test**: ボタン4押下でFW更新モードに入り、FW転送→検証→通知のフローが状態機械として正しく遷移することをユニットテストで確認

### Tests for User Story 1

> **NOTE: テストを先に書き、失敗を確認してから実装する（Red → Green → Refactor）**

- [X] T010 [P] [US1] IDLE→WAITING遷移のテストを作成する: IDLE状態でBUTTON4_PRESSイベントを送信し、WAITING状態に遷移することを検証 in tests/unit/src/fw_update_test.c
- [X] T011 [P] [US1] WAITING→TRANSFERRING遷移のテストを作成する: WAITING状態でTRANSFER_STARTイベントを送信し、TRANSFERRING状態に遷移することを検証 in tests/unit/src/fw_update_test.c
- [X] T012 [P] [US1] TRANSFERRING→VERIFYING遷移のテストを作成する: TRANSFERRING状態でTRANSFER_COMPLETEイベントを送信し、VERIFYING状態に遷移することを検証 in tests/unit/src/fw_update_test.c
- [X] T013 [P] [US1] 検証成功フローのテストを作成する: VERIFYING→NOTIFY_SUCCESS遷移、NOTIFY_DONE後に再起動準備状態であることを検証 in tests/unit/src/fw_update_test.c
- [X] T014 [P] [US1] 検証失敗フローのテストを作成する: VERIFYING→NOTIFY_FAILURE遷移、NOTIFY_DONE後にIDLEに復帰することを検証 in tests/unit/src/fw_update_test.c
- [X] T015 [P] [US1] LED制御指示テストを作成する: WAITING状態でget_led_cmdがLED1〜3消灯・LED4点滅を返すことを検証 in tests/unit/src/fw_update_test.c
- [X] T016 [P] [US1] 成功通知LED制御テストを作成する: NOTIFY_SUCCESS状態でget_led_cmdがLED4点灯（点滅なし）を返すことを検証 in tests/unit/src/fw_update_test.c
- [X] T017 [P] [US1] 失敗通知LED制御テストを作成する: NOTIFY_FAILURE状態でget_led_cmdがLED4点滅（100ms間隔）を返すことを検証 in tests/unit/src/fw_update_test.c

### Implementation for User Story 1

- [X] T018 [US1] fw_update_process_eventに状態遷移ロジックを実装する: IDLE→WAITING→TRANSFERRING→VERIFYING→NOTIFY_SUCCESS/FAILURE→IDLE/再起動 in src/fw_update.c
- [X] T019 [US1] fw_update_get_led_cmdを実装する: 各状態に対応するLED制御指示を返す in src/fw_update.c
- [X] T020 [US1] main.cのbutton_handlerを更新する: ボタン4押下時にfw_update_process_eventを呼び出し、LED制御を反映する in src/main.c
- [X] T021 [US1] main.cにMCUboot confirm処理を追加する: 起動時にboot_is_img_confirmed/boot_write_img_confirmedを呼び出す（FR-014） in src/main.c
- [X] T022 [US1] LED4点滅用のZephyrタイマー/ワークキュー処理を実装する: WAITING/TRANSFERRING状態でLED4を100ms間隔で点滅させる in src/main.c
- [X] T023 [US1] 成功/失敗通知のLEDパターン表示と完了後の状態遷移を実装する: 成功=LED4を3秒点灯後NOTIFY_DONE、失敗=LED4を5回点滅後NOTIFY_DONE in src/main.c
- [X] T024 [US1] テスト実行 — 全US1テスト（T010〜T017）がPASSすることを確認する

**Checkpoint**: FW更新の開始と完了フロー（状態遷移・LED制御）が独立してテスト可能な状態

---

## Phase 4: User Story 2 — FW更新のキャンセル（手動） (Priority: P2)

**Goal**: FW更新待ち状態でボタン4を再度押すことでキャンセルし、通常動作に復帰する

**Independent Test**: WAITING状態でボタン4を押すとIDLEに戻り全LED消灯することをユニットテストで確認

### Tests for User Story 2

- [X] T025 [P] [US2] WAITING→IDLEキャンセル遷移のテストを作成する: WAITING状態でBUTTON4_PRESSイベントを送信し、IDLEに復帰することを検証 in tests/unit/src/fw_update_test.c
- [X] T026 [P] [US2] キャンセル後LED全消灯テストを作成する: WAITING→IDLEキャンセル後にget_led_cmdが全LED消灯を返すことを検証 in tests/unit/src/fw_update_test.c
- [X] T027 [P] [US2] 転送中キャンセル不可テストを作成する: TRANSFERRING状態でBUTTON4_PRESSイベントを送信し、状態が変化しないことを検証 in tests/unit/src/fw_update_test.c

### Implementation for User Story 2

- [X] T028 [US2] fw_update_process_eventのWAITING→IDLEキャンセル遷移を実装する（IDLE状態でもBUTTON4_PRESSが正しく動作する既存実装に加える形） in src/fw_update.c
- [X] T029 [US2] テスト実行 — 全US2テスト（T025〜T027）がPASSすることを確認する

**Checkpoint**: 手動キャンセルが機能し、転送中はキャンセル不可であることを確認

---

## Phase 5: User Story 3 — FW更新のタイムアウト（自動キャンセル） (Priority: P3)

**Goal**: FW更新待ち状態で30秒間通信が開始されない場合、自動的にキャンセルして通常動作に復帰する

**Independent Test**: fw_update_check_timeoutに30秒超の経過時間を渡すとIDLEに遷移することをユニットテストで確認

### Tests for User Story 3

- [X] T030 [P] [US3] タイムアウト未発生テストを作成する: 経過時間29999msでcheck_timeoutがfalseを返すことを検証 in tests/unit/src/fw_update_test.c
- [X] T031 [P] [US3] タイムアウト発生テストを作成する: 経過時間30000msでcheck_timeoutがtrueを返し、IDLEに遷移することを検証 in tests/unit/src/fw_update_test.c
- [X] T032 [P] [US3] タイムアウト後LED全消灯テストを作成する: タイムアウト後にget_led_cmdが全LED消灯を返すことを検証 in tests/unit/src/fw_update_test.c
- [X] T033 [P] [US3] IDLE状態でのcheck_timeoutテストを作成する: IDLE状態ではcheck_timeoutがfalseを返す（タイムアウト処理なし）ことを検証 in tests/unit/src/fw_update_test.c
- [X] T034 [P] [US3] 通信開始後タイムアウト無効テストを作成する: TRANSFERRING状態ではcheck_timeoutがfalseを返すことを検証 in tests/unit/src/fw_update_test.c

### Implementation for User Story 3

- [X] T035 [US3] fw_update_check_timeoutを実装する: WAITING状態で経過時間がFW_UPDATE_TIMEOUT_MS以上の場合にTIMEOUTイベントを内部処理 in src/fw_update.c
- [X] T036 [US3] main.cにタイムアウト監視用のZephyr delayed workを実装する: WAITING状態遷移時にタイマー開始、IDLEまたはTRANSFERRING遷移時に停止 in src/main.c
- [X] T037 [US3] テスト実行 — 全US3テスト（T030〜T034）がPASSすることを確認する

**Checkpoint**: 30秒タイムアウトによる自動キャンセルが機能する状態

---

## Phase 6: User Story 4 — FW更新中のボタン操作制限 (Priority: P4)

**Goal**: FW更新待ち状態でボタン1〜3の操作を無視し、通常のLED切り替えが発生しないようにする

**Independent Test**: fw_update_is_button_allowedがWAITING/TRANSFERRING状態でボタン1〜3についてfalseを返すことをユニットテストで確認

### Tests for User Story 4

- [X] T038 [P] [US4] IDLE状態でのボタン許可テストを作成する: IDLE状態で全ボタン（1〜4）がtrue（許可）を返すことを検証 in tests/unit/src/fw_update_test.c
- [X] T039 [P] [US4] WAITING状態でのボタン制限テストを作成する: WAITING状態でボタン1〜3がfalse（拒否）、ボタン4がtrue（許可）を返すことを検証 in tests/unit/src/fw_update_test.c
- [X] T040 [P] [US4] TRANSFERRING状態でのボタン制限テストを作成する: TRANSFERRING状態で全ボタン（1〜4）がfalse（拒否）を返すことを検証 in tests/unit/src/fw_update_test.c
- [X] T040b [P] [US4] VERIFYING/NOTIFY状態でのボタン制限テストを作成する: VERIFYING、NOTIFY_SUCCESS、NOTIFY_FAILURE状態で全ボタン（1〜4）がfalse（拒否）を返すことを検証 in tests/unit/src/fw_update_test.c

### Implementation for User Story 4

- [X] T041 [US4] fw_update_is_button_allowedを実装する: 状態とボタンマスクに基づくアクセス制御ロジック in src/fw_update.c
- [X] T042 [US4] main.cのbutton_handlerを更新する: fw_update_is_button_allowedでフィルタリングし、許可されていない場合は操作を無視する in src/main.c
- [X] T043 [US4] テスト実行 — 全US4テスト（T038〜T040）がPASSすることを確認する

**Checkpoint**: FW更新中のボタン操作制限が機能し、通常操作との共存が正しく動作する状態

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: 横断的な品質改善、メモリバジェット確認、ドキュメント整備

- [X] T044 [P] MCUmgrアップロードチェックコールバックを実装する: WAITING状態でない場合はアップロードを拒否するカスタムチェック関数 in src/main.c
- [X] T044b MCUmgr/MCUbootのFWサイズ超過時の挙動を調査・記録する: slot1(472KB)を超えるイメージ送信時にMCUmgrが自動拒否するか確認し、結果をresearch.mdに追記する
- [X] T044c [P] UART切断時の状態遷移テストを作成する: TRANSFERRING状態でUART_DISCONNECTイベントを送信し、NOTIFY_FAILUREに遷移することを検証 in tests/unit/src/fw_update_test.c
- [X] T045 [P] UART切断時のエラーハンドリングを実装する: UART_DISCONNECTイベントの発火と失敗通知フロー in src/main.c
- [X] T046 メモリレポートを取得し閾値内であることを確認する: `west build -t rom_report` / `west build -t ram_report` を実行しresearch.mdに実測値を記録する
- [ ] T047 [P] quickstart.mdの動作確認チェックリストに沿って実機テストを実施する
- [X] T048 [P] ログメッセージの追加・整理を行う: 状態遷移、タイムアウト、エラーをLOG_INF/LOG_WRN/LOG_ERRで出力する in src/fw_update.c, src/main.c
- [X] T049 docker compose run --rm test で全テスト（既存LED切り替え + FW更新ロジック）がPASSすることを確認する

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 依存なし — 即座に開始可能
- **Foundational (Phase 2)**: Setup完了に依存 — **全ユーザーストーリーをブロック**
- **User Story 1 (Phase 3)**: Foundational完了に依存
- **User Story 2 (Phase 4)**: Foundational完了に依存（US1のprocess_event実装を共有するが、テストは独立）
- **User Story 3 (Phase 5)**: Foundational完了に依存（check_timeout関数は独立）
- **User Story 4 (Phase 6)**: Foundational完了に依存（is_button_allowed関数は独立）
- **Polish (Phase 7)**: 全ユーザーストーリー完了に依存

### User Story Dependencies

- **US1 (P1)**: Foundational完了後に開始可能。他のストーリーへの依存なし。**MVP**
- **US2 (P2)**: US1のprocess_event実装（T018）に技術的依存あり（WAITING→IDLE遷移はUS1のIDLE→WAITING→TRANSFERRING...と同じ関数）。ただしテストは独立して作成可能
- **US3 (P3)**: 独立。check_timeout関数はprocess_eventと疎結合
- **US4 (P4)**: 独立。is_button_allowed関数はprocess_eventと疎結合

### Within Each User Story

- テストを先に作成し、FAILを確認する（Red）
- 実装してテストがPASSすることを確認する（Green）
- リファクタリングを行う（Refactor）
- タスクまたは論理的なまとまりごとにコミットする

### Parallel Opportunities

- **Phase 1**: T004, T005は並行実行可能
- **Phase 3 (US1)**: T010〜T017は並行実行可能（すべて同ファイルの異なるテスト関数だが、各テストは独立して追加可能）
- **Phase 4-6 (US2-4)**: Foundational完了後、各ストーリーのテスト作成は並行実行可能
- **Phase 7**: T044, T045, T047, T048は並行実行可能

---

## Parallel Example: User Story 1

```bash
# 全テストを並行して作成（すべて tests/unit/src/fw_update_test.c の異なるテスト関数）:
Task T010: IDLE→WAITING遷移テスト
Task T011: WAITING→TRANSFERRING遷移テスト
Task T012: TRANSFERRING→VERIFYING遷移テスト
Task T013: 検証成功フローテスト
Task T014: 検証失敗フローテスト
Task T015: LED制御指示テスト
Task T016: 成功通知LEDテスト
Task T017: 失敗通知LEDテスト

# テスト完了後、実装を順次進める:
Task T018: 状態遷移ロジック実装
Task T019: LED制御指示実装
Task T020: main.cボタンハンドラ更新
Task T021: MCUboot confirm処理追加
Task T022: LED4点滅タイマー実装
Task T023: 成功/失敗通知パターン実装
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup完了 → MCUboot + MCUmgr有効化
2. Phase 2: Foundational完了 → fw_updateモジュール骨格
3. Phase 3: User Story 1完了 → FW更新の基本フロー動作
4. **STOP and VALIDATE**: native_simでユニットテスト、実機でFW更新フロー確認
5. MVPとしてデモ可能

### Incremental Delivery

1. Setup + Foundational → テストインフラ動作
2. US1追加 → FW更新の基本フロー（MVP!）
3. US2追加 → 手動キャンセル機能
4. US3追加 → タイムアウト安全機構
5. US4追加 → ボタン操作制限
6. Polish → メモリ確認・ドキュメント整備
7. 各ストーリーは前のストーリーを壊さずに価値を追加する

---

## Notes

- [P] タスク = 異なるファイルまたは独立したコンテキスト、依存なし
- [Story] ラベルはタスクを特定のユーザーストーリーにマッピング
- 各ユーザーストーリーは独立して完了・テスト可能
- テストがFAILすることを確認してから実装する
- タスクまたは論理的なまとまりごとにコミットする
- 全タスクの対象ファイルは plan.md の Project Structure で定義されたパスに準拠する
