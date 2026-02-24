# メモリ使用量レポート

**生成日時**: 2026-02-24 21:53:56
**ビルドディレクトリ**: `/Users/yamajitakashi/nordic/sdd/study_spec_kit_00/build/study_spec_kit_00`
**ターゲット**: nRF52840DK (PCA10056)
**根拠**: constitution.md VI. メモリバジェット管理

## サマリ

| 区分 | 使用量 | 全容量 | 使用率 | 閾値 (80%) | 判定 |
|------|--------|--------|--------|--------|------|
| Flash (ROM) | 45.75 KB (46852 bytes) | 1024 KB | 4% | 819 KB | ✅ PASS |
| RAM | 9.84 KB (10077 bytes) | 256 KB | 3% | 204 KB | ✅ PASS |

## Flash 内訳（上位モジュール）

| モジュール | サイズ (bytes) | サイズ (KB) |
|-----------|---------------|-------------|
| ZEPHYR_BASE | 29872 | 29.17 KB |
| WORKSPACE | 9000 | 8.78 KB |
| (no paths) | 4366 | 4.26 KB |
| (hidden) | 3412 | 3.33 KB |
| OUTPUT_DIR | 202 | .19 KB |

## RAM 内訳（上位モジュール）

| モジュール | サイズ (bytes) | サイズ (KB) |
|-----------|---------------|-------------|
| (no paths) | 4493 | 4.38 KB |
| ZEPHYR_BASE | 3965 | 3.87 KB |
| WORKSPACE | 1558 | 1.52 KB |
| (hidden) | 61 | .05 KB |

## 閾値ポリシー

- **Flash**: 1024 KB の 80%（819 KB）を超過した場合、Complexity Tracking テーブルに正当化を記録する（MUST）
- **RAM**: 256 KB の 80%（204 KB）を超過した場合、Complexity Tracking テーブルに正当化を記録する（MUST）
- 根拠: `.specify/memory/constitution.md` — 原則 VI. メモリバジェット管理
