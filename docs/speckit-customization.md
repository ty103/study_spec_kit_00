# speckit テンプレートのカスタマイズ

speckit のテンプレートを日本語化・カスタマイズする方法と、
その際の制約事項について解説します。

## テンプレートの一覧

`.specify/templates/` に配置された Markdown ファイルがテンプレートです。

| テンプレート | 用途 | 参照するコマンド |
|-------------|------|----------------|
| `spec-template.md` | 機能仕様書の雛形 | `/speckit.specify` |
| `plan-template.md` | 実装計画の雛形 | `/speckit.plan` |
| `tasks-template.md` | タスク一覧の雛形 | `/speckit.tasks` |
| `checklist-template.md` | チェックリストの雛形 | `/speckit.checklist` |
| `agent-file-template.md` | AI エージェント設定の雛形 | `/speckit.plan`（内部で `update-agent-context.sh` が使用） |

## テンプレートが使われる 2 つの経路

テンプレートは以下の 2 つの異なる方法で参照されます。
カスタマイズ時はそれぞれの経路を理解しておく必要があります。

### 経路 1: スクリプトによるファイルコピー

スクリプトがテンプレートをそのまま `specs/` 配下にコピーします。

| スクリプト | コピー元 | コピー先 |
|-----------|---------|---------|
| `create-new-feature.sh` | `spec-template.md` | `specs/NNN-xxx/spec.md` |
| `setup-plan.sh` | `plan-template.md` | `specs/NNN-xxx/plan.md` |

この経路では**言語の制約はありません**。
テンプレートの中身が日本語であっても、そのままコピーされるだけです。

### 経路 2: Agent（LLM）による読み込みとプレースホルダの置換

Agent ファイル（`.github/agents/*.agent.md`）の指示に従い、
LLM がテンプレートを読み込んで中身を解釈し、プレースホルダを具体的な
内容で埋めてファイルを生成します。

この経路では **Agent の指示とテンプレートの整合性** が重要になります。

## カスタマイズのガイドライン

### 自由に変更できるもの

| 対象 | 例 |
|------|-----|
| テンプレート内の説明文・コメント | `<!-- この部分は必須です -->` |
| `constitution.md` の内容 | 既に日本語で運用中のため、制約なし |
| テンプレート内の `<!-- ACTION REQUIRED: ... -->` コメント | ガイダンス文を日本語化可能 |

### 条件付きで変更できるもの

#### 見出し名の日本語化

テンプレートの見出し名を日本語化すること自体は可能ですが、
Agent ファイルが見出し名でセクションを識別している箇所があるため、
**Agent ファイルも合わせて修正** する必要があります。

**変更が必要な Agent との対応表**:

| テンプレート | Agent ファイル | Agent 内の参照箇所 |
|-------------|---------------|-------------------|
| `spec-template.md` | `speckit.specify.agent.md` | セクション順序と見出しを保持するよう指示 |
| `spec-template.md` | `speckit.clarify.agent.md` | `## Clarifications` セクション、Edge Cases サブセクションの名前 |
| `plan-template.md` | `speckit.plan.agent.md` | テンプレート構造への準拠指示 |
| `tasks-template.md` | `speckit.tasks.agent.md` | テンプレートの構造を使ってタスクを生成 |
| `checklist-template.md` | `speckit.checklist.agent.md` | タイトル・メタセクション・カテゴリ見出し・ID 形式 |

**変更例（spec-template.md の場合）**:

```markdown
# 変更前（英語）
## User Scenarios & Testing *(mandatory)*
### User Story 1 - [Brief Title] (Priority: P1)
## Requirements *(mandatory)*
### Functional Requirements
## Success Criteria *(mandatory)*

# 変更後（日本語）
## ユーザーシナリオ & テスト *(必須)*
### ユーザーストーリー 1 - [タイトル] (優先度: P1)
## 要件 *(必須)*
### 機能要件
## 成功基準 *(必須)*
```

この場合、`speckit.specify.agent.md` 内の以下のような記述も
日本語の見出し名に合わせて修正します:

```markdown
# Agent ファイル内の記述例
5. Write the specification to SPEC_FILE using the template structure...
   → テンプレートの見出しが変わった場合、この指示も修正
```

### 変更を避けるべきもの

#### プレースホルダ名

`[FEATURE NAME]`, `[DATE]`, `[###-feature-name]` などのブラケット形式の
プレースホルダは、LLM が認識して置換する目印として機能しています。

```markdown
# 推奨: プレースホルダは英語のまま、周囲を日本語化
# 機能仕様書: [FEATURE NAME]
**フィーチャーブランチ**: `[###-feature-name]`
**作成日**: [DATE]
**ステータス**: ドラフト

# 非推奨: プレースホルダ自体を日本語化
# 機能仕様書: [機能名]
**フィーチャーブランチ**: `[NNN-フィーチャー名]`
```

#### `plan-template.md` の Technical Context フィールドキー

`update-agent-context.sh` が `plan.md` から技術情報を抽出する際、
以下の正規表現パターンでフィールドを識別しています:

```
**Language/Version**: ...
**Primary Dependencies**: ...
**Storage**: ...
**Project Type**: ...
```

これらのフィールドキーを日本語に変更すると、
`update-agent-context.sh` の `extract_plan_field()` 関数による
パースが失敗します。

**対処法（2 択）**:

1. **フィールドキーは英語のまま維持する**（推奨）

   ```markdown
   ## 技術コンテキスト
   **Language/Version**: C (C99/C11)
   **Primary Dependencies**: Zephyr RTOS, nRF Connect SDK
   ```

2. **スクリプトも合わせて修正する**

   `update-agent-context.sh` 内の `extract_plan_field()` 関数を修正:

   ```bash
   # 変更前
   NEW_LANG=$(extract_plan_field "Language/Version" "$plan_file")

   # 変更後（日本語キーに対応）
   NEW_LANG=$(extract_plan_field "言語/バージョン" "$plan_file")
   ```

#### テンプレートのセクション構造（追加は可、削除は注意）

Agent は特定のセクションの存在を前提に処理を行っています。
セクションの**追加**は自由にできますが、既存セクションの**削除**は
Agent の動作に影響する可能性があります。

```markdown
# OK: セクションの追加
## 要件 *(必須)*
### 機能要件
### 非機能要件        ← 追加（Agent は無視するが問題ない）
### セキュリティ要件   ← 追加

# 注意: 既存セクションの削除
## 要件 *(必須)*
### 機能要件           ← 削除すると Agent が FR-NNN を配置できない
```

## カスタマイズの手順

### ステップ 1: テンプレートを編集

```bash
# 例: spec-template.md を日本語化
vim .specify/templates/spec-template.md
```

### ステップ 2: 対応する Agent ファイルを確認・修正

テンプレートの見出し名や構造を変更した場合、Agent ファイルの
指示文を確認し、必要に応じて修正します。

```bash
# テンプレートを参照している Agent を特定
grep -rn "template" .github/agents/
```

### ステップ 3: 既存の生成済みファイルとの整合性を確認

テンプレート変更後に新しく生成されるファイルは新テンプレートに従いますが、
既存の `specs/` 配下のファイルは自動更新されません。
必要に応じて手動で既存ファイルも更新してください。

### ステップ 4: 動作確認

テンプレートを変更したら、新しいフィーチャーで一度ワークフローを
通して動作を確認することを推奨します:

```bash
/speckit.specify テスト用の新機能
/speckit.plan テスト
/speckit.tasks
```

## カスタマイズ可否の早見表

| 対象 | 日本語化 | 注意点 |
|------|---------|-------|
| テンプレートの説明文・コメント | **可** | 制約なし |
| テンプレートの見出し名 | **条件付き可** | Agent ファイルも合わせて修正が必要 |
| プレースホルダ名 | **英語のまま推奨** | LLM の認識精度に影響する可能性 |
| `plan-template.md` のフィールドキー | **英語のまま推奨** | `update-agent-context.sh` のパースに影響 |
| `constitution.md` | **可** | 既に日本語で運用中 |
| テンプレートへのセクション追加 | **可** | Agent は不明なセクションを無視する |
| テンプレートの既存セクション削除 | **注意** | Agent が前提とするセクションが消えると動作に影響 |
