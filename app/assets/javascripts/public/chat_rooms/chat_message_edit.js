// メッセージ本文のインライン編集(編集ボタン押下・保存・キャンセル・Escape)を担当する。
//
// 編集フォーム自体は各メッセージのHAML内に常時(hidden)描画済みであり、このファイルは
// 表示切り替えとComposer/メンションオートコンプリートの動的初期化、PATCH送信、
// 成功時のDOM置換のみを行う(chat_thread_panel.js等と同じくdocumentへの
// イベント委譲のみで、body直下への新規DOM生成は行わない)。
//
// 通常一覧・スレッドパネルのどちらの.self-messageにも同じ構造の編集フォームが
// 存在するため、closest(".self-message")で編集対象を一意に特定できる
// (スレッドrootのように同一メッセージが両方の文脈に同時表示される場合でも、
// クリックされたボタンの祖先だけを見るため取り違えない)。
// 成功時はクリック元のスコープのDOMノードだけを置き換え、もう一方の文脈
// (開いたままのスレッドパネル、または通常一覧側)への即時同期は行わない
// (quote_cardと同じく、過剰なDOM同期を避ける設計)。
(function () {
  "use strict";

  if (typeof document === "undefined") return;

  function closest(el, selector) {
    return el && el.closest ? el.closest(selector) : null;
  }

  function csrfToken() {
    var meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : "";
  }

  function messageScopeFor(el) {
    return closest(el, ".self-message");
  }

  function clearEditErrors(form) {
    var errorBox = form.querySelector(".edit-errors");
    if (errorBox) {
      errorBox.hidden = true;
      errorBox.innerHTML = "";
    }
  }

  function showEditErrors(form, errors) {
    var errorBox = form.querySelector(".edit-errors");
    if (!errorBox) return;

    errorBox.innerHTML = "";
    (errors || []).forEach(function (message) {
      var p = document.createElement("p");
      p.textContent = message;
      errorBox.appendChild(p);
    });
    errorBox.hidden = false;
  }

  function openEditMode(messageScope) {
    var contentEl = messageScope.querySelector(".self-content");
    var editForm = messageScope.querySelector(".message-edit-form");
    if (!contentEl || !editForm) return;

    contentEl.hidden = true;
    editForm.hidden = false;

    var composer = editForm.querySelector(".markdown-composer");
    if (composer && window.ChatMarkdownComposer) window.ChatMarkdownComposer.init(composer);

    var form = editForm.querySelector("form");
    var textarea = editForm.querySelector(".markdown-textarea");
    var container = closest(messageScope, ".chat-rooms-show-container");
    if (form && textarea && container && window.ChatMentions && !form._mentionCleanup) {
      var candidatesUrl = container.dataset.mentionCandidatesUrl;
      var currentCustomerId = container.dataset.currentCustomerId;
      if (candidatesUrl) {
        form._mentionCleanup = window.ChatMentions.initTextarea(textarea, candidatesUrl, currentCustomerId);
      }
    }

    if (textarea && typeof textarea.focus === "function") textarea.focus();
  }

  function closeEditMode(messageScope) {
    var contentEl = messageScope.querySelector(".self-content");
    var editForm = messageScope.querySelector(".message-edit-form");
    if (!contentEl || !editForm) return;

    var form = editForm.querySelector("form");
    if (form && form._mentionCleanup && window.ChatMentions && window.ChatMentions.disposeTextarea) {
      window.ChatMentions.disposeTextarea(form._mentionCleanup);
      form._mentionCleanup = null;
    }

    editForm.hidden = true;
    contentEl.hidden = false;
  }

  function submitEditForm(form) {
    if (form.dataset.submitting === "true") return; // 二重送信防止
    form.dataset.submitting = "true";

    var saveButton = form.querySelector(".edit-save-button");
    if (saveButton) saveButton.disabled = true;

    var textarea = form.querySelector(".markdown-textarea");
    if (textarea && window.ChatMentions && window.ChatMentions.getContentForSubmission) {
      textarea.value = window.ChatMentions.getContentForSubmission(textarea);
    }

    var messageScope = closest(form, ".self-message");
    var inThread = !!closest(form, ".thread-panel-body");
    var baseUrl = form.getAttribute("action");
    var url = baseUrl + (inThread ? "?display_context=thread" : "");

    var formData = new FormData(form);
    clearEditErrors(form);

    function finish() {
      form.dataset.submitting = "false";
      if (saveButton) saveButton.disabled = false;
    }

    fetch(url, {
      method: "PATCH",
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
          showEditErrors(form, result.data.errors);
          finish();
          return;
        }

        if (messageScope && result.data.html) {
          messageScope.outerHTML = result.data.html;
        }
        finish();
      })
      .catch(function () {
        showEditErrors(form, ["通信エラーが発生しました"]);
        finish();
      });
  }

  document.addEventListener("click", function (event) {
    var editButton = closest(event.target, ".edit-button");
    if (editButton) {
      var messageScope = messageScopeFor(editButton);
      if (messageScope) openEditMode(messageScope);
      return;
    }

    var cancelButton = closest(event.target, ".edit-cancel-button");
    if (cancelButton) {
      var cancelScope = messageScopeFor(cancelButton);
      if (cancelScope) closeEditMode(cancelScope);
    }
  });

  document.addEventListener("keydown", function (event) {
    if (event.key !== "Escape") return;

    var editForm = closest(event.target, ".message-edit-form");
    if (!editForm) return;

    var messageScope = closest(editForm, ".self-message");
    if (messageScope) closeEditMode(messageScope);
  });

  document.addEventListener("submit", function (event) {
    var form = closest(event.target, ".message-edit-form form");
    if (!form) return;

    event.preventDefault();
    submitEditForm(form);
  });
})();
