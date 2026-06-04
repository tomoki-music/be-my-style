# Singing Handover Docs Index

この index は、Singing 領域の実装前に読むべき handover docs を整理する入口として使う。

Phase24〜31 で Singing Home、Activity Signal、空状態の運用ルールが増えてきたため、今後の Agent が関連 docs を見落とさないように、「どの docs をいつ読むべきか」を明文化する。

## 1. この index の目的

Singing 領域の実装・調整前に、関連する handover docs をすばやく見つけられるようにする。

特に次の作業では、この index から該当 docs を確認する。

- Singing Home のカード追加・表示順変更
- Activity Signal の意味や活動日時判定に関わる変更
- 空状態・データなし表示・初期導線の調整
- 仲間、応援、挑戦、継続に関わるコミュニティ導線の追加

## 2. 必読 docs

Singing 領域の Home / Activity / 空状態に触る場合は、以下を優先して読む。

```text
docs/handover/singing_home_card_guidelines.md
docs/handover/singing_activity_signal_guidelines.md
docs/handover/singing_empty_state_guidelines.md
```

## 3. いつ読むべきか

```text
Home card 追加・表示順変更:
  docs/handover/singing_home_card_guidelines.md

Home card の役割カテゴリや配置判断を確認する:
  docs/handover/singing_home_card_guidelines.md

MusicCommunityHomeBuilder の DTO 一覧や Home 表示順を確認する:
  docs/handover/singing_home_card_guidelines.md

Singing Home の CTA、カード全体リンク、プロフィール導線を触る:
  docs/handover/singing_home_card_guidelines.md

ActivitySignalBuilder や活動日時判定を触る:
  docs/handover/singing_activity_signal_guidelines.md

Activity Signal の target_customer_id、occurred_at、source の意味を使う:
  docs/handover/singing_activity_signal_guidelines.md

空状態・データなし表示を触る:
  docs/handover/singing_empty_state_guidelines.md

初回ユーザー向け fallback や CTA コピーを触る:
  docs/handover/singing_empty_state_guidelines.md
```

判断に迷う場合は、まず `singing_home_card_guidelines.md` を読み、Activity Signal や空状態に関わる部分だけ追加で該当 docs を確認する。

## 4. 共通方針

Singing の実装では、以下を共通方針にする。

```text
DB追加は慎重
既存データ優先
Service Object中心
DTOでViewへ渡す
nil安全
N+1禁止
ランキング感を出さない
人気者システムにしない
スコア比較を出さない
仲間・応援・挑戦・継続を優先
```

Home やコミュニティ導線では、活動量、人気、優劣を見せるのではなく、歌を続けるきっかけ、仲間とのつながり、応援の循環、今日の小さな挑戦を見せる。

## 5. PR 前チェック

PR 前に以下を確認する。

```text
該当 docs を読んだか
MusicCommunityHomeBuilder の DTO 一覧と Home 表示順を確認したか
Home card の役割カテゴリと配置判断を確認したか
表示順を変えた場合、home_card_guidelines を更新したか
ActivitySignalBuilder の意味を変えていないか
空状態が docs 方針とズレていないか
禁止表現を使っていないか
対象 spec を通したか
git diff --check を通したか
```

docs-only の変更では RSpec を省略してよい。省略した場合は、完了報告に理由を明記する。
