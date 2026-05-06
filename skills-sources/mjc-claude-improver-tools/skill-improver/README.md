# skill-improver

既存スキル（`SKILL.md`）を **skill-creator への eval 委譲**（Phase 1）と **機械的な静的チェック**（Phase 2）の 2 フェーズで仕上げる軽量ツール。

## どんなケースで使うか

- スキルを新規作成・大幅改訂したあと、品質チェックを通したい
- 「スキルが効かない」「トリガーされない」「500 行を超えそう」と感じる
- `TODO` / `FIXME` 残留、参照ファイルのリンク切れ、シェルスクリプトの構文エラーなど、機械的に拾える問題を一掃したい
- コンテキスト管理設計（再 Read ルール、中間データ外部化、API レスポンスの絞り込み等）を検証したい

使わない場面:

- 新規スキルを作りたい → `skill-creator` を直接使う
- 指示文の曖昧さを別エージェントの実行で炙り出したい → `empirical-prompt-tuning` を使う
- PR / 差分のコードレビュー → `/code-reviewer` などを使う

## 使い方

```
/skill-improver <skill-directory-path>
/skill-improver <skill-directory-path> -p <追加の改善指示>
```

### 例

```
/skill-improver .claude/skills/my-skill
/skill-improver packages/mjc-git-workflow-tools/skills/smart-commit -p "コンテキスト管理を重点的に"
/skill-improver .claude/skills/deploy -p "eval は不要、対話的に改善したい"
```

## オプション

| オプション        | 説明                                                 |
| ----------------- | ---------------------------------------------------- |
| `-p <プロンプト>` | `skill-creator` に渡す追加の改善指示                 |

## 2 フェーズ構成

### Phase 1（本体）: skill-creator による eval 駆動改善

- 対象スキルの読み込みより先に `skill-creator` を Skill ツール経由で呼び出す（= インストール確認を兼ねる）
- eval ループは最大 1 iteration に制限（Phase 2 のコンテキスト予算を確保するため）
- Phase 1 の結果は `/tmp/skill-improver-phase1-<スキル名>.md` に書き出される

### Phase 2: コンテキスト管理 + 静的チェック

Phase 1 のレポートファイルが存在することを **物理ゲート** として検証してから実行する。

- 読み込みタイミング / 圧縮耐性 / 中間データの外部化 / API レスポンスの絞り込み 等の設計チェック
- `TODO` / `FIXME` 残留、テンプレート未カスタマイズ、リンク切れ、`bash -n` での構文チェック

## 前提条件

`skill-creator` プラグインがインストール済みであること。

```
/plugin install skill-creator@claude-plugins-official
```

未インストールの場合は本スキルの実行は中止され、インストール手順が案内される。

## 元になったスキル

本スキルは Anthropic 公式の [skill-creator](https://github.com/anthropics/skills/tree/main/skills/skill-creator) を呼び出すラッパーとして設計している。`skill-creator` が短い eval で検出しにくい「長い会話・コンテキスト圧縮時に顕在化する問題」と「静的に検出できる問題」を、Phase 2 で補完する位置付け。

skill-creator との補完関係の詳細は [パッケージ README](../../README.md) を参照。

## 推奨: 新規セッションで実行する

このスキルは **作業セッションとは別の新規セッションで実行する** ことを推奨する。

- 対象スキルの読み込みと `skill-creator` eval で一定のトークンを消費するため、クリーンなコンテキストで開始する方が安定する
- **スキル改修が一段落したら、新規セッションで `/skill-improver <skill-path>` を実行するのがベスト**
