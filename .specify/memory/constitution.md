<!--
  Sync Impact Report
  ==================
  バージョン変更: 1.1.0 → 1.1.1
  変更された原則: なし（原則 I〜VI は変更なし）
  修正箇所:
    - 開発ワークフロー: /speckit.spec → /speckit.specify（コマンド名修正）
    - 開発ワークフロー: /speckit.clarify, /speckit.analyze,
      /speckit.checklist, /speckit.taskstoissues のステップを追加
    - 開発ワークフロー: README.md の詳細ドキュメントへの参照を追加
  追加セクション: なし
  削除セクション: なし
  テンプレート更新状況:
    - .specify/templates/plan-template.md ✅ 変更不要
      Constitution Check が動的に新原則を評価。
    - .specify/templates/spec-template.md ✅ 変更不要
      NFR は FR/SC として定義可能。テンプレート汎用構造で対応。
    - .specify/templates/tasks-template.md ✅ 変更不要
      Polish フェーズにメモリレポートタスクを配置可能。
    - .specify/templates/checklist-template.md ✅ 変更不要
      /speckit.checklist でメモリ関連チェックリスト生成可能。
    - .specify/templates/agent-file-template.md ✅ 変更不要
  フォローアップ TODO: なし
-->

# study_spec_kit_00 Constitution

## Core Principles

### I. ロジック分離（ハードウェア非依存設計）

- ハードウェアに依存しない純粋ロジックは、専用モジュール
  （`src/<module>.c` / `src/<module>.h`）として分離しなければならない
  （MUST）。
- ハードウェア抽象化層（HAL）やドライバ依存コードは `main.c`
  または専用の統合レイヤーに閉じ込めなければならない（MUST）。
- 分離されたロジックモジュールは、ハードウェアドライバのスタブ
  ヘッダのみで `native_sim` 上でコンパイル・テスト可能でなければ
  ならない（MUST）。
- 新機能追加時はまず「テスト可能な純粋関数」として設計し、
  ハードウェア連携は後から統合する。

**根拠**: nRF52840DK のような組み込みターゲットでは、実機なしに
ロジックを高速に検証できることが開発効率とコード品質を決定的に
左右する。`led_toggle.c` / `led_toggle.h` への分離実績がこの
原則の有効性を実証している。

### II. テスト先行（非交渉）

- TDD は必須とする。テスト作成 → テスト失敗確認（Red）→ 実装
  （Green）→ リファクタ（Refactor）のサイクルを厳守しなければ
  ならない（MUST）。
- テストフレームワークは Zephyr 公式の **ztest**
  （`ZTEST_SUITE` / `ZTEST` 新 API）を使用する。
- テストランナーは **Twister**（`west twister`）を使用し、
  `native_sim` ボードターゲットで実行する。
- すべてのユーザーストーリーに対して独立したテストスイートが
  存在しなければならない（MUST）。
- テストなしのロジックコードのマージは禁止する。

**根拠**: 組み込みソフトウェアのバグは実機デバッグに多大な
コストを要する。テスト先行により、ロジックレベルのバグを
開発初期段階で排除する。

### III. 仕様駆動開発

- すべての機能は仕様書（`specs/<NNN>-<feature>/spec.md`）から
  開始しなければならない（MUST）。
- 仕様 → 計画（`plan.md`）→ タスク（`tasks.md`）→ 実装の
  順序に従わなければならない（MUST）。
- ユーザーストーリーは優先度（P1, P2, P3...）を付与し、各
  ストーリーは独立してテスト・デリバリー可能でなければならない
  （MUST）。
- 要件は機能要件（FR-NNN）と成功基準（SC-NNN）として定量的に
  定義する。曖昧な要件には `NEEDS CLARIFICATION` を明記する。

**根拠**: 仕様なき実装は手戻りの最大要因である。spec-kit
ワークフローにより、要件漏れと認識齟齬を防止する。

### IV. クロスプラットフォーム検証

- テストは以下の環境で実行可能でなければならない（MUST）：
  - **macOS**: Docker コンテナ（`linux/amd64`）経由で
    `native_sim` を実行
  - **Linux（x86_64）**: ネイティブで `native_sim` を直接実行
  - **CI/CD**: Docker ベースの自動実行
- `docker-compose.yml` および `scripts/test.sh` を常に最新に
  保ち、`docker compose run --rm test` で全テストが通過する
  状態を維持しなければならない（MUST）。
- テスト環境の構築手順は `README.md` に文書化する。

**根拠**: 開発チームメンバーの環境（macOS / Linux / CI）を
問わず、同一のテスト結果を再現できることが品質保証の前提である。

### V. シンプルさと段階的拡張

- YAGNI（You Aren't Gonna Need It）原則を遵守する。現時点で
  必要のない機能・抽象化を実装してはならない（MUST NOT）。
- 複雑さの導入には明示的な正当化が必要であり、
  Complexity Tracking テーブルに記録しなければならない（MUST）。
- 新しい依存ライブラリの追加は、既存の Zephyr / nRF Connect SDK
  の機能で代替できないことを確認した上で行う。
- コードは可読性を最優先とし、過度な最適化より明瞭さを選択する。

**根拠**: 組み込みシステムではリソース制約と保守性の両立が重要で
ある。不要な複雑さはバグと技術的負債の温床となる。

### VI. メモリバジェット管理

- すべての機能は、仕様書（`spec.md`）の非機能要件（NFR）
  または制約事項として **RAM / Flash のバジェット上限** を
  定義しなければならない（MUST）。上限が不明な場合は
  `NEEDS CLARIFICATION` を明記し、計画フェーズで解決する。
- ビルド後に `west build -t rom_report` および
  `west build -t ram_report` を実行し、**メモリ使用量の実測値**
  を記録しなければならない（MUST）。記録先は以下のいずれか：
  - `plan.md` の Technical Context → Constraints セクション
  - `research.md` のメモリ分析セクション
- nRF52840 のリソース上限を基準とし、以下の閾値を
  超過する場合は Complexity Tracking テーブルに正当化を
  記録しなければならない（MUST）：
  - **RAM**: 256KB の 80%（204KB）
  - **Flash**: 1MB の 80%（819KB）
- Zephyr スレッドのスタックサイズは、使用するスレッドごとに
  明示的に定義し、根拠を文書化しなければならない（MUST）。
  `CONFIG_MAIN_STACK_SIZE` 等の Kconfig 設定値を `prj.conf`
  にコメント付きで記載する。デフォルト値を変更しない場合でも
  その判断根拠を `research.md` に記録する。
- メモリ解析タスクを `tasks.md` の Polish フェーズに含め、
  ビルド成果物のメモリレポートが閾値内であることを検証
  しなければならない（MUST）。

**根拠**: nRF52840 は RAM 256KB / Flash 1MB という有限リソースで
動作する。機能追加に伴うメモリ消費の増大を早期に把握し、
リソース枯渇による実行時障害を未然に防止する。また、スタック
オーバーフローは組み込みシステムにおける最も検出困難なバグの
一つであり、設計段階でのスタックサイズ管理が不可欠である。

## 技術スタック制約

- **言語**: C（C99/C11）
- **RTOS**: Zephyr RTOS（nRF Connect SDK v3.2.2 経由）
- **ターゲットボード**: nRF52840DK（PCA10056）
- **ビルドシステム**: CMake + Ninja（West 経由）
- **テスト**: ztest + Twister、`native_sim` ボードターゲット
- **ハードウェア抽象化**: `dk_buttons_and_leds` ライブラリ
  （nRF Connect SDK 提供）
- **コンテナ**: Docker（Ubuntu 22.04 / linux/amd64）— macOS
  テスト環境用
- **ライセンス**: Nordic-5-Clause
- 上記スタック外の技術導入は、本憲法の改訂手続きを経ること。

## 開発ワークフロー

1. **原則策定**: `/speckit.constitution` でプロジェクト憲法を
   策定する。原則の追加・変更時にのみ再実行する。
2. **仕様作成**: `/speckit.specify` で仕様書を作成。ユーザー
   ストーリーと受入シナリオを定義する。
3. **仕様明確化**: `/speckit.clarify` で仕様の曖昧な点を質問
   で解消し、回答を `spec.md` に反映する（任意・推奨）。
4. **計画策定**: `/speckit.plan` で技術調査・実装計画を策定。
   Constitution Check を実施し、本憲法への準拠を確認する。
5. **品質チェック**: `/speckit.checklist` でドメインごとの
   要件品質チェックリストを生成する（任意）。
6. **タスク分解**: `/speckit.tasks` でユーザーストーリー単位の
   タスクリストを作成。各タスクに `[P]` / `[US#]` ラベルを付与。
7. **整合性分析**: `/speckit.analyze` で仕様・計画・タスクの
   横断的整合性を非破壊的に検証する（任意・推奨）。
8. **テスト作成**: テスト対象のロジックに対して ztest テスト
   スイートを先に作成し、失敗を確認する（Red）。
9. **実装**: `/speckit.implement` でタスクに沿ったコードを実装
   する（Green）。テストを通過させる最小限のコードを書く。
10. **リファクタ**: テストが通過する状態を維持しつつ、コードを
    整理する（Refactor）。
11. **検証**: `docker compose run --rm test` または
    `./scripts/test.sh` で全テスト通過を確認する。
12. **実機確認**: `west flash` で書き込み、`README.md` の動作
    確認手順に従って手動テストを実施する。
13. **コミット**: 各タスクまたは論理的なまとまりごとにコミット
    する。コミットメッセージは日本語で記述する。
14. **Issue 化**: `/speckit.taskstoissues` でタスクを GitHub
    Issue に変換する（任意）。

> 各コマンドの入力・出力の詳細は `README.md` の
> 「speckit 開発ワークフロー」セクションを参照すること。

## Governance

- 本憲法はプロジェクトのすべての開発慣行に優先する。
- **改訂手続き**: 憲法の変更は以下の手順に従う：
  1. 変更提案を文書化（変更内容、根拠、影響範囲）
  2. Sync Impact Report を作成し、影響を受ける
     テンプレート・ドキュメントを特定
  3. 変更を適用し、影響を受けるすべてのファイルを更新
  4. バージョンを Semantic Versioning に従って更新
- **バージョニングポリシー**:
  - MAJOR: 原則の削除・再定義など後方互換性のない変更
  - MINOR: 新しい原則・セクションの追加、重要なガイダンス拡充
  - PATCH: 表現の明確化、誤字修正、意味を変えない修正
- **コンプライアンス確認**: 各機能の `plan.md` に
  Constitution Check セクションを設け、本憲法の各原則への
  準拠状況を記録しなければならない（MUST）。
- **言語ポリシー**: すべての出力（コメント、コミットメッセージ、
  ドキュメント、ユーザーへの回答）は日本語で記述する。技術用語は
  英語のまま使用してよい。
- ランタイム開発ガイダンスは `.github/copilot-instructions.md`
  を参照すること。

**Version**: 1.1.1 | **Ratified**: 2026-02-24 | **Last Amended**: 2026-02-24
