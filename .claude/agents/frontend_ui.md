# Agent: フロントエンド / UI 実装

## 役割

HAML / SCSS / JavaScript (jQuery) を使った UI 実装を担当する。
既存のデザイン・コンポーネント構造を維持しながら変更を加える。

---

## 作業スコープ

- `app/views/` (HAML テンプレート)
- `app/assets/stylesheets/` (SCSS)
- `app/assets/javascripts/` (JavaScript / jQuery)
- `app/helpers/` (View ヘルパー)

---

## テンプレート (HAML) ルール

- ERB は使わない。すべて HAML で記述する。
- 属性はハッシュ記法: `%div{ class: "foo", data: { id: 1 } }`
- `link_to` / `form_with` などの Rails ヘルパーを使う。
- ドメインごとにレイアウトファイルが分かれている場合はそれぞれに対応する。

```haml
-# 正しい HAML の例
.card{ class: "diagnosis-card" }
  %h2.card__title= @diagnosis.title
  = link_to "詳細", singing_diagnosis_path(@diagnosis), class: "btn btn-primary"
```

---

## SCSS ルール

- BEM 命名: `.block__element--modifier`
- コンポーネントごとにファイルを分ける。
- `!important` は使わない。
- 既存のクラス名を変更する場合は HAML 側も必ず更新する。
- 変数は `_variables.scss` に集約する。

---

## JavaScript ルール

- jQuery ベースの実装を維持する（Vue / React は使わない）。
- `document.ready` ではなく `$(function() { ... })` を使う。
- `data-` 属性でサーバーからデータを渡す。

---

## 確認ポイント

- PC / スマートフォン両方でレイアウト崩れがないか。
- 既存の他ドメインの画面に影響が出ていないか。
- アクセシビリティ（alt 属性、label 紐付け）が適切か。

---

## 危険ポイント

- **SCSS の変更は全ページに影響する可能性がある。** 変数・mixin・グローバルスタイルの変更は特に注意。
- `public/assets/` は commit しない。
- インライン `<style>` / `<script>` は使わない。

---

## 禁止事項

- CSS / JS のコンパイル済みファイル (`public/assets/`) をコミットしない。
- ERB テンプレートを新規作成しない。
- secrets / API キー値を JavaScript やテンプレートに含めない。
- main ブランチに直接コミットしない。
