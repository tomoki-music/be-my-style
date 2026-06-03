# Singing Activity Signal Guidelines

このガイドは、`Singing::ActivitySignalBuilder` を Home card Builder から使うときの判断基準として使う。

Singing 関連 docs の入口は `docs/handover/singing_index.md` を参照する。Activity Signal だけでなく、Home card の表示順や空状態も関係する場合は、index から該当 docs を確認する。

Activity Signal は「ユーザーの活動を共通形式で読む」ための read-only な材料であり、Home card の表示優先順位そのものではない。

## 1. ActivitySignalBuilder の役割

`Singing::ActivitySignalBuilder` は、ユーザーの活動を共通の Signal DTO として返す read-only Builder。

基本方針:

- DB 追加なし
- DB 書き込みなし
- 既存データのみを読む
- Home card Builder が目的別に採用できる活動材料を返す
- ランキング、人気、スコア比較には使わない

## 2. Signal DTO

`Singing::ActivitySignalBuilder` は、以下の DTO を返す。

```ruby
Signal
  source
  occurred_at
  target_customer_id
  metadata
```

`source` は以下を扱う。

```ruby
:diagnosis
:reaction_sent
:reaction_received
:challenge_progress
```

`metadata` は source ごとの補足情報を入れる。たとえば `:reaction_sent` / `:reaction_received` では `reaction_type`、`:challenge_progress` では `target_key` や `completed` を持つ。

## 3. 並び順

`ActivitySignalBuilder` は必ず `occurred_at desc` で返す。

つまり、Builder の結果では次が成り立つ。

```ruby
latest_signal == signals.first
```

この並び順は「活動一覧としての最新順」を表す。

## 4. target_customer_id の意味

`target_customer_id` は、reaction 系 source で相手ユーザーを指す。

```text
reaction_sent:
  応援した相手

reaction_received:
  応援してくれた相手
```

この意味を source ごとに曖昧にしない。特に `reaction_received` では、`target_customer_id` は「応援された自分」ではなく「応援してくれた相手」を表す。

## 5. 最新順と表示優先順位の違い

`ActivitySignalBuilder` の責務は、以下だけである。

```text
活動一覧を最新順で返す
```

一方で、各 Home card Builder の責務は以下である。

```text
自分の目的に応じて signal を採用する
```

そのため、`signals.first` をそのまま全カードの表示優先順位として扱わない。

判断を分ける観点:

```text
最新順:
  ActivitySignalBuilder が occurred_at desc で返す順

優先順位順:
  カードの見せたい体験に合わせて Builder が選ぶ順

目的別採用:
  最新活動、前回の記憶、次の一歩、不在期間判定など、用途に応じて signal を選ぶこと
```

## 6. Home card Builder での使い方

### CommunityMemoryBuilder

`CommunityMemoryBuilder` は「前回の記憶」を出すために Activity Signal を使う。

ただし、記憶カードとして見せたい優先順位があるため、ActivitySignalBuilder の最新順をそのまま採用しない。現在は、診断、応援送信、応援受信、未完了チャレンジなど、記憶として見せたい source の順で採用する。

### CommunityRecommendationBuilder

`CommunityRecommendationBuilder` は「次の一歩」を提案するために Activity Signal を使う。

推薦として有効な最新活動を材料にするが、完了済み challenge のように推薦上そのまま使わないほうがよい signal は fallback に回す判断がある。

### GentleReturnFlowBuilder

`GentleReturnFlowBuilder` は、不在期間判定に Activity Signal を使う。

この Builder では、ユーザーの最新活動日時だけが重要である。`latest_signal` を使って「どれくらい間が空いたか」を判断する。

### ReturnMotivationBuilder

`ReturnMotivationBuilder` は、復帰動機コピーや CTA 分岐に Activity Signal を使う。

最新活動の source をもとに、「診断の続き」「届いた応援」「チャレンジの続き」など、責めない復帰導線へ分岐する。

## 7. やってはいけないこと

Activity Signal を使うときは、以下を避ける。

```text
ActivitySignalBuilder の最新順を、そのまま全Builderの表示優先順位にする
target_customer_id の意味を source ごとに曖昧にする
ランキング・人気・スコア比較に転用する
DB書き込みを入れる
```

Home は「活動量の多さ」や「人気の高さ」を競う場所ではない。Activity Signal は、仲間、応援、挑戦、継続の文脈をやさしく拾うための材料として扱う。

## 8. Spec 方針

`ActivitySignalBuilder` を変更した場合は、以下を必ず確認する。

```bash
~/.rbenv/shims/bundle exec rspec \
  spec/services/singing/activity_signal_builder_spec.rb \
  spec/services/singing/community_memory_builder_spec.rb \
  spec/services/singing/community_recommendation_builder_spec.rb \
  spec/services/singing/gentle_return_flow_builder_spec.rb \
  spec/services/singing/return_motivation_builder_spec.rb
```

docs-only の変更では RSpec を省略してよい。省略した場合は、完了報告に理由を明記する。
