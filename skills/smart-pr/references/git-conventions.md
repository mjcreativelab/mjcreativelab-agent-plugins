# Git / GitHub 運用規約（smart-pr 用抜粋）

このスキルが従う Git / GitHub 規約。プロジェクト側の `CLAUDE.md` に同等の規約があればそちらを優先する。

## ブランチ運用

- **main / master / develop 等のデフォルトブランチへの直接 push は禁止**。必ず PR 経由でマージする。
- `--no-verify` を付けてフックを skip しない。
- force push（`--force` / `--force-with-lease`）は使わない。merge は fast-forward push になるため通常通り `git push` で済む。

## ブランチ命名規則（参考）

ブランチ作成は smart-pr の責務外（smart-commit / smart-issue-resolve 等が担当）だが、Issue 番号抽出のために形式を理解する必要がある。

フォーマット: `{type}/issue-{番号}-{簡潔な説明}` または `{type}/{簡潔な説明}-YYYYMMDD`

| prefix      | 用途                             |
| ----------- | -------------------------------- |
| `feature/`  | 新機能・機能追加                 |
| `fix/`      | バグ修正                         |
| `refactor/` | リファクタリング（機能変更なし） |
| `docs/`     | ドキュメントのみの変更           |
| `chore/`    | ビルド・CI・依存関係など雑務     |
| `test/`     | テストの追加・修正               |

## ブランチ名から Issue 番号を抽出する

正規表現: `issue-(\d+)`（先頭の `issue-` に続く数字 1 桁以上）

例:
- `feature/issue-42-add-user-search` → `42`
- `fix/issue-100-validation-error` → `100`
- `refactor/extract-validator` → 抽出不可（commit メッセージや本文の `#NN` を別途探す）

抽出できない場合はコミットメッセージ本文の `#NN` 表記を `git log` で検索し、それでも見つからなければ `search_issues` で候補を探してユーザーに確認する。

## PR / Issue の作成ルール

- **作成者を自動アサイン**: PR 作成・Issue 作成時は作成者本人をアサインする。GitHub MCP の `get_me` でログイン名を取得し、`issue_write`（PR にも適用可能）の `assignees` に渡す。
- **既存ラベルから付与**: 新規ラベルは作らない。リポジトリで既に運用されているラベルから変更内容に合うものを選ぶ。
- **Issue 操作は MCP 統一**: `issue_write` を使う（gh CLI との混在を避ける）。
- **`labels` パラメータは上書き**: `issue_write` の `labels` は配列上書きなので、既存ラベルがある場合は取得して結合する。

## 関連 Issue の表記

- `Closes #XX`: PR マージ時に自動で Issue をクローズする
- `Refs #XX`: 参照のみ（自動クローズしない）

複数 Issue がある場合は箇条書きで列挙する。

## 共通の落とし穴

- MCP ツールの `body` パラメータには **実際の改行文字**を含める。`\n` リテラルを渡すと GitHub 上で 1 行表示になる。
- ドラフト PR はユーザーから明示的に指示があった場合のみ。
- GitHub Project への自動追加はしない。
