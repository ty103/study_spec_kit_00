# 議論記録: テスト戦略 — prj.conf 同期・実機テスト・統合テスト自動化

> 日付: 2026-03-04  
> 参加者: 開発者 + Copilot  
> ステータス: 結論済み（一部は将来実施予定）

---

## 1. テスト用 prj.conf とアプリ用 prj.conf の同期

### 背景

- テストプロジェクト（`tests/unit/`）は独立した Zephyr アプリとしてビルドされるため、アプリ直下の `prj.conf` ではなく `tests/unit/prj.conf` が使われる
- 現時点のテスト対象コード（`led_toggle.c`, `fw_update.c`）には `#ifdef CONFIG_xxx` のような Kconfig 依存の分岐がないため、設定が異なってもロジックの動作は同一
- ただし将来 Kconfig 依存の分岐を追加した場合、同期漏れで挙動が変わるリスクがある

### 検討した選択肢

| 方法 | メリット | デメリット |
|------|---------|-----------|
| アプリ prj.conf を丸ごとコピー | 完全一致 | MCUboot パーティション変更・UART 競合・ログバックエンド問題でテスト FW が壊れる |
| 共通 conf ファイル分離 | 構造的 | ファイルが増える |
| CI 差分チェック | 既存構成を変えない | 同期漏れは CI まで気づかない |
| ドキュメント規約のみ | シンプル | 人間が忘れるリスク |

### 結論: `[SYNC]` / `[NO-SYNC]` カテゴリ方式を採用

- `prj.conf` の設定をカテゴリ分けしてコメント付与
  - `[SYNC]`: ロジックに影響する設定（`CONFIG_GPIO`, `CONFIG_DK_LIBRARY`, `CONFIG_LOG`, `CONFIG_MCUMGR` 等）
  - `[NO-SYNC]`: ハードウェア/ビルドインフラ設定（MCUboot, RTT, Flash, UART 等）— テスト FW に入れると壊れるものを含む
  - `[NO-SYNC]`: メモリチューニング — 害はないが同期管理のコストに見合わない
- `tests/unit/boards/nrf52840dk_nrf52840.conf` に `[SYNC]` 設定のみを反映
- `scripts/check-conf-sync.sh` で同期チェックを自動化（`--fix` で自動修正も可能）

### なぜ全設定コピーがだめか（具体的な理由）

| 設定 | テスト FW に入れるとどうなるか |
|------|------|
| `CONFIG_BOOTLOADER_MCUBOOT=y` | リンカスクリプトが MCUboot パーティション前提に変わり、テスト FW 単体では起動できない |
| `CONFIG_MCUMGR_TRANSPORT_UART=y` | Twister が UART でテスト結果を読む。MCUmgr も UART を使うと競合する |
| `CONFIG_LOG_BACKEND_UART=n` | Twister は UART ログからテスト結果を読むため、無効にすると結果が取得できない |
| `CONFIG_USE_SEGGER_RTT=y` | 害はないが意味もない |

---

## 2. 実機ロジックテスト（nrf52840dk での ztest）の意義

### 質問

> native_sim では不足で、ロジックテストを実機でやらないと見つからない不具合が具体的に想像できない

### 結論: native_sim で十分。実機ロジックテストの優先度は低い

native_sim は Linux プロセスとして Zephyr カーネルがそのまま動く。テスト対象関数が以下の条件を満たす限り、CPU アーキテクチャの違いは結果に影響しない：

- 純粋なロジック（状態マシン、条件分岐、演算）
- ハードウェアレジスタに直接アクセスしない
- Zephyr カーネル API（`k_timer`, `k_sem` 等）のセマンティクスは native_sim でも忠実に再現される

### native_sim で見つからない不具合は存在するが、ztest の範疇を超える

| 不具合の種類 | 具体例 | なぜ native_sim で見つからないか |
|---|---|---|
| アライメント違反 | `uint32_t` を奇数アドレスから読む | x86 は非アライメントアクセスを許容するが ARM Cortex-M は HardFault |
| スタックオーバーフロー | 深い再帰がデフォルトスタックサイズを超える | native_sim のスタックは Linux プロセスのスタック（8MB）。実機は 2KB 程度 |
| 割り込みレイテンシ競合 | ISR 内の処理が長すぎて別の割り込みを逃す | native_sim は疑似的な割り込みシミュレーション |
| volatile/メモリバリア不足 | コンパイラ最適化で共有変数の読み書き順序が変わる | x86 は強いメモリモデル。ARM は弱いメモリモデルで再順序化が起きる |

これらは**統合テスト/システムテスト**で検出すべき問題であり、ユニットテスト（ztest）で狙うものではない。

### 推奨テスト戦略

```
native_sim ロジックテスト（ztest）
  → 状態遷移、条件分岐、境界値、エラーパスの網羅的テスト
  → CI で毎コミット自動実行（高速・確実）

実機手動テスト（quickstart.md）
  → ボタン操作 → LED 確認、DFU フロー
  → スタック/タイミング/ハードウェア連携の検証

nrf52840dk 対応は「選択肢として残す」位置づけ
  → testcase.yaml に設定済み。必要時にすぐ使えるインフラ
  → CI で常時回す必要はない
```

---

## 3. 統合テスト/システムテストの自動化

### 質問

> 統合テスト/システムテストも一部自動化したい

### 結論: 段階的に実現可能。今は実施せず将来の選択肢として記録する

#### レベル 1: ビルド検証 + スタック/メモリ安全性（追加コスト: ほぼゼロ）

Kconfig の安全機構を有効化してビルド → フラッシュ → 起動 → クラッシュしなければ PASS。

```
CONFIG_HW_STACK_PROTECTION=y   # MPU ベース。違反時に即 HardFault → Twister が FAIL 検出
CONFIG_STACK_SENTINEL=y        # スタック底にカナリア値を書き、破壊を検出
CONFIG_ASSERT=y                # __ASSERT が UART に出力 → Twister がキャッチ
```

testcase.yaml にオーバーレイ conf を追加するだけで実現可能。

#### レベル 2: GPIO ループバックテスト（追加コスト: ワイヤ数本）

出力ピンと入力ピンをジャンパワイヤで物理接続し、GPIO ドライバの動作を自動検証。

```c
ZTEST(gpio_integration, test_loopback)
{
    gpio_pin_set(dev, 3, 1);   // P0.03 (出力)
    k_msleep(1);
    zassert_equal(gpio_pin_get(dev, 4), 1);  // P0.04 (入力) で検証
}
```

#### レベル 3: DFU フロー pytest（追加コスト: スクリプト開発）

Twister の `harness: pytest` を使い、`mcumgr` CLI 経由で DFU アップロード → バージョン確認を自動化。

```yaml
tests:
  app.dfu.integration:
    harness: pytest
    platform_allow:
      - nrf52840dk/nrf52840
    tags: integration slow
```

```python
def test_dfu_upload_and_confirm():
    # 1. v0.0.2 イメージを MCUmgr でアップロード
    # 2. イメージリストでスロット1に v0.0.2 があることを確認
    # 3. テスト確認 → リブート → 新 FW で起動
    # 4. 起動後のバージョン確認
```

#### レベル 4: HiL タイミングテスト（追加コスト: ボード 2 台）

テストドライバ DK がボタン押下をシミュレート → テスト対象 DK の LED 応答を GPIO で読み取り → 応答時間を測定。

```
[テストドライバ DK]          [テスト対象 DK]
  GPIO OUT ──────────────→ Button GPIO IN
  GPIO IN  ←────────────── LED GPIO OUT
```

### 投資対効果の優先順位

| レベル | 内容 | 追加コスト | 検出できる問題 | 推奨時期 |
|:---:|---|---|---|---|
| 1 | スタック/メモリ安全性 | Kconfig 追加のみ | スタック破壊、アサーション違反 | 次の機能追加時 |
| 2 | GPIO ループバック | ワイヤ数本 | GPIO ドライバの動作不良 | GPIO 制御が複雑化した時 |
| 3 | DFU フロー pytest | スクリプト開発 | DFU 失敗、バージョン不整合 | DFU 安定後 |
| 4 | HiL タイミングテスト | ボード 2 台 | 応答遅延、割り込み漏れ | 製品品質が必要な段階 |

---

## 4. RTT でのテスト結果読み取り

### 質問

> Twister が UART ではなく RTT でテスト結果を読むことはできないか？  
> アプリビルドと異なるログバックエンド設定では意味が薄れるのでは

### 結論: 技術的には可能だが、現時点では不要

- Twister の `--device-serial-pty` オプションで任意の PTY スクリプトを指定可能
- `JLinkRTTLogger` → PTY ブリッジスクリプト → Twister という構成で RTT 読み取りは実現可能
- ただし JLink SDK のインストールと PTY ブリッジスクリプトの開発が必要
- テストの目的（純粋ロジック検証）に対しては、ログバックエンドの違いは影響しない
- **実施しないことに決定**

---

## 関連ファイル

| ファイル | 役割 |
|---------|------|
| `prj.conf` | `[SYNC]` / `[NO-SYNC]` カテゴリコメント付き |
| `tests/unit/boards/nrf52840dk_nrf52840.conf` | `[SYNC]` 設定の実機テスト用オーバーレイ |
| `scripts/check-conf-sync.sh` | `[SYNC]` セクション同期チェック（`--fix` 対応） |
| `tests/unit/testcase.yaml` | `native_sim` + `nrf52840dk/nrf52840` 両対応 |
| `tests/unit/CMakeLists.txt` | native_sim のみスタブヘッダを適用する条件分岐 |
