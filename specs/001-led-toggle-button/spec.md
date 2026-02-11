# Feature Specification: nRF52840DK LED トグル（ボタン操作）

**Feature Branch**: `001-led-toggle-button`  
**Created**: 2026-02-10  
**Status**: Draft  
**Input**: User description: "nRF52840DKで、ボタンを押すたびにLEDの点灯と消灯を切り替えるプロジェクト。"

## User Scenarios & Testing *(mandatory)*

<!--
  IMPORTANT: User stories should be PRIORITIZED as user journeys ordered by importance.
  Each user story/journey must be INDEPENDENTLY TESTABLE - meaning if you implement just ONE of them,
  you should still have a viable MVP (Minimum Viable Product) that delivers value.
  
  Assign priorities (P1, P2, P3, etc.) to each story, where P1 is the most critical.
  Think of each story as a standalone slice of functionality that can be:
  - Developed independently
  - Tested independently
  - Deployed independently
  - Demonstrated to users independently
-->

### User Story 1 - ボタン押下でLEDトグル (Priority: P1)

ユーザーがnRF52840DK上のボタンを1回押すと、対応するLEDの状態が切り替わる（消灯中なら点灯、点灯中なら消灯）。これにより、ユーザーはボタン操作でLEDの点灯/消灯を自由に制御できる。

**Why this priority**: プロジェクトの核となる機能であり、ボタン入力によるLED制御はこの機能の最も基本的な価値を提供する。

**Independent Test**: nRF52840DKにファームウェアを書き込み、ボタンを押してLEDが切り替わることを目視確認するだけでテスト可能。

**Acceptance Scenarios**:

1. **Given** デバイスの電源が入りLEDが消灯している状態, **When** ユーザーがButton 1を1回押す, **Then** LED 1が点灯する
2. **Given** LED 1が点灯している状態, **When** ユーザーがButton 1を再度1回押す, **Then** LED 1が消灯する
3. **Given** デバイスの電源が入った状態, **When** ユーザーがButton 2を1回押す, **Then** LED 2の状態が切り替わる（LED 1とは独立して動作）

---

### User Story 2 - 起動時の初期状態 (Priority: P2)

デバイスに電源を投入した直後、すべてのLEDが既知の初期状態（消灯）で開始され、ユーザーは現在の状態を明確に把握できる。

**Why this priority**: ユーザーが操作を開始する前に、デバイスが予測可能な状態にあることを保証するために重要。

**Independent Test**: デバイスの電源を入れた直後にすべてのLEDが消灯していることを目視確認する。

**Acceptance Scenarios**:

1. **Given** デバイスの電源がオフの状態, **When** 電源を投入する, **Then** すべてのLED（LED 1〜LED 4）が消灯した状態で起動する
2. **Given** デバイスをリセットした場合, **When** リセットが完了する, **Then** すべてのLEDが消灯した初期状態に戻る

---

### User Story 3 - 複数ボタンの独立動作 (Priority: P3)

各ボタン（Button 1〜Button 4）がそれぞれ対応するLED（LED 1〜LED 4）を独立して制御する。あるボタンの操作が他のLEDの状態に影響しない。

**Why this priority**: 4つのボタンとLEDの組み合わせすべてが独立して動作することで、ユーザーに完全な制御性を提供する。

**Independent Test**: 各ボタンを個別に押して対応するLEDのみが切り替わり、他のLEDに影響がないことを確認する。

**Acceptance Scenarios**:

1. **Given** すべてのLEDが消灯している状態, **When** Button 1のみを押す, **Then** LED 1のみが点灯し、LED 2〜4は消灯のまま
2. **Given** LED 1が点灯、LED 2〜4が消灯の状態, **When** Button 3を押す, **Then** LED 3が点灯し、LED 1は点灯のまま、LED 2とLED 4は消灯のまま
3. **Given** すべてのLEDが点灯している状態, **When** Button 2を押す, **Then** LED 2のみが消灯し、LED 1, 3, 4は点灯のまま

---

### Edge Cases

- ボタンを非常に速く連打した場合でも、押下ごとに1回だけトグルが発生すること（チャタリング対策）
- 複数のボタンを同時に押した場合、それぞれ対応するLEDが正しくトグルされること
- ボタンを長押しした場合、1回のトグルのみが発生すること（押下時のみ反応し、保持中に繰り返しトグルしない）
- デバイスが長時間稼働しても、トグル動作が安定して機能すること

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: デバイスは電源投入時にすべてのLED（LED 1〜LED 4）を消灯状態で初期化しなければならない
- **FR-002**: 各ボタン（Button 1〜Button 4）は、対応するLED（LED 1〜LED 4）と1対1で紐づけられなければならない
- **FR-003**: ユーザーがボタンを1回押すたびに、対応するLEDの状態が1回切り替わらなければならない（点灯→消灯、消灯→点灯）
- **FR-004**: ボタンのチャタリング（機械的な振動による誤入力）をデバウンス時間15msで除去し、1回の物理的な押下で1回のトグルのみが発生しなければならない
- **FR-005**: 各ボタンとLEDのペアは互いに独立して動作しなければならない（あるボタンの操作が他のLEDに影響しない）
- **FR-006**: ボタンの押下検出は、ボタンを押した瞬間（押下エッジ）で行わなければならない（離した瞬間ではない）
- **FR-007**: ボタンを長押ししても、トグルは1回のみ発生しなければならない（ボタンを離して再度押すまで次のトグルは発生しない）

### Key Entities

- **ボタン**: nRF52840DK上の物理的な押しボタンスイッチ（Button 1〜Button 4の4個）。ユーザーからの入力を受け付ける。
- **LED**: nRF52840DK上の発光ダイオード（LED 1〜LED 4の4個）。点灯または消灯の2つの状態を持ち、対応するボタンによって制御される。
- **ボタン-LEDペア**: ボタンとLEDの1対1の対応関係。Button NがLED Nを制御する（N = 1〜4）。

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: 4つのボタンすべてにおいて、ボタンを1回押すごとに対応するLEDが確実にトグルされること（成功率100%）
- **SC-002**: ボタン押下からLEDの状態変化までの応答が100ms以下であること
- **SC-003**: ボタンを10回連続で押した場合、10回すべてのトグルが正確に反映されること（連打耐性）
- **SC-004**: デバイスのリセット後、すべてのLEDが消灯した初期状態に戻ること
- **SC-005**: 各ボタン操作が他のLEDに影響を与えないこと（独立性の確認テストに100%合格）

## Clarifications

### Session 2026-02-10

- Q: SC-002のレスポンス要件「体感即時」の具体的なレイテンシ目標は？ → A: 100ms以下
- Q: デバウンス（チャタリング除去）の時間はどの程度にするか？ → A: 15ms
- Q: ボタン-LEDの対応マッピングは「Button N → LED N」で確定か？ → A: Button N → LED N（順序通り）

## Assumptions

- nRF52840DK開発ボード（PCA10056）を使用する
- ボードに搭載されている4つのユーザーボタン（Button 1〜Button 4）と4つのユーザーLED（LED 1〜LED 4）を使用する
- デバウンス（チャタリング除去）の時間は15msとする
- ボタンのトグル検出はボタン押下時（立ち下がりエッジ）をトリガーとする（nRF52840DKのボタンはアクティブロー）
- デバイスは連続稼働を前提とし、省電力モードの実装は本機能のスコープ外とする
