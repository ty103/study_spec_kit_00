# ztest / Twister よくある質問（FAQ）

> **対象読者**: ztest・Twister を使い始めた開発者
>
> **前提知識**: [ztest と Twister 入門ガイド](ztest-and-twister-guide.md) を読んでいること

---

## 目次

1. [テスト実行時に RTT ログを出せる？出力すべき？](#1-テスト実行時に-rtt-ログを出せる出力すべき)
2. [実機に書き込んでテストできる？native_sim 用のコードを流用できる？](#2-実機に書き込んでテストできるnative_sim-用のコードを流用できる)
3. [テスタブルな設計って？ztest を前提に何に気をつけるべき？](#3-テスタブルな設計ってztest-を前提に何に気をつけるべき)
4. [ztest で TDD できる？Copilot と組み合わせて自動化できる？](#4-ztest-で-tdd-できるcopilot-と組み合わせて自動化できる)
5. [テストコードのカバレッジを測ることはできる？](#5-テストコードのカバレッジを測ることはできる)

---

## 1. テスト実行時に RTT ログを出せる？出力すべき？

### 結論：native_sim では RTT は使えない（代わりにコンソールログが出る）。実機テストなら使える。

**RTT（Real-Time Transfer）** は J-Link デバッガ経由でマイコンと通信するプロトコルです。native_sim は PC 上で動くため J-Link は関与せず、RTT は使えません。

native_sim でのテスト時は、代わりに **Zephyr の `LOG_*` マクロ** が標準出力（コンソール）に出力されます。現在のプロジェクトでは `prj.conf` に `CONFIG_LOG=y` が設定されているので、テスト対象コード内の `LOG_INF()` / `LOG_ERR()` などはコンソールに表示されます。

### 出力すべきか？

テストコード自体にはログを入れないのが一般的です。アサーションの失敗メッセージで十分だからです。ただし、テスト対象の実装コードにログがあるのは問題ありません。デバッグ時に `--verbose` をつければ確認できます。

---

## 2. 実機に書き込んでテストできる？native_sim 用のコードを流用できる？

### 結論：できる。テストコードはそのまま流用できる。

Twister は native_sim 以外のプラットフォームでもテストを実行できます。

### 実現方法

`testcase.yaml` の `platform_allow` に実機ボードを追加します：

```yaml
tests:
  app.led_toggle_button.unit:
    tags:
      - button
      - led
      - unit_test
    platform_allow:
      - native_sim
      - nrf52840dk/nrf52840    # 実機を追加
```

実行コマンド：

```bash
west twister -T tests/unit -p nrf52840dk/nrf52840 --device-testing \
    --device-serial /dev/ttyACM0
```

| オプション | 意味 |
|---|---|
| `--device-testing` | 実機でテストすることを指示 |
| `--device-serial` | UART シリアルポートを指定（テスト結果の受信用） |

### テストコードの流用について

**ztest のテストコード自体は全く同じものが動きます。** `ZTEST()` や `zassert_equal()` はプラットフォームに依存しません。

ただし注意点が1つあります。現在のプロジェクトでは `dk_buttons_and_leds.h` のスタブを使っています。実機テストの場合は本物の SDK ヘッダが使われるため、CMakeLists.txt でスタブの適用を native_sim に限定し、実機向けにはボード固有の設定ファイル（`boards/nrf52840dk_nrf52840.conf`）で `CONFIG_DK_LIBRARY=y` を有効にする必要があります。本プロジェクトではこの対応済みです。

### native_sim と実機テストの比較

| | native_sim | 実機 |
|---|---|---|
| テストコード | そのまま使える | そのまま使える |
| スタブ | 必要（stubs/） | 不要（本物の SDK を使う） |
| ビルド時間 | 数秒 | 数十秒 |
| 実行速度 | 即座 | 書き込み＋実行で数十秒 |
| 推奨用途 | 日常開発（TDD） | リリース前の最終確認 |

---

## 3. テスタブルな設計って？ztest を前提に何に気をつけるべき？

### 核心：「ロジック」と「ハードウェア操作」を分離する

現在のプロジェクトの `led_toggle.c` は、まさにテスタブルな設計の好例です。

### テスタブル設計の原則

#### (1) ハードウェアを直接操作しない

```c
// ❌ テストしにくい — GPIO を直接操作している
void button_handler(uint32_t state, uint32_t changed) {
    if (changed & BIT(0) && state & BIT(0)) {
        dk_set_led_on(DK_LED1);   // ← ハードウェア依存！
    }
}

// ✅ テストしやすい — ロジックだけを行い、結果を返す
uint32_t led_toggle_process(uint32_t button_state, uint32_t has_changed) {
    uint32_t pressed = has_changed & button_state;
    if (pressed & DK_BTN1_MSK) {
        led_state ^= DK_LED1_MSK;  // ← ビットマスク演算のみ
    }
    return led_state;  // ← 呼び出し元が GPIO を操作する
}
```

テストコードでは GPIO を使わずに `led_toggle_process()` の戻り値を検証するだけで済みます。

#### (2) 状態をリセットできるようにする

```c
// ✅ 状態リセット関数を用意する
void led_toggle_reset(void) {
    led_state = 0;
    last_had_press = 0;
}
```

これにより各テストケースの `before_each` で状態をクリーンにでき、テスト同士が干渉しません。

#### (3) グローバル変数を最小化し、アクセサ関数を用意する

```c
static uint32_t led_state;  // static で隠蔽

uint32_t led_toggle_get_state(void) {  // 外部からは関数経由で取得
    return led_state;
}
```

#### (4) 外部依存は「注入可能」にする

コールバックや関数ポインタで外部依存を渡す設計にすると、テスト時に偽の実装（モック/スタブ）に差し替えられます。

```c
// ✅ LED を操作する関数をコールバックで受け取る
typedef void (*led_set_fn)(uint32_t mask);
void led_controller_init(led_set_fn set_on, led_set_fn set_off);
```

### テスタブル設計チェックリスト

| チェック項目 | 具体策 |
|---|---|
| 関数は GPIO / UART などを直接呼んでいないか？ | ロジックと I/O を分離する |
| 内部状態をリセットできるか？ | `xxx_reset()` / `xxx_init()` を用意する |
| 関数の入出力が明確か？ | 引数で入力、戻り値で出力。副作用を最小化 |
| 外部依存を差し替えられるか？ | コールバック / 関数ポインタ / スタブヘッダ |

---

## 4. ztest で TDD できる？Copilot と組み合わせて自動化できる？

### 結論：TDD は十分に可能。Copilot との組み合わせも実現できる。

### TDD のサイクル

```
1. テストを書く（Red — 最初は失敗する）
2. 最小限の実装を書く（Green — テストが通る）
3. リファクタリング（Refactor — コードを整理）
4. 1 に戻る
```

ztest + Docker で、このサイクルを以下のように回せます：

```bash
# テストコードを書く → 実行（Red）
./scripts/test-docker.sh

# 実装コードを書く → 実行（Green）
./scripts/test-docker.sh

# リファクタリング → 実行（Refactor で壊していないか確認）
./scripts/test-docker.sh
```

### Copilot に TDD を実践させる方法

#### 方法 1: プロンプトで指示する

```
以下の仕様に対して、TDD スタイルで実装してください。

1. まず tests/unit/src/ にテストコードを書く
2. 次に src/ に最小限の実装を書く
3. テストコマンド `./scripts/test-docker.sh` を実行して確認する
4. 失敗したら修正し、合格するまで繰り返す

仕様: [ここに仕様を記述]
```

#### 方法 2: カスタムインストラクション（`.github/copilot-instructions.md`）に TDD ルールを追加する

```markdown
## TDD ルール

- 新しい関数を実装する際は、必ず先にテストコードを書くこと
- テストコードを書いたら `./scripts/test-docker.sh` を実行して Red（失敗）を確認すること
- 実装コードを書いたら再度テストを実行して Green（成功）を確認すること
- テストが通らない実装をコミットしないこと
```

#### 方法 3: VS Code タスク + Copilot の組み合わせ

`.vscode/tasks.json` にテスト実行タスクを定義すると、Copilot がコード生成後にタスクを呼び出すよう指示できます：

```json
{
  "label": "Run Unit Tests (Docker)",
  "type": "shell",
  "command": "./scripts/test-docker.sh",
  "group": "test",
  "problemMatcher": []
}
```

### 現実的な限界

- Copilot は **テストの自動実行結果を見て自律的にコードを修正する** ことは現時点では限定的（Agent モードを使えば可能な場合もある）
- 「テストを書く → 実装を書く → テストを実行」のサイクルを **完全自動化** するのは難しいが、**半自動化**（Copilot にテストと実装を生成させ、手動でテストを走らせる）は十分実用的

---

## 5. テストコードのカバレッジを測ることはできる？

### 結論：できる。Twister + gcov/lcov で実現可能。

native_sim は通常の GCC でビルドされるため、**gcov（GCC のカバレッジツール）** がそのまま使えます。

### 実行方法

```bash
west twister -T tests/unit -p native_sim --coverage --coverage-tool gcovr
```

| オプション | 意味 |
|---|---|
| `--coverage` | カバレッジ計測を有効にする（`-fprofile-arcs -ftest-coverage` が付与される） |
| `--coverage-tool gcovr` | レポート生成に gcovr を使用する（HTML/XML レポートを出力可能） |

### 出力されるレポート

```
twister-out/coverage/
├── index.html          ← ブラウザで開けるカバレッジレポート
├── coverage.xml        ← CI ツール用の XML レポート
└── ...
```

### Docker 環境での実行

Docker コンテナ内で実行するには、コンテナに `gcovr` をインストールする必要があります。**本プロジェクトでは `Dockerfile.test` に `gcovr` が含まれており、`test.sh` に `--coverage` オプションが用意されているため、以下のコマンドだけでカバレッジ計測が可能です。**

```bash
# macOS の場合（Docker 経由）
./scripts/test-docker.sh --coverage

# Linux の場合（Docker 不要）
./scripts/test.sh --coverage
```

テスト成功後、レポートの場所が表示されます：

```
 ✅ All tests PASSED

 📊 カバレッジレポート:
   HTML: twister-out/coverage/index.html
   XML:  twister-out/coverage/coverage.xml
```

### カバレッジで分かること

| 種類 | 意味 |
|---|---|
| **行カバレッジ** | 各行が実行されたかどうか |
| **分岐カバレッジ** | if/else の各分岐が通ったかどうか |
| **関数カバレッジ** | 各関数が呼ばれたかどうか |

例えば `led_toggle.c` のカバレッジが 85% なら、15% のコードパスがテストで通っていないことが分かります。
