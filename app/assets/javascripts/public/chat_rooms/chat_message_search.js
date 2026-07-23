// チャットルーム内メッセージ検索パネル(Slack風の検索モーダル)の開閉・検索・結果からの
// ジャンプを管理する。
//
// パネル本文(結果一覧)はサーバーからHTML断片をfetchして都度差し替える方式とし、本文の
// プレーンテキスト抜粋・エスケープ・Markdown除去は全てサーバー側(ChatMessagesHelper)に
// 委ねる。クライアント側でMarkdownや本文を再構築しない。
//
// メッセージへのジャンプはchat_thread_panel.js/chat_message_scroll_highlight.jsと同じ
// 見た目(.chat-message-highlight, 3秒)・同じ仕組み(通常メッセージ: #chat-message-<id>への
// scrollIntoView、スレッド返信: window.ChatThreadPanel.open)を再利用し、新しいジャンプ基盤は
// 作らない。検索パネルとスレッドパネルが同時に開いた状態にならないよう、ジャンプ前に
// 必ず検索パネルを閉じる。
(function () {
  "use strict";

  if (typeof document === "undefined") return;

  var HIGHLIGHT_CLASS = "chat-message-highlight";
  var HIGHLIGHT_DURATION_MS = 3000;
  var PER_PAGE = 20;

  var state = {
    open: false,
    query: "",
    page: 1,
    returnFocusEl: null
  };

  function closest(el, selector) {
    return el && el.closest ? el.closest(selector) : null;
  }

  function panelEl() {
    return document.getElementById("search-panel");
  }

  function bodyEl() {
    return document.getElementById("search-panel-body");
  }

  function inputEl() {
    return document.getElementById("search-panel-input");
  }

  function paginationEl() {
    return document.querySelector(".search-panel-pagination");
  }

  function pageInfoEl() {
    return document.getElementById("search-panel-page-info");
  }

  function container() {
    return document.querySelector(".chat-rooms-show-container");
  }

  function searchUrl() {
    var c = container();
    return c ? c.dataset.searchUrl : null;
  }

  function resetPanel() {
    var panel = panelEl();
    if (panel) panel.hidden = true;
    document.body.classList.remove("search-panel-open");

    var body = bodyEl();
    if (body) body.innerHTML = '<p class="search-panel-placeholder">キーワードを入力して検索してください</p>';

    var input = inputEl();
    if (input) input.value = "";

    var pagination = paginationEl();
    if (pagination) pagination.hidden = true;

    state.open = false;
    state.query = "";
    state.page = 1;
    state.returnFocusEl = null;
  }

  function focusPanel() {
    var dialog = document.querySelector(".search-panel-dialog");
    if (dialog && typeof dialog.focus === "function") dialog.focus();
  }

  function focusableElements(scope) {
    var nodes = scope.querySelectorAll(
      'a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])'
    );
    return Array.prototype.filter.call(nodes, function (el) {
      return el.offsetParent !== null;
    });
  }

  function openPanel(options) {
    var panel = panelEl();
    if (!panel) return;

    options = options || {};

    state.open = true;
    state.returnFocusEl = options.returnFocusEl || document.querySelector(".chat-search-trigger");

    panel.hidden = false;
    document.body.classList.add("search-panel-open");
    focusPanel();

    var input = inputEl();
    if (input && typeof input.focus === "function") input.focus();
  }

  function closePanel() {
    var panel = panelEl();
    if (!panel) return;

    var returnFocusEl = state.returnFocusEl;
    resetPanel();

    if (returnFocusEl && typeof returnFocusEl.focus === "function") {
      returnFocusEl.focus();
    }
  }

  function updatePagination(data) {
    var pagination = paginationEl();
    var pageInfo = pageInfoEl();
    if (!pagination || !pageInfo) return;

    if (!data.total_count || data.total_count <= PER_PAGE) {
      pagination.hidden = true;
      return;
    }

    pagination.hidden = false;
    var totalPages = Math.max(1, Math.ceil(data.total_count / PER_PAGE));
    pageInfo.textContent = data.page + " / " + totalPages;

    var prevButton = pagination.querySelector(".search-panel-prev");
    var nextButton = pagination.querySelector(".search-panel-next");
    if (prevButton) prevButton.disabled = !data.prev_page;
    if (nextButton) nextButton.disabled = !data.next_page;
  }

  function runSearch(query, page) {
    var url = searchUrl();
    var body = bodyEl();
    if (!url || !body) return;

    state.query = query;
    state.page = page;

    body.innerHTML = '<p class="search-panel-placeholder">検索中…</p>';
    var pagination = paginationEl();
    if (pagination) pagination.hidden = true;

    var params = new URLSearchParams();
    params.set("q", query);
    params.set("page", page);

    fetch(url + "?" + params.toString(), {
      headers: { "X-Requested-With": "XMLHttpRequest" },
      credentials: "same-origin"
    })
      .then(function (response) {
        if (!response.ok) throw new Error("search_fetch_failed");
        return response.json();
      })
      .then(function (data) {
        body.innerHTML = data.html;
        updatePagination(data);
      })
      .catch(function () {
        body.innerHTML = '<p class="search-panel-message search-panel-message--error">検索できませんでした</p>';
      });
  }

  // 通常メッセージへのジャンプ。既存のchat_message_scroll_highlight.jsと同じ見た目・仕組み
  // (#chat-message-<id>のscrollIntoView + 一時ハイライト)を再利用する。
  function jumpToNormalMessage(messageId) {
    var target = document.getElementById("chat-message-" + messageId);
    if (!target) return;

    target.scrollIntoView({ block: "center" });
    target.classList.add(HIGHLIGHT_CLASS);
    setTimeout(function () {
      target.classList.remove(HIGHLIGHT_CLASS);
    }, HIGHLIGHT_DURATION_MS);
  }

  // スレッド返信へのジャンプ。既存のchat_thread_panel.jsが公開するopen APIをそのまま使う
  // (新しいスレッド表示ロジックを作らない)。
  function jumpToThreadReply(rootId, messageId) {
    if (!window.ChatThreadPanel || !window.ChatThreadPanel.open) return;
    window.ChatThreadPanel.open(rootId, { highlightId: messageId });
  }

  function handleResultSelect(card) {
    var messageId = card.getAttribute("data-search-message-id");
    var rootId = card.getAttribute("data-search-root-id");
    var isReply = card.getAttribute("data-search-is-reply") === "true";
    if (!messageId) return;

    // スレッドパネルと同時に開いた状態にならないよう、ジャンプ前に必ず検索パネルを閉じる。
    closePanel();

    if (isReply) {
      jumpToThreadReply(rootId, messageId);
    } else {
      jumpToNormalMessage(messageId);
    }
  }

  document.addEventListener("click", function (event) {
    var trigger = closest(event.target, ".chat-search-trigger");
    if (trigger) {
      openPanel({ returnFocusEl: trigger });
      return;
    }

    var resultCard = closest(event.target, ".search-result-card");
    if (resultCard) {
      handleResultSelect(resultCard);
      return;
    }

    if (!state.open) return;

    if (closest(event.target, ".search-panel-close") || closest(event.target, ".search-panel-backdrop")) {
      closePanel();
      return;
    }

    var prevButton = closest(event.target, ".search-panel-prev");
    if (prevButton && !prevButton.disabled && state.page > 1) {
      runSearch(state.query, state.page - 1);
      return;
    }

    var nextButton = closest(event.target, ".search-panel-next");
    if (nextButton && !nextButton.disabled) {
      runSearch(state.query, state.page + 1);
    }
  });

  document.addEventListener("submit", function (event) {
    var form = closest(event.target, "#search-panel-form");
    if (!form) return;

    event.preventDefault();
    var input = inputEl();
    var query = input ? input.value : "";
    runSearch(query, 1);
  });

  document.addEventListener("keydown", function (event) {
    if (!state.open) return;

    if (event.key === "Escape") {
      event.preventDefault();
      closePanel();
      return;
    }

    if (event.key === "Tab") {
      var dialog = document.querySelector(".search-panel-dialog");
      if (!dialog) return;

      var focusables = focusableElements(dialog);
      if (focusables.length === 0) return;

      var first = focusables[0];
      var last = focusables[focusables.length - 1];

      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    }
  });

  document.addEventListener("turbolinks:before-cache", resetPanel);
})();
