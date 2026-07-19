// 返信元カード(.reply-source-card)・引用カード(.quote-card)のクリック/キーボード操作から、
// 元メッセージへスクロールし一時ハイライトする。
//
// chat_message_scroll_highlight.js(通知経由のURLハッシュからの初回ジャンプ)とは
// 起点イベントが異なる(クリック vs URLハッシュ)ため独立したファイルにしている。
// ハイライトの見た目を統一するため、CSSクラス(.chat-message-highlight)とタイミング(3秒)は
// chat_message_scroll_highlight.jsと揃える。
//
// chat_reply_composer.js同様、動的にDOMを生成せずdocumentへイベント委譲するだけなので、
// 初回スクリプト読み込み時に一度だけ登録すればよく、Turbolinksのクリーンアップは不要。
// 対象メッセージがDOM上に存在しない場合(削除済み・別ページ由来等)は何もしない。
//
// 引用カードが指す先がスレッド内メッセージで、かつ現在スレッドパネルが開いていない
// (=DOM上に対象が存在しない)場合は、chat_thread_panel.jsが公開するopen APIで
// スレッドパネルを開き、その中で対象をハイライトする(スレッドの自動展開基盤を新たに
// 作り込まず、既存のパネル取得・ハイライト経路を再利用するだけに留める)。

(function () {
  "use strict";

  if (typeof document === "undefined") return;

  var HIGHLIGHT_CLASS = "chat-message-highlight";
  var HIGHLIGHT_DURATION_MS = 3000;

  function findNavigationCard(el) {
    return el && el.closest
      ? el.closest(".reply-source-card[data-reply-target-id], .quote-card[data-quote-target-id]")
      : null;
  }

  function targetIdOf(card) {
    return card.getAttribute("data-reply-target-id") || card.getAttribute("data-quote-target-id");
  }

  function highlight(target) {
    target.scrollIntoView({ block: "center" });
    target.classList.add(HIGHLIGHT_CLASS);
    setTimeout(function () {
      target.classList.remove(HIGHLIGHT_CLASS);
    }, HIGHLIGHT_DURATION_MS);
  }

  function openInThreadPanel(domId) {
    if (!window.ChatThreadPanel || !window.ChatThreadPanel.open) return;

    var match = domId.match(/^chat-message-(\d+)$/);
    if (!match) return;

    window.ChatThreadPanel.open(match[1], { highlightId: match[1] });
  }

  function jumpToTarget(card) {
    var targetId = targetIdOf(card);
    if (!targetId) return;

    var target = document.getElementById(targetId);
    if (target) {
      highlight(target);
      return;
    }

    // 引用元がスレッド内メッセージで、現在そのスレッドパネルが開いていない場合の
    // フォールバック。返信元カードは同一chat_room内かつスレッド階層化しない設計のため
    // 通常は直接DOM上に見つかるが、引用カードはスレッド内メッセージも指しうる。
    if (card.classList.contains("quote-card")) {
      openInThreadPanel(targetId);
    }
  }

  document.addEventListener("click", function (event) {
    var card = findNavigationCard(event.target);
    if (card) jumpToTarget(card);
  });

  document.addEventListener("keydown", function (event) {
    if (event.key !== "Enter" && event.key !== " ") return;

    var card = findNavigationCard(event.target);
    if (!card) return;

    // スペースキーでのページスクロールなど、role="button"要素のデフォルト動作を抑止する。
    event.preventDefault();
    jumpToTarget(card);
  });
})();
