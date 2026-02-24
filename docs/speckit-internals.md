# speckit の仕組み

speckit がどのように動作しているかを解説します。

## 全体アーキテクチャ

speckit は **VS Code の GitHub Copilot Chat 拡張機能** の仕組みを利用した
スラッシュコマンドベースの開発支援ツールです。
独自のランタイムやサーバーは持たず、以下の 3 層構造で動作します。

```
┌─────────────────────────────────────────────────────┐
│  VS Code + GitHub Copilot Chat                      │
│  ユーザーが /speckit.xxx を入力                       │
└──────────────┬──────────────────────────────────────┘
               │ スラッシュコマンドとして解決
               ▼
┌─────────────────────────────────────────────────────┐
│  Prompt ファイル (.github/prompts/*.prompt.md)       │
│  → 対応する Agent にルーティング                     │
└──────────────┬──────────────────────────────────────┘
               │ agent: speckit.xxx
               ▼
┌─────────────────────────────────────────────────────┐
│  Agent ファイル (.github/agents/*.agent.md)          │
│  → LLM へのシステムプロンプトとして機能              │
│  → シェルスクリプトを実行してコンテキストを取得      │
│  → テンプレートを使ってファイルを生成                │
└──────────────┬──────────────────────────────────────┘
               │ ターミナルでスクリプト実行
               ▼
┌─────────────────────────────────────────────────────┐
│  スクリプト (.specify/scripts/bash/*.sh)             │
│  → Git ブランチ / specs/ ディレクトリからコンテキスト │
│     を解決し、JSON またはテキストで返す               │
└─────────────────────────────────────────────────────┘
```

## VS Code の仕組みとの対応

### Prompt ファイル（スラッシュコマンドの登録）

`.github/prompts/speckit.xxx.prompt.md` は、VS Code の Copilot Chat に
スラッシュコマンドを登録するためのファイルです。

```yaml
# .github/prompts/speckit.plan.prompt.md
---
agent: speckit.plan
---
```

- ファイル名がそのままスラッシュコマンド名になる
  （例: `speckit.plan.prompt.md` → `/speckit.plan`）
- YAML フロントマターの `agent:` フィールドで、処理を委譲する Agent を指定する
- Prompt ファイル自体にはロジックを持たない — 純粋なルーティング定義

### Agent ファイル（LLM への指示書）

`.github/agents/speckit.xxx.agent.md` は、LLM（Copilot）に対する
**システムプロンプト**（指示書）です。ユーザーの入力とともに LLM に送信されます。

```yaml
# .github/agents/speckit.plan.agent.md
---
description: Execute the implementation planning workflow...
handoffs:
  - label: Create Tasks
    agent: speckit.tasks
    prompt: Break the plan into tasks
    send: true
  - label: Create Checklist
    agent: speckit.checklist
    prompt: Create a checklist for the following domain...
---

## Outline
1. Run `.specify/scripts/bash/setup-plan.sh --json` ...
2. Load spec.md and constitution ...
3. Generate plan.md, research.md, data-model.md ...
```

YAML フロントマターに定義できるプロパティ:

| プロパティ | 説明 |
|-----------|------|
| `description` | Agent の説明（Copilot Chat の UI に表示される） |
| `handoffs` | コマンド完了後に提案する次のコマンド。`label` が UI のボタンラベル、`agent` が委譲先、`prompt` が前入力テキスト。`send: true` で自動送信 |
| `tools` | Agent が使用可能な外部ツール（例: `github/github-mcp-server/issue_write`） |

Agent ファイルの本文（Markdown 部分）が LLM へのプロンプトとなり、
以下のパターンで処理を記述します:

1. **スクリプト実行**: ターミナルでシェルスクリプトを実行し、出力を解析
2. **ファイル読み込み**: 仕様書やテンプレートをワークスペースから読み込み
3. **ファイル生成/更新**: テンプレートに基づいてドキュメントを生成・書き込み
4. **ユーザー対話**: 質問を投げかけ、回答をファイルに反映

### Prompt と Agent の関係

```
/speckit.plan  (ユーザー入力)
     │
     ▼
speckit.plan.prompt.md  ─── agent: speckit.plan ───▶  speckit.plan.agent.md
  (コマンド登録)                                        (処理ロジック)
```

- **Prompt**: 1 対 1 で Agent にマッピングされるルーティング定義
- **Agent**: 実際の処理手順をプロンプトとして記述した指示書
- Prompt なしの Agent は、他の Agent からの handoff 経由でのみ呼び出せる

## スクリプト群の役割

### common.sh — 共通ユーティリティ

すべてのスクリプトが `source` する共通関数ライブラリです。

| 関数 | 役割 |
|------|------|
| `get_repo_root()` | Git リポジトリのルートパスを取得（非 Git 環境ではフォールバック） |
| `get_current_branch()` | 現在のブランチ名を取得。`SPECIFY_FEATURE` 環境変数 → Git → `specs/` ディレクトリの自動検出の優先順で解決 |
| `find_feature_dir_by_prefix()` | ブランチ名の数値プレフィックス（例: `001`）から `specs/001-*` ディレクトリを検索 |
| `get_feature_paths()` | 上記を組み合わせ、全パス変数（`FEATURE_DIR`, `FEATURE_SPEC`, `IMPL_PLAN`, `TASKS` 等）をシェル変数として出力 |
| `check_feature_branch()` | ブランチ名が `NNN-xxx` 形式であることを検証 |

**コンテキスト解決の仕組み**:

```
ブランチ名: "001-led-toggle-button"
              │
              ├── 数値プレフィックス "001" を抽出
              ▼
specs/001-led-toggle-button/  ← このディレクトリを発見
  ├── spec.md       → FEATURE_SPEC
  ├── plan.md       → IMPL_PLAN
  ├── tasks.md      → TASKS
  ├── research.md   → RESEARCH
  ├── data-model.md → DATA_MODEL
  ├── quickstart.md → QUICKSTART
  └── contracts/    → CONTRACTS_DIR
```

### check-prerequisites.sh — 前提条件チェック

ほぼすべての Agent が最初に実行するスクリプトです。
現在のフィーチャーのコンテキストを解決し、必要なファイルの存在を検証します。

| オプション | 動作 |
|-----------|------|
| `--json` | JSON 形式で出力（Agent が解析しやすい形式） |
| `--paths-only` | パス情報のみ出力（バリデーションをスキップ） |
| `--require-tasks` | `tasks.md` の存在を必須とする（`implement`, `analyze` 用） |
| `--include-tasks` | `tasks.md` を AVAILABLE_DOCS リストに含める |

出力例（`--json --paths-only`）:
```json
{
  "REPO_ROOT": "/path/to/repo",
  "BRANCH": "001-led-toggle-button",
  "FEATURE_DIR": "/path/to/repo/specs/001-led-toggle-button",
  "FEATURE_SPEC": "/path/to/repo/specs/001-led-toggle-button/spec.md",
  "IMPL_PLAN": "/path/to/repo/specs/001-led-toggle-button/plan.md",
  "TASKS": "/path/to/repo/specs/001-led-toggle-button/tasks.md"
}
```

### create-new-feature.sh — フィーチャー作成

`/speckit.specify` が呼び出すスクリプトです。以下を実行します:

1. `specs/` ディレクトリと Git ブランチから次の番号を自動算出
2. 機能説明からブランチ名を自動生成（ストップワード除去、3〜4 語に短縮）
3. Git ブランチを作成（`git checkout -b NNN-short-name`）
4. `specs/NNN-short-name/` ディレクトリを作成
5. `spec-template.md` を `spec.md` としてコピー

### setup-plan.sh — 計画フェーズの準備

`/speckit.plan` が呼び出すスクリプトです。
`plan-template.md` を `plan.md` としてコピーし、パス情報を返します。

### update-agent-context.sh — エージェントコンテキスト更新

`/speckit.plan` の完了後に呼び出されるスクリプトです。
`plan.md` から技術スタック情報（言語、フレームワーク、DB 等）を抽出し、
`.github/copilot-instructions.md` 等のエージェント設定ファイルを自動更新します。

16 種類以上の AI エージェント対応:
Claude, Gemini, Copilot, Cursor, Qwen, Windsurf, Kilo Code 等

## テンプレートシステム

Agent はファイル生成時にテンプレートを使用します。
テンプレートは `.specify/templates/` に配置され、プレースホルダ付きの
Markdown ファイルです。

| テンプレート | 用途 | 主なプレースホルダ |
|-------------|------|------------------|
| `spec-template.md` | 機能仕様書の雛形 | `[FEATURE NAME]`, `[DATE]`, `[###-feature-name]` |
| `plan-template.md` | 実装計画の雛形 | `[FEATURE]`, `[DATE]`, `[Language/Version]` |
| `tasks-template.md` | タスク一覧の雛形 | `[FEATURE NAME]`, `[###-feature-name]` |
| `checklist-template.md` | チェックリストの雛形 | `[CHECKLIST TYPE]`, `[FEATURE NAME]`, `[DATE]` |
| `agent-file-template.md` | AI エージェント設定の雛形 | `[PROJECT NAME]`, `[DATE]` |

テンプレートの使われ方:

```
spec-template.md ──── create-new-feature.sh ──→ specs/NNN/spec.md (コピー)
                                                      │
plan-template.md ──── setup-plan.sh ───────────→ specs/NNN/plan.md (コピー)
                                                      │
                      LLM (Agent) がプレースホルダを埋めてファイルを更新
```

1. **スクリプトがテンプレートをコピー**: プレースホルダ付きのままファイルを作成
2. **LLM がプレースホルダを置換**: Agent の指示に従い、コンテキストに応じた値で埋める
3. **結果のファイルにはプレースホルダが残らない**: すべて具体的な内容に置換される

## 状態管理

speckit には専用のデータベースや状態ファイルはありません。
状態は以下の既存の仕組みで暗黙的に管理されます。

### フィーチャーコンテキストの解決

```
「今どのフィーチャーで作業しているか？」
     │
     ├─ 1. 環境変数 SPECIFY_FEATURE が設定されていればそれを使用
     │
     ├─ 2. Git ブランチ名 (例: "001-led-toggle-button") から解決
     │
     └─ 3. specs/ ディレクトリ内の最大番号を自動検出
```

### メモリシステム

`.specify/memory/` ディレクトリは、プロジェクト横断で参照される
永続的な情報を格納します。現在は `constitution.md`（プロジェクト憲法）のみです。

| ファイル | 役割 | 参照するコマンド |
|---------|------|----------------|
| `constitution.md` | プロジェクト原則・制約の定義 | `plan`（Constitution Check）, `analyze`（整合性検証）, `constitution`（更新） |

### copilot-instructions.md（自動更新）

`.github/copilot-instructions.md` は `update-agent-context.sh` により
自動更新されるファイルです。`plan.md` から抽出した技術スタック情報が
書き込まれ、Copilot Chat の全セッションで参照されるグローバルコンテキストとして
機能します。

```
plan.md → update-agent-context.sh → .github/copilot-instructions.md
  (技術スタック情報)                    (Copilot のグローバル設定)
```

## Handoff（コマンド連鎖）

Agent は YAML フロントマターの `handoffs` で次のコマンドを提案できます。
Copilot Chat の UI にボタンとして表示され、ユーザーがクリックすると
次の Agent に処理が委譲されます。

```
constitution ─handoff→ specify ─handoff→ clarify ─handoff→ plan
                                                              │
                                          ┌───────────────────┤
                                          ▼                   ▼
                                      checklist            tasks
                                                              │
                                          ┌───────────────────┤
                                          ▼                   ▼
                                       analyze            implement
```

`send: true` が設定された handoff は、ユーザーの確認なしに自動送信されます。

## 処理フローの具体例: `/speckit.plan`

```
1. ユーザーが "/speckit.plan C言語 + Zephyr RTOS" と入力

2. VS Code が speckit.plan.prompt.md を読み込み
   → agent: speckit.plan → speckit.plan.agent.md を LLM に送信

3. LLM が Agent の手順に従い実行:
   a. ターミナルで setup-plan.sh --json を実行
      → plan-template.md を plan.md にコピー
      → パス情報を JSON で返す

   b. spec.md を読み込み（要件の理解）
   c. constitution.md を読み込み（原則の確認）

   d. plan.md のプレースホルダを具体的な内容で埋める
      - Technical Context → "C (C99/C11)", "Zephyr RTOS" 等
      - Constitution Check → 6 原則への準拠チェック
      - Project Structure → 実際のディレクトリ構成

   e. research.md を生成（技術調査結果）
   f. data-model.md を生成（データモデル）
   g. contracts/ を生成（インターフェース契約）
   h. quickstart.md を生成（テストシナリオ）

   i. ターミナルで update-agent-context.sh を実行
      → copilot-instructions.md を更新

4. Copilot Chat UI に handoff ボタンが表示:
   [Create Tasks] [Create Checklist]
```

## ファイル構成の全体像

```
.github/
├── agents/                              # Agent 定義（LLM への指示書）
│   ├── speckit.constitution.agent.md    #   → constitution.md の更新
│   ├── speckit.specify.agent.md         #   → spec.md の生成
│   ├── speckit.clarify.agent.md         #   → spec.md の明確化
│   ├── speckit.plan.agent.md            #   → plan.md + 設計ドキュメント生成
│   ├── speckit.tasks.agent.md           #   → tasks.md の生成
│   ├── speckit.analyze.agent.md         #   → 読み取り専用の整合性分析
│   ├── speckit.implement.agent.md       #   → ソースコードの実装
│   ├── speckit.checklist.agent.md       #   → チェックリストの生成
│   └── speckit.taskstoissues.agent.md   #   → GitHub Issue への変換
├── prompts/                             # スラッシュコマンド登録
│   └── speckit.*.prompt.md              #   → 対応する Agent へルーティング
├── copilot-instructions.md              # Copilot グローバル設定（自動更新）
└── workflows/
    └── test.yml                         # CI/CD

.specify/
├── memory/
│   └── constitution.md                  # プロジェクト憲法（永続状態）
├── templates/                           # ファイル生成テンプレート
│   ├── spec-template.md
│   ├── plan-template.md
│   ├── tasks-template.md
│   ├── checklist-template.md
│   └── agent-file-template.md
└── scripts/bash/                        # シェルスクリプト
    ├── common.sh                        #   共通関数ライブラリ
    ├── check-prerequisites.sh           #   前提条件チェック
    ├── create-new-feature.sh            #   フィーチャー作成
    ├── setup-plan.sh                    #   計画フェーズ準備
    └── update-agent-context.sh          #   エージェント設定更新

specs/                                   # フィーチャーごとの成果物
└── NNN-feature-name/
    ├── spec.md                          #   仕様書
    ├── plan.md                          #   実装計画
    ├── tasks.md                         #   タスク一覧
    ├── research.md                      #   技術調査
    ├── data-model.md                    #   データモデル
    ├── quickstart.md                    #   テストシナリオ
    ├── checklists/                      #   品質チェックリスト
    └── contracts/                       #   インターフェース契約
```

## まとめ

speckit の動作原理をまとめると:

1. **実行基盤は VS Code + Copilot Chat** — 独自のランタイムは不要
2. **Prompt ファイルがコマンドを登録** — Agent にルーティングするだけ
3. **Agent ファイルが LLM へのプロンプト** — 処理手順を自然言語で記述
4. **シェルスクリプトがコンテキストを解決** — Git ブランチと `specs/` から状態を導出
5. **テンプレートがファイル構造を統一** — プレースホルダを LLM が埋める
6. **Handoff でコマンドを連鎖** — 次のステップを UI ボタンで提案
7. **状態管理は暗黙的** — 専用 DB なし、ファイルシステムが真実の源泉
