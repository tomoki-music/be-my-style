// スレッド返信パネル(Slack風のスレッド表示)の開閉・取得・投稿を管理する。
//
// パネル本文(元メッセージ・返信一覧・返信フォーム)はサーバーからHTML断片をfetchして
// 都度差し替えるため、内部のtextarea(メンションオートコンプリート)はページ遷移を伴わず
// 動的に生成・破棄される。chat_mention_autocomplete.jsの公開API(initTextarea/disposeTextarea)
// を使い、パネルを閉じる・再取得するたびに前回分だけを確実に後始末する
// (cleanupAllInstances()は同一ページの全インスタンス=通常投稿フォームまで巻き込むため使わない)。
//
// 開閉・投稿のトリガーとなるクリック・キー操作はdocumentへの委譲のみで登録し、
// 動的に挿入される要素(返信ボタン・返信フォーム等)にも自動的に効くため、
// chat_reply_composer.js等と同じくper-nodeのリスナー登録・Turbolinksクリーンアップは不要。
// ただしbfcache復元時にパネルが開いたまま復元されるのを防ぐため、
// turbolinks:before-cacheでパネル状態自体はリセットする。
(function () {
  "use strict";

  if (typeof document === "undefined") return;

  var HIGHLIGHT_CLASS = "chat-message-highlight";
  var HIGHLIGHT_DURATION_MS = 3000;

  var state = {
    open: false,
    rootMessageId: null,
    mentionCleanup: null,
    returnFocusEl: null
  };

  function closest(el, selector) {
    return el && el.closest ? el.closest(selector) : null;
  }

  function panelEl() {
    return document.getElementById("thread-panel");
  }

  function panelBodyEl() {
    return document.getElementById("thread-panel-body");
  }

  function container() {
    return document.querySelector(".chat-rooms-show-container");
  }

  function threadUrl(id) {
    var c = container();
    var template = c ? c.dataset.threadUrlTemplate : null;
    if (!template) return null;
    return template.replace("__ID__", encodeURIComponent(id));
  }

  function threadReplyUrl(id) {
    var c = container();
    var template = c ? c.dataset.threadReplyUrlTemplate : null;
    if (!template) return null;
    return template.replace("__ID__", encodeURIComponent(id));
  }

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : "";
  }

  function disposeMentionInstance() {
    if (state.mentionCleanup && window.ChatMentions && window.ChatMentions.disposeTextarea) {
      window.ChatMentions.disposeTextarea(state.mentionCleanup);
    }
    state.mentionCleanup = null;
  }

  function resetPanel() {
    var panel = panelEl();
    if (panel) panel.hidden = true;
    document.body.classList.remove("thread-panel-open");
    disposeMentionInstance();

    var body = panelBodyEl();
    if (body) body.innerHTML = "";

    state.open = false;
    state.rootMessageId = null;
    state.returnFocusEl = null;
  }

  function focusPanel() {
    var dialog = document.querySelector(".thread-panel-dialog");
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

  function openThread(messageId, options) {
    var panel = panelEl();
    var body = panelBodyEl();
    if (!panel || !body || !messageId) return;

    options = options || {};

    state.open = true;
    state.rootMessageId = messageId;
    state.returnFocusEl =
      options.returnFocusEl ||
      document.querySelector('.thread-replies-button[data-thread-message-id="' + messageId + '"]');

    panel.hidden = false;
    document.body.classList.add("thread-panel-open");
    body.innerHTML = '<p class="thread-panel-placeholder">読み込み中…</p>';

    var url = threadUrl(messageId);
    if (!url) return;

    fetch(url, {
      headers: { "X-Requested-With": "XMLHttpRequest" },
      credentials: "same-origin"
    })
      .then(function (response) {
        if (!response.ok) throw new Error("thread_fetch_failed");
        return response.text();
      })
      .then(function (html) {
        renderThreadBody(html, options.highlightId);
      })
      .catch(function () {
        body.innerHTML = '<p class="thread-panel-placeholder">スレッドを表示できませんでした</p>';
      });
  }

  function renderThreadBody(html, highlightId) {
    var body = panelBodyEl();
    if (!body) return;

    disposeMentionInstance();
    body.innerHTML = html;

    var composer = body.querySelector(".markdown-composer");
    if (composer && window.ChatMarkdownComposer) window.ChatMarkdownComposer.init(composer);

    var textarea = body.querySelector(".markdown-textarea");
    var c = container();
    if (textarea && c && window.ChatMentions) {
      var candidatesUrl = c.dataset.mentionCandidatesUrl;
      var currentCustomerId = c.dataset.currentCustomerId;
      if (candidatesUrl) {
        state.mentionCleanup = window.ChatMentions.initTextarea(textarea, candidatesUrl, currentCustomerId);
      }
    }

    focusPanel();
    highlightWithinPanel(body, highlightId);
  }

  // 通常一覧側と同じid(chat-message-<id>)を使うと、パネルに表示中の元メッセージが
  // 一覧側と重複してしまうため、パネル内はdata-chat-message-id属性でスコープして探す。
  function highlightWithinPanel(body, highlightId) {
    if (!highlightId) return;

    var target = body.querySelector('[data-chat-message-id="' + highlightId + '"]');
    if (!target) return;

    target.scrollIntoView({ block: "center" });
    target.classList.add(HIGHLIGHT_CLASS);
    setTimeout(function () {
      target.classList.remove(HIGHLIGHT_CLASS);
    }, HIGHLIGHT_DURATION_MS);
  }

  function closeThread() {
    var panel = panelEl();
    if (!panel) return;

    var returnFocusEl = state.returnFocusEl;
    resetPanel();

    if (returnFocusEl && typeof returnFocusEl.focus === "function") {
      returnFocusEl.focus();
    }
  }

  function updateReplyCountUI(rootId, count) {
    var panelCount = document.querySelector("[data-thread-replies-count]");
    if (panelCount) panelCount.textContent = count + "件の返信";

    var mainMessage = document.getElementById("chat-message-" + rootId);
    if (!mainMessage) return;

    var badge = mainMessage.querySelector(".thread-replies-button");
    if (count <= 0) {
      if (badge) badge.remove();
      return;
    }

    if (!badge) {
      badge = document.createElement("button");
      badge.type = "button";
      badge.className = "thread-replies-button";
      badge.setAttribute("data-thread-message-id", rootId);
      var meta = mainMessage.querySelector(".message-meta");
      if (meta && meta.parentNode) meta.parentNode.insertBefore(badge, meta.nextSibling);
    }
    badge.setAttribute("aria-label", count + "件の返信を表示");
    badge.innerHTML = '<span class="thread-replies-button-icon">↩</span>' + count + "件の返信";
  }

  function clearThreadReplyErrors(form) {
    var errorBox = form.querySelector(".thread-reply-errors");
    if (errorBox) {
      errorBox.hidden = true;
      errorBox.innerHTML = "";
    }
  }

  function showThreadReplyErrors(form, errors) {
    var errorBox = form.querySelector(".thread-reply-errors");
    if (!errorBox) return;

    errorBox.innerHTML = "";
    (errors || []).forEach(function (message) {
      var p = document.createElement("p");
      p.textContent = message;
      errorBox.appendChild(p);
    });
    errorBox.hidden = false;
  }

  function handleThreadReplySuccess(data, form) {
    var list = document.getElementById("thread-replies-list");
    if (list && data.html) {
      list.insertAdjacentHTML("beforeend", data.html);
      var newItem = list.lastElementChild;
      if (newItem && newItem.scrollIntoView) newItem.scrollIntoView({ block: "end" });
    }
    updateReplyCountUI(data.root_message_id, data.replies_count);

    // form.reset()はhidden fieldの値を初期状態へ戻すだけで、表示中の引用プレビュー
    // (.quote-preview)自体は消えないため、投稿成功後は明示的にリセットする。
    if (form && window.ChatQuoteReply && window.ChatQuoteReply.reset) {
      window.ChatQuoteReply.reset(form);
    }
  }

  function submitThreadReply(form) {
    if (form.dataset.submitting === "true") return; // 二重送信防止
    form.dataset.submitting = "true";

    var submitButton = form.querySelector(".thread-reply-submit");
    if (submitButton) submitButton.disabled = true;

    var textarea = form.querySelector(".markdown-textarea");
    if (textarea && window.ChatMentions && window.ChatMentions.getContentForSubmission) {
      textarea.value = window.ChatMentions.getContentForSubmission(textarea);
    }

    var formData = new FormData(form);
    var url = threadReplyUrl(state.rootMessageId);
    clearThreadReplyErrors(form);

    function finish() {
      form.dataset.submitting = "false";
      if (submitButton) submitButton.disabled = false;
    }

    if (!url) {
      finish();
      return;
    }

    fetch(url, {
      method: "POST",
      headers: {
        "X-CSRF-Token": csrfToken(),
        "X-Requested-With": "XMLHttpRequest"
      },
      credentials: "same-origin",
      body: formData
    })
      .then(function (response) {
        return response
          .json()
          .catch(function () {
            return {};
          })
          .then(function (data) {
            return { ok: response.ok, data: data };
          });
      })
      .then(function (result) {
        if (!result.ok) {
          showThreadReplyErrors(form, result.data.errors);
          finish();
          return;
        }
        form.reset();
        handleThreadReplySuccess(result.data, form);
        finish();
      })
      .catch(function () {
        showThreadReplyErrors(form, ["通信エラーが発生しました"]);
        finish();
      });
  }

  document.addEventListener("click", function (event) {
    var openButton = closest(event.target, ".thread-replies-button");
    if (openButton) {
      var id = openButton.getAttribute("data-thread-message-id");
      if (id) openThread(id, { returnFocusEl: openButton });
      return;
    }

    if (!state.open) return;

    if (closest(event.target, ".thread-panel-close") || closest(event.target, ".thread-panel-backdrop")) {
      closeThread();
    }
  });

  document.addEventListener("keydown", function (event) {
    if (!state.open) return;

    if (event.key === "Escape") {
      event.preventDefault();
      closeThread();
      return;
    }

    if (event.key === "Tab") {
      var dialog = document.querySelector(".thread-panel-dialog");
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

  document.addEventListener("submit", function (event) {
    var form = closest(event.target, ".thread-reply-form");
    if (!form) return;

    event.preventDefault();
    submitThreadReply(form);
  });

  document.addEventListener("turbolinks:before-cache", resetPanel);

  // 引用カード(.quote-card)から、現在パネルに表示されていないスレッド内メッセージへ
  // 移動するためのフォールバック用公開API(chat_message_reply_navigation.js内で使用)。
  // messageIdがスレッドrootかreplyかを問わず、thread_reply同様サーバー側(thread_root)で
  // 解決させ、パネルを開いた上でhighlightIdをハイライトする。
  window.ChatThreadPanel = window.ChatThreadPanel || {};
  window.ChatThreadPanel.open = openThread;

  document.addEventListener("turbolinks:load", function () {
    if (!document.URL.match(/chat_rooms/)) return;

    var params = new URLSearchParams(window.location.search);
    var threadMessageId = params.get("thread_message_id");
    if (!threadMessageId) return;

    openThread(threadMessageId, { highlightId: params.get("highlight_message_id") });
  });
})();
