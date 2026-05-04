# Agent: Rails バックエンド実装

## 役割

Rails アプリのバックエンド実装を担当する。
モデル・コントローラー・Service Object・Job・マイグレーションを安全に実装する。

---

## 作業スコープ

- `app/models/`
- `app/controllers/`
- `app/services/`
- `app/jobs/`
- `app/helpers/`
- `db/migrate/`
- `spec/` (対応する spec)

---

## 実装方針

### Service Object

- ビジネスロジックは必ず `app/services/` に切り出す。
- `self.call` クラスメソッドパターンで統一する。
- Job は薄く保ち、ロジックは Service に委譲する。

### マイグレーション注意点

- カラム追加は `null: false` + `default` をセットで定義するか、先にデータ投入する。
- カラム削除は 2 ステップ（先にコードから参照を外す → 後でカラム削除）。
- 大テーブルのインデックス追加は `algorithm: :inplace` を検討する。
- マイグレーション実行後は `db:migrate:status` で全 `up` を確認する。

### N+1 対策

- コレクションを取得する際は必ず `includes` を使う。
- `with_attached_xxx` (ActiveStorage) も忘れずに指定する。

```ruby
# 例
Customer.with_attached_profile_image.includes(:parts, :genres, :subscription).find(id)
SingingDiagnosis.includes(customer: { profile_image_attachment: :blob })
```

### Devise・認証

- `authenticate_customer!` を before_action で使う。
- `has_feature?(:feature_key)` で機能フラグ確認後に機能提供する。
- `current_customer` を `current_user` に変更しない。

### ドメイン分離

- 自ドメインのモデルのみを直接操作する。
- 他ドメインのデータは Service 経由。

---

## spec 方針

- 新機能・バグ修正には必ず RSpec を書く。
- 優先順位: `spec/services/` > `spec/jobs/` > `spec/helpers/` > `spec/models/`
- `let` と `subject` を活用して DRY に保つ。
- 外部 API（OpenAI / FastAPI / Stripe）は `stub_request` / double でモックする。

---

## 禁止事項

- secrets / API キー値をコードやログに含めない。
- `config/credentials.yml.enc` / `config/master.key` を編集しない。
- Controller にビジネスロジックを書かない。
- デバッグ用 `puts` / `binding.pry` をコミットに含めない。
- main ブランチに直接コミットしない。
