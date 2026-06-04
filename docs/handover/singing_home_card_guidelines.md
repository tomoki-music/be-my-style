# Singing Home Card Guidelines

このガイドは、Singing Home に体験カードを追加・調整するときの判断基準として使う。

Singing 関連 docs の入口は `docs/handover/singing_index.md` を参照する。Home card、Activity Signal、空状態のどれを読むべきか迷った場合は、まず index で確認する。

Singing Home は「歌唱診断サイト」のダッシュボードではなく、「歌を楽しみながら成長する音楽コミュニティ」へ戻ってくる場所として設計する。

## 1. Home UX 方針

BeMyStyle Singing は、診断結果を確認するだけの場所ではない。

目指す体験:

```text
歌を楽しみながら成長する音楽コミュニティ
```

Home は単なるダッシュボードではなく、ユーザーが次のように感じられる場所にする。

```text
帰ってきたくなる場所
```

そのため、Home 上のカードは「評価」「順位」「成果の優劣」よりも、「続き」「仲間」「応援」「今日の小さな一歩」を優先する。

## 2. MusicCommunityHomeBuilder の役割

`Singing::MusicCommunityHomeBuilder` は、Singing Home で表示するカード DTO を集約する Builder として扱う。

View に直接複雑な判定や取得処理を書かず、基本の流れを次の形に保つ。

```text
Service Object
↓
DTO
↓
View
```

`MusicCommunityHomeBuilder` は `Singing::HomesController#top` から呼び出され、`app/views/public/lp/singing.html.haml` に渡す Home 全体の DTO を組み立てる。Challenge Circle 由来の `today_mission` や、Home 下部の `community_summary` / `recommended_event` / `growth_summary` もここでまとめる。

`encouragement_inbox` と `community_feed` は現状 `MusicCommunityHomeBuilder` の属性ではなく、同じ Home 画面で `Singing::HomesController#top` から別 DTO として渡される隣接カードとして扱う。

## 3. 現在の MusicCommunityHomeBuilder DTO 一覧

`Singing::MusicCommunityHomeBuilder::MusicCommunityHome` の現在の属性は以下。

```text
hero_message
home_cta
today_mission
gentle_return_flow
community_memory
personal_music_story
music_milestones
community_recommendation
return_motivation
music_friends
friend_activity_highlights
community_network
suggested_musicians
growth_circles
ecosystem
reputation
growth_partnerships
music_social_graph
community_summary
recommended_event
growth_summary
```

表示名と Builder 属性名が異なる主なカード:

```text
Community Reputation: reputation
Music Community Ecosystem: ecosystem
仲間: community_summary
イベント: recommended_event
成長: growth_summary
CTA: home_cta
```

Home 画面に表示される隣接 DTO:

```text
encouragement_inbox
community_feed
```

これらは Home 表示順には含めるが、`MusicCommunityHomeBuilder` に属性追加されていない限り、Builder DTO 一覧とは分けて考える。

主なカードの役割:

| 表示名 | Builder / DTO | 役割 |
|---|---|---|
| Hero | `hero_message` | Home 全体の入口として、今日の音楽時間へ迎える |
| Gentle Return Flow | `gentle_return_flow` | 間が空いたユーザーを責めずに前回の続きへ戻す |
| Community Memory | `community_memory` | 前回までの活動や仲間との記憶を思い出せるようにする |
| Personal Music Story | `personal_music_story` | 自分の音楽の足跡を物語として振り返る |
| Music Milestones | `music_milestones` | 最近迎えた音楽の節目を表示する。スコアではなく体験の節目を扱う。 |
| Community Recommendation | `community_recommendation` | 今日の次の一歩を、コミュニティ導線へつなぐ |
| Return Motivation | `return_motivation` | 継続や再開の気持ちを軽く後押しする |
| Music Friends | `music_friends` | 最近つながりのある仲間を見せる |
| Friend Activity Highlights | `friend_activity_highlights` | 仲間の最近の音楽時間を見せる |
| Today's Mission | `today_mission` | 今日やる小さな行動を提示する |
| Encouragement Inbox | `encouragement_inbox` | 仲間から届いた応援を受け取る |
| Community Feed | `community_feed` | 仲間の挑戦や活動の流れを見せる |
| Suggested Musicians | `suggested_musicians` | 近い挑戦や共通点から新しい仲間に出会う |
| Community Reputation | `reputation` | 活動と応援の積み重ねをコミュニティ上の存在感として見せる |
| Growth Partnerships | `growth_partnerships` | 一緒に成長できる仲間を見つける |
| Music Social Graph | `music_social_graph` | 応援、成長タイプ、挑戦、イベントで広がる音楽の輪を見せる |
| Growth Circles | `growth_circles` | 近い方向を向く小さな仲間の輪を見せる |
| Music Community Ecosystem | `ecosystem` | コミュニティ全体の動きを見せる |
| Community Network | `community_network` | ユーザーと近い仲間をプロフィール導線へつなぐ |
| 仲間 | `community_summary` | Mission / Challenge / Growth Community の要約を見せる |
| イベント | `recommended_event` | 今日の挑戦から音楽の場へつなぐ |
| 成長 | `growth_summary` | 診断や成長タイプの流れを要約する |
| CTA | `home_cta` | ユーザー状態に応じた主要行動へ導く |

## 4. Home カード役割カテゴリ

Home card が増えた場合は、まず「どのカテゴリの役割を担うカードか」を確認する。

| カテゴリ | 対象カード | 目的 |
|---|---|---|
| 復帰・安心 | Gentle Return Flow / Return Motivation | 離脱後も責めずに戻れる。少し間が空いても、また少し始められる状態を作る |
| 続き・記憶 | Community Memory | 前回来た時の続きがあり、自分の音楽時間が途切れていないと感じられるようにする |
| 自分の物語 | Personal Music Story | 自分が積み重ねてきた体験を、成果ではなく物語として感じられるようにする |
| 次の一歩 | Community Recommendation / Today's Mission | 今日何をすればよいか分かり、迷わず小さな行動へ進めるようにする |
| 仲間・つながり | Music Friends / Friend Activity Highlights / Suggested Musicians | 自分と関係のある仲間がいることを感じ、新しい仲間とも自然に出会えるようにする |
| 応援・交流 | Encouragement Inbox / Community Feed | 応援を受け取り、仲間の活動を見ることで、コミュニティに参加している感覚を作る |
| 成長・挑戦 | Music Milestones / Growth Circles / Growth Partnerships / Community Reputation | 小さな節目を振り返り、成長の実感を作る。自分らしい成長や挑戦を、比較ではなく仲間との積み重ねとして感じられるようにする |
| 世界観・探索 | Music Social Graph / Music Community Ecosystem / Community Network / 仲間 / イベント / 成長 / CTA | BeMyStyle Singing の世界観を理解し、探索し、登録・参加へ進めるようにする |

新しいカードを追加する時は、次を確認する。

- どのカテゴリに属するか
- 既存カードと役割が重複していないか
- 上部に置くほど「自分ごと」になっているか
- 下部に置くほど「探索・世界観」になっているか
- CTA が既存導線と重複しすぎていないか

カテゴリが既存カードと近い場合は、新規カードにする前に既存カードの copy、DTO、表示条件、CTA の調整で目的を満たせないか確認する。

## 5. 現在の Home 表示順

現在の Home は、上から以下の順で表示する。

```text
Hero
Gentle Return Flow
Community Memory
Personal Music Story
Music Milestones
Community Recommendation
Return Motivation
Music Friends
Friend Activity Highlights
Today's Mission
Encouragement Inbox
Community Feed
Suggested Musicians
Community Reputation
Growth Partnerships
Music Social Graph
Growth Circles
Music Community Ecosystem
Community Network
仲間
イベント
成長
CTA
```

実装上の主な入口:

- View: `app/views/public/lp/singing.html.haml`
- Aggregator: `Singing::MusicCommunityHomeBuilder`
- Controller: `Singing::HomesController#top`

`Gentle Return Flow` は、7日以上または30日以上活動が空いたログインユーザーだけに表示する。新規ユーザーや7日未満の活動があるユーザーには表示せず、「おかえりなさい」「少し間が空いても大丈夫」「前の続きから」など、責めない復帰導線として扱う。

## 6. Home カード追加時の基本ルール

Home カードを追加するときは、以下を基本方針にする。

- DB 追加は慎重に判断する
- 既存データを優先して使う
- Service Object 中心で組み立てる
- View へは DTO で渡す
- nil 安全にする
- N+1 を発生させない
- ランキング感を出さない
- 人気者システムにしない
- スコア比較を主役にしない
- 仲間・応援・挑戦・継続を優先する

特に Phase27〜28 で追加した Home 系カードは、既存の診断、応援、成長タイプ、チャレンジ、Community Feed のデータから「音楽コミュニティの動き」を見せる方針で実装している。新しいカードも、まず既存 Builder や既存 DTO から組み立てられないかを確認する。

`Singing::ActivitySignalBuilder` を使う Home card では、Activity Signal の最新順とカードごとの表示優先順位を混同しない。Activity Signal の DTO、`occurred_at desc`、`target_customer_id` の意味、目的別採用の判断は `docs/handover/singing_activity_signal_guidelines.md` を参照する。

新しい Home カードを追加した場合は、必ず以下を更新する。

```text
MusicCommunityHomeBuilder
View
Builder spec
spec/services/singing/music_community_home_builder_spec.rb
docs/handover/singing_home_card_guidelines.md
```

必要に応じて以下も更新する。

```text
docs/handover/singing_index.md
docs/handover/singing_activity_signal_guidelines.md
docs/handover/singing_empty_state_guidelines.md
```

## 7. 表示順の考え方

Home の上部ほど、ユーザー自身の文脈に近いものを置く。

上部で優先するもの:

```text
復帰安心
前回の続き
自分の物語
次の一歩
```

Home の中部では、ユーザーが今日つながれる人や行動を置く。

中部で優先するもの:

```text
つながりのある仲間
仲間の活動
今日の行動
応援
フィード
```

Home の下部ほど、発見や探索、コミュニティ全体の説明を置く。

下部で扱いやすいもの:

```text
発見
世界観
探索
CTA
```

判断に迷った場合は、次の順で考える。

- 「今日戻ってきたユーザー」に必要なものは上へ置く
- 「続きの行動」が明確なカードは Today's Mission より上または近くに置く
- 「仲間との近さ」が強いカードは Community Feed より上に置く
- 「コミュニティ全体の説明」は Growth Circles 以降に置く
- 「初回ユーザー向けの広い導線」は下部 CTA に集約する

## 8. 禁止表現

Home では、以下の表現は禁止または避ける。

```text
人気
ランキング
上位
1位
トップ
フォロワー数
スコア差
勝った
負けた
あなたより上手い
注目ユーザー
```

これらは、Home を「比較される場所」「人気の差が見える場所」に見せやすい。既存のランキング機能が別領域に存在していても、Home のコミュニティカードでは前面に出さない。

## 9. 推奨表現

Home では、以下のような表現を優先する。

```text
つながり
応援
仲間
音楽時間
小さな一歩
続き
今日の挑戦
自分らしく
少しずつ
```

人を紹介する場合は「おすすめユーザー」「人気ユーザー」ではなく、「あなたと近い仲間」「一緒に成長できる仲間」のように、近さ・共通点・伴走感を出す。

## 10. CTA 設計

CTA は 1 カード 1 つを基本にする。

CTA 例:

```text
Community Feedを見る
応援を見る
チャレンジを見る
診断履歴を見る
歌唱診断をする
仲間を見る
```

CTA 先が不明な場合は、新規導線を増やすより既存導線を優先する。

既存導線の優先候補:

- `singing_growth_feed_path`: Community Feed / 仲間の活動
- `singing_challenges_path`: 今日の挑戦 / ミッション
- `singing_diagnoses_path`: 診断履歴 / 成長記録
- `new_singing_diagnosis_path`: 歌唱診断
- `singing_user_path(customer)`: 仲間のプロフィール

カード全体がプロフィール導線として自然に読める場合は、小さな CTA ボタンよりもカード全体をリンクにする。`customer` が nil の場合は表示をスキップし、名前が blank の場合は `メンバー` を fallback にする。

## 11. 空状態

データなし時は、原則としてカード自体を非表示にする。

ただし、初回ユーザーに行動を促す価値がある場合のみ fallback を表示してよい。

例:

```text
Community Recommendation は fallback 表示OK
Music Friends はデータなし非表示
Friend Activity Highlights はデータなし非表示
```

空状態を出す場合は、「何もない」ことではなく、次の一歩を案内する。詳細なコピー判断は `docs/handover/singing_empty_state_guidelines.md` を参照する。

## 12. Spec 方針

Home card Builder は、必ず service spec を作る。

最低テスト:

```text
nil customer
no data
primary data case
mixed data case
limit
dedupe
active? 判定
```

`Singing::MusicCommunityHomeBuilder` に統合した場合は、統合 spec も更新する。

チェック観点:

- nil customer で落ちない
- 関連データがない場合に active? が期待どおりになる
- 表示件数 limit が守られる
- 同じ customer / item が重複表示されない
- View で必要な DTO 属性が揃っている
- `includes` や事前取得で N+1 を避けている
- copy / CTA が競争・人気・上下関係に寄っていない

## 13. 確認コマンド

Home card Builder を追加・変更した場合:

```bash
~/.rbenv/shims/bundle exec rspec spec/services/singing/<builder>_spec.rb spec/services/singing/music_community_home_builder_spec.rb
```

共通確認:

```bash
git diff --check
```

```bash
DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails runner 'puts "boot ok"'
```

CSS / JS / asset 関連変更、または本番反映前:

```bash
RAILS_ENV=production DISABLE_SPRING=1 ~/.rbenv/shims/bundle exec rails assets:precompile
```

ドキュメントだけの変更では RSpec / Rails 起動確認 / assets:precompile は省略してよいが、省略理由を完了報告に明記する。

## Agent 実装前チェック

Home card を追加・調整する前に、以下を確認する。

- `main` ではなく feature / fix ブランチで作業している
- `config/credentials.yml.enc`、`config/master.key`、`.env`、`*.env.*` を読まない・触らない
- `public/assets/` 配下のコンパイル済みアセットをコミット対象にしない
- Stripe / 本番サーバー / systemd / DB rollback に触れる場合は、事前にユーザー確認する
- 既存 Home の表示順に対して、追加カードをどこへ置くか説明できる
- 新しい DB カラムやテーブルが本当に必要か再確認した
- 競争、人気、スコア比較に見える copy が混ざっていない

## 将来の改善メモ

Home card がさらに増える場合は、以下を検討する。

- `Singing::MusicCommunityHomeBuilder` の DTO 一覧をカード役割別に整理する
- Home 表示順を view コメントではなく docs 側で管理し、PR 時に更新する
- 空状態の表示可否を Builder spec の共通 shared example に寄せる
- CTA 先の一覧を routing 変更時に更新する運用にする
