# speckit 開発ワークフロー

本プロジェクトでは **speckit** を使用して、仕様策定から実装までを体系的に進めます。
以下に、通常の開発フローにおけるコマンドの実行順序・入力・出力をまとめます。

## ワークフロー全体図

```
constitution ─→ specify ─→ clarify ─→ plan ─→ tasks ─→ analyze ─→ implement
                                         ↘                          ↑
                                       checklist              taskstoissues
```

## コマンド一覧

### 1. `/speckit.constitution` — プロジェクト原則の策定

プロジェクト全体を統治する原則（憲法）を定義・更新します。
通常はプロジェクト開始時に 1 回実行し、以降は原則の追加・変更時にのみ再実行します。

| 項目 | 内容 |
|------|------|
| 入力 | ユーザーからの原則の記述（自然言語）、既存のテンプレート |
| 出力 | `.specify/memory/constitution.md`（プロジェクト憲法） |
| 次のコマンド | → `/speckit.specify` |

### 2. `/speckit.specify` — 機能仕様書の作成

自然言語の機能説明から、構造化された仕様書を生成します。
Git ブランチの作成と仕様品質チェックリストの初期生成も行います。

| 項目 | 内容 |
|------|------|
| 入力 | 機能の説明テキスト（自然言語） |
| 出力 | `specs/<NNN-feature>/spec.md`（仕様書）、`specs/<NNN-feature>/checklists/requirements.md`（品質チェックリスト）、Git ブランチ |
| 次のコマンド | → `/speckit.clarify` または `/speckit.plan` |

### 3. `/speckit.clarify` — 仕様の曖昧点の解消（任意・推奨）

仕様書の未定義・曖昧な領域を検出し、最大 5 件の質問で明確化します。
回答は `spec.md` に直接反映されます。

| 項目 | 内容 |
|------|------|
| 入力 | なし（自動的に現在のフィーチャーの `spec.md` を読み込む） |
| 出力 | `spec.md` の更新（`## Clarifications` セクション追加） |
| 次のコマンド | → `/speckit.plan` |

### 4. `/speckit.plan` — 技術計画・設計アーティファクトの生成

仕様書と憲法に基づき、実装に必要な設計ドキュメント群を一括生成します。

| 項目 | 内容 |
|------|------|
| 入力 | `spec.md`、`.specify/memory/constitution.md` |
| 出力 | `plan.md`（実装計画）、`research.md`（技術調査）、`data-model.md`（データモデル）、`contracts/`（インターフェース契約）、`quickstart.md`（テストシナリオ） |
| 次のコマンド | → `/speckit.tasks` |

### 5. `/speckit.checklist` — 要件品質チェックリストの生成（任意）

仕様書の品質（完全性・明確性・整合性）を検証するためのチェックリストを作成します。
ドメインごとに複数回実行できます（例: UX、セキュリティ、パフォーマンス）。

| 項目 | 内容 |
|------|------|
| 入力 | ドメイン指定（例: `ux`, `security`）、`spec.md`、`plan.md`（任意） |
| 出力 | `specs/<NNN-feature>/checklists/<domain>.md`（例: `ux.md`, `security.md`） |
| 次のコマンド | — （`/speckit.implement` 実行時に自動参照される） |

### 6. `/speckit.tasks` — タスク一覧の生成

設計アーティファクト群からフェーズ分け・依存関係を考慮した実行可能なタスク一覧を生成します。

| 項目 | 内容 |
|------|------|
| 入力 | `plan.md`（必須）、`spec.md`（必須）、`data-model.md`・`contracts/`・`research.md`（任意） |
| 出力 | `tasks.md`（フェーズ別タスク一覧、依存関係グラフ、チェックリスト形式） |
| 次のコマンド | → `/speckit.analyze` または `/speckit.implement` |

### 7. `/speckit.analyze` — 横断的整合性分析（任意・推奨）

仕様・計画・タスクの 3 文書を横断し、重複・矛盾・カバレッジ不足を非破壊的に検出します。
ファイルは一切変更しません（読み取り専用）。

| 項目 | 内容 |
|------|------|
| 入力 | `spec.md`、`plan.md`、`tasks.md`、`.specify/memory/constitution.md` |
| 出力 | チャット内に分析レポート出力（重複検出、カバレッジギャップ、不整合テーブル、メトリクス） |
| 次のコマンド | → 問題があれば修正後に `/speckit.implement` |

### 8. `/speckit.implement` — タスクに沿った実装の実行

`tasks.md` に定義されたタスクをフェーズ順に実行し、実際のソースコードを生成します。
完了したタスクは `tasks.md` 上で `[X]` にマークされます。

| 項目 | 内容 |
|------|------|
| 入力 | `tasks.md`（必須）、`plan.md`（必須）、その他の設計ドキュメント群、`checklists/`（任意） |
| 出力 | プロジェクトのソースコード、設定ファイル、`tasks.md` の進捗更新 |
| 次のコマンド | → `/speckit.taskstoissues`（任意） |

### 9. `/speckit.taskstoissues` — GitHub Issue への変換（任意）

タスクを GitHub Issue に変換します。リモートリポジトリが GitHub である場合のみ動作します。

| 項目 | 内容 |
|------|------|
| 入力 | `tasks.md`、Git リモート URL |
| 出力 | GitHub リポジトリ上に Issue を作成 |
| 次のコマンド | — |

## 典型的な開発フロー例

```bash
# 1. プロジェクト原則の策定（初回のみ）
/speckit.constitution メモリ安全性とテストファーストを原則とする

# 2. 新機能の仕様作成
/speckit.specify ボタン押下で LED をトグルする機能

# 3. 仕様の曖昧点を解消
/speckit.clarify

# 4. 技術計画の生成
/speckit.plan C言語 + Zephyr RTOS で実装する

# 5. 要件品質チェック（必要に応じて）
/speckit.checklist ハードウェア

# 6. タスク一覧の生成
/speckit.tasks

# 7. 整合性分析（推奨）
/speckit.analyze

# 8. 実装の実行
/speckit.implement
```

## speckit 関連ファイル構成

```
.specify/
├── memory/
│   └── constitution.md       # プロジェクト憲法
├── templates/                # テンプレート群（speckit が内部で使用）
│   ├── spec-template.md
│   ├── plan-template.md
│   ├── tasks-template.md
│   ├── checklist-template.md
│   └── commands/             # 各コマンドの定義
└── scripts/                  # 前提条件チェック等のユーティリティ

.github/
├── agents/                   # 各コマンドのエージェント定義
│   ├── speckit.constitution.agent.md
│   ├── speckit.specify.agent.md
│   ├── speckit.clarify.agent.md
│   ├── speckit.plan.agent.md
│   ├── speckit.tasks.agent.md
│   ├── speckit.analyze.agent.md
│   ├── speckit.implement.agent.md
│   ├── speckit.checklist.agent.md
│   └── speckit.taskstoissues.agent.md
└── prompts/                  # VS Code のプロンプト定義
    └── speckit.*.prompt.md
```

## speckit を使わずにファイルを変更した場合の留意点

speckit コマンドを経由せずに `specs/` 配下のドキュメントやソースコードを
直接編集した場合、アーティファクト間の整合性が崩れる可能性があります。
以下の対応を行ってください。

### `specs/` 配下を手動編集した場合

| 変更対象 | 発生するリスク | 対応方法 |
|---------|-------------|---------|
| `spec.md` | `plan.md` / `tasks.md` が古い仕様を参照した状態になる | `/speckit.plan` → `/speckit.tasks` を再実行して下流を再生成する |
| `plan.md` | `tasks.md` のタスク粒度・依存関係が実態と乖離する | `/speckit.tasks` を再実行する |
| `tasks.md` | `/speckit.implement` が誤ったタスク状態で動作する | 手動でチェックボックスを更新し、`/speckit.analyze` で整合性を確認する |
| `checklists/*.md` | 仕様変更後のチェック項目が古いまま残る | `/speckit.checklist` で該当ドメインを再生成する |
| `research.md` / `data-model.md` | 計画・タスクとの技術前提が不一致になる | `/speckit.analyze` で不整合を検出し、必要に応じて `/speckit.plan` を再実行する |

> **推奨**: 手動編集後は必ず `/speckit.analyze` を実行し、
> 仕様・計画・タスク間の横断的整合性を確認してください。

### ソースコードを手動で改変した場合

| 変更内容 | 発生するリスク | 対応方法 |
|---------|-------------|---------|
| ロジック変更（`src/*.c`） | `tasks.md` の完了状態が実装と一致しない | `tasks.md` のチェックボックスを手動更新する |
| API 変更（`src/*.h`） | `contracts/` やテストコードとの不整合 | テストを実行して通過を確認。`contracts/` も手動更新する |
| テスト追加・変更 | `quickstart.md` のシナリオと不一致 | `quickstart.md` を手動更新する |
| `prj.conf` 変更 | メモリバジェットへの影響 | `./scripts/memory-report.sh` で閾値チェックを再実行する |
| 新ファイル追加 | `plan.md` のファイル構成と不一致 | `plan.md` の File Structure セクションを手動更新する |

> **注意**: speckit はアーティファクト間の **自動同期機能を持ちません**。
> コマンド実行時にその時点のファイルを読み込んで処理するため、
> 手動変更を加えた場合はユーザー自身が整合性を管理する必要があります。

### 整合性回復の手順

手動変更が広範囲に及んだ場合は、以下の順序でアーティファクトを再生成できます：

```bash
# 1. 整合性を確認（読み取り専用、ファイル変更なし）
/speckit.analyze

# 2. 問題がある場合、影響の大きい順に再生成
/speckit.plan    # spec.md を変更した場合
/speckit.tasks   # plan.md を変更した場合
```

> **既存の実装コードは上書きされません。**
> `/speckit.plan` や `/speckit.tasks` はドキュメントのみを再生成します。
> `/speckit.implement` を実行しない限り、ソースコードには影響しません。
