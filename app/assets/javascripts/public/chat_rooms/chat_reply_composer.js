// 返信ボタン押下・返信プレビュー表示・キャンセル・hidden field更新・textareaフォーカスを担当。
//
// chat_mention_autocomplete.jsと違い、この機能は動的にDOM(ドロップダウン等)を生成せず、
// 常に既存の.reply-preview/.reply-to-hidden-field/.markdown-textareaを参照するだけなので、
// documentへのイベント委譲を初回スクリプト読み込み時に一度だけ登録すれば良い
// (Turbolinksのページ遷移はdocument.body配下の要素だけを差し替え、documentオブジェクト自体は
// 維持されるため、documentに登録したリスナーはページ遷移後も有効。per-nodeのリスナー登録や
// body直下へのDOM生成をしていないため、chat_mention_autocomplete.jsのような
// turbolinks:before-cacheでのリスナー破棄は不要)。
//
// ただしTurbolinksのbfcache復元(ブラウザバック)では「前ページで開いたままの返信プレビュー」
// がDOMごとキャッシュされてしまうため、turbolinks:before-cacheで返信プレビューの表示状態と
// hidden fieldだけを初期化する(textarea本文・添付ファイル選択・メンション状態には一切触れない)。

(function () {
  "use strict";

  if (typeof document === "undefined") return;

  function closest(el, selector) {
    return el && el.closest ? el.closest(selector) : null;
  }

  function resetReplyPreview(container) {
    var preview = container.querySelector(".reply-preview");
    var hiddenField = container.querySelector(".reply-to-hidden-field");
    if (preview) preview.hidden = true;
    if (hiddenField) hiddenField.value = "";
  }

  function showReplyPreview(container, button) {
    var preview = container.querySelector(".reply-preview");
    var hiddenField = container.querySelector(".reply-to-hidden-field");
    if (!preview || !hiddenField) return;

    var authorEl = container.querySelector(".reply-preview-author");
    var snippetEl = container.querySelector(".reply-preview-snippet");
    var textarea = container.querySelector(".markdown-textarea");

    // 本文・添付・メンション状態には触れない。書き換えるのは返信プレビュー表示とhidden fieldのみ。
    hiddenField.value = button.getAttribute("data-reply-message-id") || "";
    if (authorEl) authorEl.textContent = button.getAttribute("data-reply-author") || "";
    if (snippetEl) snippetEl.textContent = button.getAttribute("data-reply-preview") || "";
    preview.hidden = false;

    if (typeof preview.scrollIntoView === "function") {
      preview.scrollIntoView({ block: "nearest" });
    }
    if (textarea && typeof textarea.focus === "function") {
      textarea.focus();
    }
  }

  document.addEventListener("click", function (event) {
    var replyButton = closest(event.target, ".reply-button");
    if (replyButton) {
      var container = closest(replyButton, ".chat-rooms-show-container");
      if (container) showReplyPreview(container, replyButton);
      return;
    }

    var cancelButton = closest(event.target, ".reply-preview-cancel");
    if (cancelButton) {
      var cancelContainer = closest(cancelButton, ".chat-rooms-show-container");
      if (cancelContainer) resetReplyPreview(cancelContainer);
    }
  });

  document.addEventListener("turbolinks:before-cache", function () {
    document.querySelectorAll(".chat-rooms-show-container").forEach(function (container) {
      resetReplyPreview(container);
    });
  });
})();
