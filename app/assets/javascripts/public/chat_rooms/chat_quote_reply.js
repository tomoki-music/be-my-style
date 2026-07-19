// 引用返信ボタン押下・引用プレビュー表示・キャンセル・hidden field更新を担当する。
//
// chat_reply_composer.js(スレッド親子関係の「返信」)とは別の概念であり、通常Composer・
// スレッドComposerの両方に、それぞれ独立した引用状態(.quote-preview/.quote-to-hidden-field)
// を持たせる。引用ボタンは通常一覧・スレッドパネルの両方のメッセージに表示されるため、
// クリックされた引用ボタンがスレッドパネル内か通常一覧内かによって、更新対象のプレビュー/
// hidden fieldを出し分ける(chat_reply_composer.jsは常に通常Composerのみが対象のため、
// この出し分けは不要だった)。
//
// このファイルもchat_reply_composer.js同様、動的にDOM(ドロップダウン等)を生成せず
// documentへイベント委譲するだけなので、初回スクリプト読み込み時に一度だけ登録すればよい。
// スレッドパネルを閉じる・再取得する際は、chat_thread_panel.jsがパネル本文のinnerHTMLごと
// 差し替える(resetPanel/renderThreadBody)ため、スレッド側の引用状態は自動的にリセットされる。
// bfcache復元(ブラウザバック)時は、通常Composer側の引用プレビューだけを明示的に初期化する。

(function () {
  "use strict";

  if (typeof document === "undefined") return;

  function closest(el, selector) {
    return el && el.closest ? el.closest(selector) : null;
  }

  // クリックされた引用ボタンがスレッドパネル内であればパネル本文を、そうでなければ
  // 通常Composerを含むチャット画面全体をスコープとして返す。通常Composerの
  // .quote-previewは.chat-rooms-show-container内でスレッドパネルより先にマークアップ
  // されているため、パネルを介さないスコープではquerySelectorが常に通常Composer側の
  // 要素を返す。
  function quoteScopeElement(el) {
    return closest(el, ".thread-panel-body") || closest(el, ".chat-rooms-show-container");
  }

  function resetQuotePreview(scope) {
    var preview = scope.querySelector(".quote-preview");
    var hiddenField = scope.querySelector(".quote-to-hidden-field");
    var imageNote = scope.querySelector(".quote-preview-image-note");
    if (preview) preview.hidden = true;
    if (hiddenField) hiddenField.value = "";
    if (imageNote) imageNote.hidden = true;
  }

  function showQuotePreview(scope, button) {
    var preview = scope.querySelector(".quote-preview");
    var hiddenField = scope.querySelector(".quote-to-hidden-field");
    if (!preview || !hiddenField) return;

    var labelEl = scope.querySelector(".quote-preview-label");
    var snippetEl = scope.querySelector(".quote-preview-snippet");
    var imageNoteEl = scope.querySelector(".quote-preview-image-note");
    var textarea = scope.querySelector(".markdown-textarea");

    hiddenField.value = button.getAttribute("data-quote-message-id") || "";
    if (labelEl) labelEl.textContent = button.getAttribute("data-quote-label") || "";
    if (snippetEl) snippetEl.textContent = button.getAttribute("data-quote-excerpt") || "";

    var hasImage = button.getAttribute("data-quote-has-image") === "true";
    var hasExcerpt = (button.getAttribute("data-quote-excerpt") || "").length > 0;
    if (imageNoteEl) imageNoteEl.hidden = !(hasImage && hasExcerpt);

    preview.hidden = false;

    if (typeof preview.scrollIntoView === "function") {
      preview.scrollIntoView({ block: "nearest" });
    }
    if (textarea && typeof textarea.focus === "function") {
      textarea.focus();
    }
  }

  document.addEventListener("click", function (event) {
    var quoteButton = closest(event.target, ".quote-button");
    if (quoteButton) {
      var scope = quoteScopeElement(quoteButton);
      if (scope) showQuotePreview(scope, quoteButton);
      return;
    }

    var cancelButton = closest(event.target, ".quote-preview-cancel");
    if (cancelButton) {
      var cancelScope = quoteScopeElement(cancelButton);
      if (cancelScope) resetQuotePreview(cancelScope);
    }
  });

  document.addEventListener("turbolinks:before-cache", function () {
    document.querySelectorAll(".chat-rooms-show-container").forEach(function (container) {
      resetQuotePreview(container);
    });
  });

  window.ChatQuoteReply = window.ChatQuoteReply || {};
  window.ChatQuoteReply.reset = resetQuotePreview;
})();
