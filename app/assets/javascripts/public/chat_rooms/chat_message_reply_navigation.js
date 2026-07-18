// 返信元カード(.reply-source-card)のクリック/キーボード操作から、元メッセージへ
// スクロールし一時ハイライトする。
//
// chat_message_scroll_highlight.js(通知経由のURLハッシュからの初回ジャンプ)とは
// 起点イベントが異なる(クリック vs URLハッシュ)ため独立したファイルにしている。
// ハイライトの見た目を統一するため、CSSクラス(.chat-message-highlight)とタイミング(3秒)は
// chat_message_scroll_highlight.jsと揃える。
//
// chat_reply_composer.js同様、動的にDOMを生成せずdocumentへイベント委譲するだけなので、
// 初回スクリプト読み込み時に一度だけ登録すればよく、Turbolinksのクリーンアップは不要。
// 対象メッセージがDOM上に存在しない場合(削除済み・別ページ由来等)は何もしない。

(function () {
  "use strict";

  if (typeof document === "undefined") return;

  var HIGHLIGHT_CLASS = "chat-message-highlight";
  var HIGHLIGHT_DURATION_MS = 3000;

  function findReplySourceCard(el) {
    return el && el.closest ? el.closest(".reply-source-card[data-reply-target-id]") : null;
  }

  function jumpToReplyTarget(card) {
    var targetId = card.getAttribute("data-reply-target-id");
    if (!targetId) return;

    var target = document.getElementById(targetId);
    if (!target) return;

    target.scrollIntoView({ block: "center" });
    target.classList.add(HIGHLIGHT_CLASS);
    setTimeout(function () {
      target.classList.remove(HIGHLIGHT_CLASS);
    }, HIGHLIGHT_DURATION_MS);
  }

  document.addEventListener("click", function (event) {
    var card = findReplySourceCard(event.target);
    if (card) jumpToReplyTarget(card);
  });

  document.addEventListener("keydown", function (event) {
    if (event.key !== "Enter" && event.key !== " ") return;

    var card = findReplySourceCard(event.target);
    if (!card) return;

    // スペースキーでのページスクロールなど、role="button"要素のデフォルト動作を抑止する。
    event.preventDefault();
    jumpToReplyTarget(card);
  });
})();
