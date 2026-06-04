# Singing Navigation Guidelines

このドキュメントは、Phase31-C で整理した Singing グローバルナビの設計方針を明文化する。

今後メニューが再び増えすぎないよう、追加・変更前に必ず参照すること。

---

## 1. Navigation の基本方針

BeMyStyle Singing は **歌唱診断サイト** ではなく **帰ってきたくなる音楽コミュニティ** である。

そのため、Navigation は「診断する」だけを中心にせず、「今日のホーム」を主導線にする。

```text
ユーザーが感じてほしいこと:
  今日戻ってくる場所がある
  自分の音楽の続きがある
  仲間とのつながりがある
  音楽の節目がある
  今日の一歩がある
```

Navigation はこの体験を邪魔しないシンプルさを保つ。

---

## 2. PC メニュー構成

### メインリンク（`.singing-nav__links`）

原則 **5項目以内** に抑える。

```text
🏠 今日のホーム   ← 最重要。pill ボタン風スタイルで視覚的に最初に目が行く位置に置く
診断する
チャレンジ
ランキング
プロフィール（ログイン時のみ）
```

### 補助リンク（`.singing-nav__right`）

```text
通知アイコン（ログイン時のみ）
BeMyStyleへ（控えめな小テキストリンク）
ユーザー情報 + アバター（ログイン時のみ）
ログアウトボタン（ログイン時のみ）
```

### 実装ファイル

```text
app/views/singing/shared/_header.html.haml
app/assets/stylesheets/singing/diagnoses.scss  ← .singing-nav__* セクション
```

---

## 3. SP メニュー構成

SP はフラットに並べず、**カテゴリ分け**する。

```text
今日
  🏠 今日のホーム
  🎤 診断する
  🏆 チャレンジ

コミュニティ
  🏅 ランキング
  👤 プロフィール（ログイン時のみ）
  🔔 通知（ログイン時のみ）

その他
  📊 成長記録
  🏅 バッジ
  📅 シーズン履歴
  🎬 Recap（現在非表示。再開時はここに追加する）
  💳 料金プラン
  BeMyStyleへ
  ログアウト（ログイン時のみ）
```

実装と差異がある場合は **実装を正とする**。このドキュメントを実装に合わせて更新すること。

---

## 4. メニュー追加時の判断基準

新規メニューを追加する前に以下を確認する。

```text
□ グローバルナビに本当に必要か
    → Home カードや CTA で代替できないか先に確認する

□ PC メインリンクが 6 項目以上にならないか
    → 6 項目以上になる場合は既存項目を SP「その他」へ移すか削除を先に検討する

□ SP で見づらくならないか
    → カテゴリをまたぐ場合は分類を見直す

□ 「その他」カテゴリに寄せられないか
    → 日常的に使わない機能は「その他」で十分

□ 外部導線（BeMyStyleへ など）を主導線にしていないか
    → 外部導線は補助リンク扱いにする
```

---

## 5. 優先順位

メニュー項目が競合した場合の優先度（高い順）。

```text
1. 今日戻る（ホーム）
2. 歌う・診断する
3. 挑戦する
4. 仲間を見る（ランキング）
5. 自分を見る（プロフィール）
6. 補助情報を見る（成長記録・バッジ・シーズン履歴など）
7. 外部・設定系（BeMyStyleへ・料金プラン）
```

---

## 6. NG 方針

```text
メニューを単純追加し続けない
診断導線だけを強くしすぎない
外部導線を主導線にしない
PC と SP の構造を大きくズレさせない
5 項目を超えたまま放置しない
```

---

## 7. スタイル規則

### 今日のホーム（pill スタイル）

```scss
.singing-nav__link--home {
  background: rgba(124, 77, 255, 0.18);
  border: 1px solid rgba(124, 77, 255, 0.35);
  border-radius: 20px;
  color: #c4b5fd;
  font-weight: 700;
  padding: 5px 14px;
}
```

派手すぎないこと。グラデーション CTA とは区別する。

### SP カテゴリ見出し

```scss
.singing-nav__mobile-section-label {
  color: rgba(226, 232, 240, 0.4);
  font-size: 10px;
  font-weight: 700;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}
```

---

## 8. 関連ドキュメント

```text
docs/handover/singing_index.md           ← Singing 全体 index
docs/handover/singing_home_card_guidelines.md
docs/handover/singing_activity_signal_guidelines.md
docs/handover/singing_empty_state_guidelines.md
```

---

## 9. 変更履歴

| Phase | 内容 |
|-------|------|
| Phase31-C | PC 5項目化・SP カテゴリ分け・今日のホーム主導線化 |
