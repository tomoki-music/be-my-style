# Rails 実装ルール

## テンプレート (HAML)

- このリポジトリは **HAML** を使用する。ERB は使わない。
- HAML の属性はハッシュ記法: `%div{ class: "foo", data: { id: 1 } }`
- 長い属性は複数行に分割する。

```haml
-# 正しい例
= link_to singing_diagnosis_path(@diagnosis), class: "btn btn-primary" do
  診断結果を見る

-# NG: ERB 記法
<%= link_to ... %>
```

---

## スタイル (SCSS)

- BEM 命名規則を基本とする。
- コンポーネント単位で `app/assets/stylesheets/` 配下にファイルを分ける。
- 既存のクラス名を変更する場合は、View 側の HAML も必ず追従して変更する。
- `!important` は原則禁止。

---

## Service Object 方針

- ビジネスロジックは Controller に書かず、`app/services/` 配下の Service Object に切り出す。
- Service Object は `call` クラスメソッドを持つ形式を推奨:

```ruby
# 例: app/services/singing_diagnoses/ai_comment_generator.rb
module SingingDiagnoses
  class AiCommentGenerator
    def self.call(diagnosis)
      new(diagnosis).generate
    end
    # ...
  end
end
```

- Job (`app/jobs/`) は薄く保つ。ロジックは Service に委譲する。
- Service は単一責任を守る。1 サービス = 1 つの明確な役割。

---

## Devise 方針

- 認証は **Devise** で管理。独自認証ロジックを追加しない。
- `current_customer` を `current_user` に変更しない（モデル名が `Customer`）。
- ドメインごとに Devise コントローラーを継承して個別カスタマイズ:

```
app/controllers/singing/sessions_controller.rb
app/controllers/singing/registrations_controller.rb
```

- `authenticate_customer!` を before_action で使う。
- `has_feature?(:feature_key)` で機能フラグを確認してから機能を提供する。

---

## ドメイン分離方針

| ドメイン | 名前空間 | 概要 |
|----------|----------|------|
| music | `Music::` | コミュニティ・セッション・バンド |
| singing | `Singing::` | 歌声診断・ランキング・AIコメント |
| business | `Business::` | 法人・プレミアム |
| learning | `Learning::` | 学習コンテンツ |
| admin | `Admin::` | 管理者機能 |

- ドメインをまたぐロジックは `app/services/` に切り出す。
- Controller は自ドメインのモデルのみを直接操作する。
- 他ドメインのデータが必要な場合は Service 経由にする。

---

## N+1 対策

- Controller でコレクションを取得する際は **必ず `includes` を使う**。
- 関連モデルのメソッドを View で呼ぶ前に includes しているか確認する。

```ruby
# NG: N+1 が発生する
@diagnoses = SingingDiagnosis.all

# OK
@diagnoses = SingingDiagnosis.includes(:customer).all

# ActiveStorage のアタッチメントも同様
@user = Customer.with_attached_profile_image.includes(:parts, :genres, :subscription).find(id)
```

- Bullet gem (`Gemfile` の `:development` グループ) を活用して N+1 を検出する。
- `joins` と `includes` の違いを意識する（`includes` はメモリ展開、`joins` は SQL JOIN）。

---

## その他 Rails ルール

- `before_action` での早期 `return` は明示的に書く（`return if` 形式）。
- `find_by` は `nil` を返す。`find` は `ActiveRecord::RecordNotFound` を raise する。用途に合わせて使い分ける。
- `rescue_from` は `ApplicationController` で定義し、個別コントローラーに書かない。
- デバッグ用の `puts` / `p` / `binding.pry` / `byebug` はコミット前に必ず削除する。
- `Rails.logger.info/debug` は本番ログを汚さないよう適切なレベルで使う。
