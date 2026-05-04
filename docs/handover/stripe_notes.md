# Stripe 注意事項

## 基本方針

- Stripe 関連コードの変更は**必ずユーザー（運営者）に確認してから行う。**
- 本番の Stripe 設定変更はユーザー・お金に直接影響するため、慎重に扱う。
- テスト用キーと本番キーを**絶対に混在させない。**

## キー管理

| キー種別 | 保存場所 | 注意 |
|----------|----------|------|
| Stripe シークレットキー (本番) | systemd Environment / credentials | 値をログに出力しない |
| Stripe シークレットキー (テスト) | 開発環境 .env / credentials | 本番環境に設定しない |
| Stripe Webhook シークレット | systemd Environment / credentials | 変更時は Stripe ダッシュボードと同期 |

**キーの値はいかなるファイル・ログにも記載しない。**

## コード変更時の注意点

### Plan / Price ID

- Stripe の Price ID（`price_xxx`）は環境ごとに異なる。
- テスト環境と本番環境で ID が違うため、ハードコードは禁止。
- `Rails.application.credentials` または ENV から取得する。

### Webhook

- Webhook エンドポイントを変更する場合は Stripe ダッシュボードも更新する。
- Webhook シークレットが変わった場合は systemd の環境変数も更新 + Puma 再起動が必要。

### サブスクリプション変更

- プランの追加・変更・廃止は Stripe ダッシュボードと Rails の両方で整合性を保つ。
- 既存サブスクリプション利用者への影響を事前に確認する。

## 確認コマンド（開発環境）

```bash
# Stripe gem が正常に読み込まれているか
DISABLE_SPRING=1 bundle exec rails runner 'puts Stripe::VERSION'

# テストモードの API キーが設定されているか
DISABLE_SPRING=1 bundle exec rails runner \
  'puts Stripe.api_key.to_s.start_with?("sk_test_") ? "test key OK" : "WARN: not test key"'
```

## デプロイ時の Stripe 確認観点

- [ ] 本番環境に **テスト用キー** が設定されていないことを確認
- [ ] Webhook エンドポイント URL が本番 URL になっていることを確認
- [ ] 新しい Price / Plan ID が本番 Stripe ダッシュボードに存在することを確認
- [ ] サブスクリプション作成・解約フローの動作確認（Stripe テストモードで事前検証）
