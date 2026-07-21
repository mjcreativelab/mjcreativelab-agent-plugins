# グローバル設定ミラーのサニタイズ（global-config-pull / push）

対象: `internal/global-config-pull/SKILL.md`・`internal/global-config-push/SKILL.md`・`dotfiles/claude/settings.json`・`CLAUDE.md`

## 背景

`/global-config-pull` の実行中に、public リポジトリのミラー `dotfiles/claude/` へ社内情報が入ることが判明した。

- **未公開だったもの（今回コミット前に検出・除去）**: `~/.claude/CLAUDE.md` に別セッションが追記した企業プロキシの節に、社内テナントの MITM CA ホスト名が含まれていた
- **すでに公開済みだったもの**: `dotfiles/claude/settings.json` の `enabledPlugins` 19 エントリと `extraKnownMarketplaces` 2 件に、社内 GitHub org・**非公開リポジトリのパス 2 件**・社内 plugin 名が含まれていた（既存コミットに存在）

## 自分で判断した事項

- **CLAUDE.md 側は「一般化」で対応**: 実ホスト名を除去し、確認手段（`security find-certificate ... | openssl x509 -noout -subject`）を書く形にした。手順の実用性を保ちつつ企業特定情報を消せ、push で逆流しても矛盾しない。製品名（Netskope）は残した — 回避策が MITM 型プロキシ固有で、診断上の価値があり、企業を特定しないため
- **settings.json 側は「サニタイズ + マージ」**: ミラーから非公開 marketplace のエントリを除去し、push 時に live 側の該当エントリを復元する。単純にミラーを書き換えるだけだと、push が平文コピーのため偽の値が live に書き戻りプラグイン設定が壊れる
- **除外対象の marketplace 名はリポジトリに置かない**: 名前自体が社内情報なので、ローカル限定の `~/.claude/.config-sync-exclude`（同期対象外）に列挙し、両スキルがそれを読む。ファイルが無い環境ではサニタイズをスキップして従来動作にフォールバックする
- **settings.json を同期対象から外す案は採らなかった**: permissions・hooks・statusLine 等の追跡価値が大きく、失うものが大きい。サニタイズで消えるのは非公開 marketplace 由来の 19/33 エントリのみで、残りは従来どおり追跡される
- **`~` の逆正規化を push に追加**: pull が `$HOME` → `~` に正規化する一方 push は平文コピーだったため、push すると `permissions.additionalDirectories` に `~/...` リテラルが書き戻る既存欠陥があった（live は現在すべて絶対パス）。settings.json の反映経路を書き換えるついでに `sed` で展開するようにした
- **`jq` 不在環境では settings.json を反映しない**: 単純コピーで代替するとサニタイズ済みミラーがそのまま live を潰すため、飛ばして報告する方が安全
- **`~/.claude/chrome/` は除外リストへ**: Claude in Chrome の native host wrapper で、CLI が自動生成しマシン固有の絶対パスと CLI バージョンを埋め込む生成物のため
- **`effortLevel` の記述は値を書かない形に直した**: グローバル CLAUDE.md に「（現在 "max"）」と実値が書かれていたが、実際は `xhigh` でドリフトしていた。`xhigh` に書き換えると同じ陳腐化を繰り返すため、値を書かず確認コマンド（`jq -r .effortLevel ~/.claude/settings.json`）を示す形にした

## 検証

- 両 SKILL.md の bash ブロックを抽出して `bash -n`: pull 6 ブロック・push 5 ブロックすべて PASS
- サニタイズ実行後のミラー: `zozo|st-tech|goskope|near-fashion` の grep 0 件、`jq -e .` PASS、`enabledPlugins` 33 → 14 件
- push マージを live へ書かず一時ファイルで実行し、`jq -S` 正規化して live と `diff`: **完全一致**（`enabledPlugins` 33 件・`extraKnownMarketplaces` 7 件が復元、`~` リテラル 0 件）

## 残課題

- 既存コミットの履歴には社内 org・非公開リポジトリのパスが残る。除去には履歴書き換えが必要だが、本リポジトリは git tree-SHA ベースで配布（`npx skills` の `#v<X.Y.Z>` pin）しており、書き換えると配布済み pin が壊れるうえ force push はプロジェクト規約で禁止のため実施していない。HEAD からの除去と今後の流入停止に留める（ユーザー判断で許容済み）
