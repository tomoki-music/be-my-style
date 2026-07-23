// ピン留め一覧パネル(検索パネルと同じSlack風モーダル構造)の開閉・取得と、
// 各メッセージのピン留め/解除ボタンを管理する。
//
// パネル本文(ピン留め一覧)はサーバーからHTML断片をfetchして都度差し替える方式とし、
// 検索パネルと異なりキーワード入力・ページネーションは無い(上限を設けていないため
// 1ルームのピン件数は運用上小さい想定で、全件を一度に取得して表示する)。
//
// ピン留め一覧からのジャンプはchat_message_search.js/chat_thread_panel.js/
// chat_message_scroll_highlight.jsと同じ見た目(.chat-message-highlight, 3秒)・
// 同じ仕組み(通常メッセージ: #chat-message-<id>へのscrollIntoView、
// スレッド返信: window.ChatThreadPanel.open)を再利用し、新しいジャンプ基盤は作らない。
// ピン留めパネルとスレッドパネルが同時に開いた状態にならないよう、ジャンプ前に
// 必ずピン留めパネルを閉じる(検索パネルと同じ設計)。
(function () {
  "use strict";

  if (typeof document === "undefined") return;

  var HIGHLIGHT_CLASS = "chat-message-highlight";
  var HIGHLIGHT_DURATION_MS = 3000;

  var state = {
    open: false,
    returnFocusEl: null
  };

  function closest(el, selector) {
    return el && el.closest ? el.closest(selector) : null;
  }

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : "";
  }

  function panelEl() {
    return document.getElementById("pin-panel");
  }

  function bodyEl() {
    return document.getElementById("pin-panel-body");
  }

  function container() {
    return document.querySelector(".chat-rooms-show-container");
  }

  function pinsUrl() {
    var c = container();
    return c ? c.dataset.pinsUrl : null;
  }

  function pinUrl(messageId) {
    var c = container();
    var template = c ? c.dataset.pinUrlTemplate : null;
    if (!template) return null;
    return template.replace("__ID__", encodeURIComponent(messageId));
  }

  function resetPanel() {
    var panel = panelEl();
    if (panel) panel.hidden = true;
    document.body.classList.remove("pin-panel-open");

    var body = bodyEl();
    if (body) body.innerHTML = '<p class="pin-panel-placeholder">ピン留めされたメッセージはまだありません</p>';

    state.open = false;
    state.returnFocusEl = null;
  }

  function focusPanel() {
    var dialog = document.querySelector(".pin-panel-dialog");
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

  function loadPins() {
    var url = pinsUrl();
    var body = bodyEl();
    if (!url || !body) return;

    body.innerHTML = '<p class="pin-panel-placeholder">読み込み中…</p>';

    fetch(url, {
      headers: { "X-Requested-With": "XMLHttpRequest" },
      credentials: "same-origin"
    })
      .then(function (response) {
        if (!response.ok) throw new Error("pins_fetch_failed");
        return response.json();
      })
      .then(function (data) {
        body.innerHTML = data.html;
      })
      .catch(function () {
        body.innerHTML = '<p class="pin-panel-message pin-panel-message--error">ピン留め一覧を取得できませんでした</p>';
      });
  }

  function openPanel(options) {
    var panel = panelEl();
    if (!panel) return;

    options = options || {};

    state.open = true;
    state.returnFocusEl = options.returnFocusEl || document.querySelector(".chat-pin-trigger");

    panel.hidden = false;
    document.body.classList.add("pin-panel-open");
    focusPanel();
    loadPins();
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

  // 通常メッセージへのジャンプ。既存のchat_message_scroll_highlight.js/
  // chat_message_search.jsと同じ見た目・仕組みを再利用する。
  function jumpToNormalMessage(messageId) {
    var target = document.getElementById("chat-message-" + messageId);
    if (!target) return;

    target.scrollIntoView({ block: "center" });
    target.classList.add(HIGHLIGHT_CLASS);
    setTimeout(function () {
      target.classList.remove(HIGHLIGHT_CLASS);
    }, HIGHLIGHT_DURATION_MS);
  }

  // スレッド返信へのジャンプ。既存のchat_thread_panel.jsが公開するopen APIをそのまま使う。
  function jumpToThreadReply(rootId, messageId) {
    if (!window.ChatThreadPanel || !window.ChatThreadPanel.open) return;
    window.ChatThreadPanel.open(rootId, { highlightId: messageId });
  }

  function handleResultJump(jumpButton) {
    var card = closest(jumpButton, ".pin-result-card");
    if (!card) return;

    var messageId = card.getAttribute("data-pin-message-id");
    var rootId = card.getAttribute("data-pin-root-id");
    var isReply = card.getAttribute("data-pin-is-reply") === "true";
    if (!messageId) return;

    // スレッドパネルと同時に開いた状態にならないよう、ジャンプ前に必ずピン留めパネルを閉じる。
    closePanel();

    if (isReply) {
      jumpToThreadReply(rootId, messageId);
    } else {
      jumpToNormalMessage(messageId);
    }
  }

  function messageScopeFor(el) {
    return closest(el, ".self-message") || closest(el, ".partner-message");
  }

  // メッセージ本体のピン留め/解除ボタン。通常一覧・スレッドパネルのどちらでも同じ
  // ボタンが描画されるため、update/edit系と同様closest(".thread-panel-body")の有無で
  // display_contextを判定し、正しい文脈のHTML断片で置き換える。
  function togglePin(button) {
    if (button.dataset.submitting === "true") return; // 二重送信防止
    button.dataset.submitting = "true";

    var messageId = button.getAttribute("data-pin-message-id");
    var action = button.getAttribute("data-pin-action");
    var messageScope = messageScopeFor(button);
    var baseUrl = pinUrl(messageId);
    if (!messageId || !action || !baseUrl) {
      button.dataset.submitting = "false";
      return;
    }

    var inThread = !!closest(button, ".thread-panel-body");
    var url = baseUrl + (inThread ? "?display_context=thread" : "");
    var method = action === "unpin" ? "DELETE" : "POST";

    fetch(url, {
      method: method,
      headers: {
        "X-CSRF-Token": csrfToken(),
        "X-Requested-With": "XMLHttpRequest"
      },
      credentials: "same-origin"
    })
      .then(function (response) {
        if (!response.ok) throw new Error("pin_toggle_failed");
        return response.json();
      })
      .then(function (data) {
        if (messageScope && data.html) {
          messageScope.outerHTML = data.html;
        }
        // ピン一覧パネルを開いたままメッセージ側で操作した場合、パネルの内容も
        // 最新化する(自分の画面のみの即時反映。他ユーザーへは同期しない)。
        if (state.open) loadPins();
      })
      .catch(function () {
        button.dataset.submitting = "false";
      });
  }

  function handlePinResultUnpin(unpinButton) {
    var messageId = unpinButton.getAttribute("data-unpin-message-id");
    var baseUrl = pinUrl(messageId);
    if (!messageId || !baseUrl) return;

    fetch(baseUrl, {
      method: "DELETE",
      headers: {
        "X-CSRF-Token": csrfToken(),
        "X-Requested-With": "XMLHttpRequest"
      },
      credentials: "same-origin"
    })
      .then(function (response) {
        if (!response.ok) throw new Error("pin_unpin_failed");
        return response.json();
      })
      .then(function () {
        loadPins();

        // 通常一覧/スレッドパネルに同じメッセージが表示されている場合は、
        // バッジ・ボタン表示もその場で最新化する。
        var messageScope = document.getElementById("chat-message-" + messageId);
        if (messageScope) {
          var pinButton = messageScope.querySelector(".pin-button");
          var pinnedLabel = messageScope.querySelector(".pinned-label");
          if (pinButton) {
            pinButton.classList.remove("pin-button--unpin");
            pinButton.classList.add("pin-button--pin");
            pinButton.setAttribute("data-pin-action", "pin");
            pinButton.setAttribute("aria-label", "ピン留めする");
            var label = pinButton.querySelector(".pin-button-label");
            if (label) label.textContent = "ピン留めする";
          }
          if (pinnedLabel) pinnedLabel.remove();
        }
      })
      .catch(function () {
        // 何もしない(パネルは現状のまま。次回開いた際に再取得される)。
      });
  }

  document.addEventListener("click", function (event) {
    var trigger = closest(event.target, ".chat-pin-trigger");
    if (trigger) {
      openPanel({ returnFocusEl: trigger });
      return;
    }

    var pinButton = closest(event.target, ".pin-button");
    if (pinButton) {
      togglePin(pinButton);
      return;
    }

    var unpinButton = closest(event.target, ".pin-result-unpin");
    if (unpinButton) {
      handlePinResultUnpin(unpinButton);
      return;
    }

    var jumpButton = closest(event.target, ".pin-result-jump");
    if (jumpButton) {
      handleResultJump(jumpButton);
      return;
    }

    if (!state.open) return;

    if (closest(event.target, ".pin-panel-close") || closest(event.target, ".pin-panel-backdrop")) {
      closePanel();
    }
  });

  document.addEventListener("keydown", function (event) {
    if (!state.open) return;

    if (event.key === "Escape") {
      event.preventDefault();
      closePanel();
      return;
    }

    if (event.key === "Tab") {
      var dialog = document.querySelector(".pin-panel-dialog");
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
