// Markdownツールバー・編集/プレビュー切り替え・サーバーレンダリングプレビュー
// GitHub/Slack風のチャット入力欄(.markdown-composer)を初期化する。
// クライアント側でMarkdownをパースするライブラリ(markdown-it/marked等)は使わず、
// 表示時と同じサーバーサイドレンダラー(Chat::MarkdownRenderer)をAjaxで呼び出すことで
// 見た目のズレを防いでいる。
document.addEventListener('turbolinks:load', function () {
  if (!document.URL.match(/chat_rooms/)) return;

  var PREVIEW_DEBOUNCE_MS = 350;

  document.querySelectorAll('.markdown-composer').forEach(initComposer);

  function initComposer(composer) {
    var textarea = composer.querySelector('.markdown-textarea');
    var previewPane = composer.querySelector('.markdown-preview-pane');
    var previewUrl = composer.dataset.previewUrl;
    if (!textarea || !previewPane || !previewUrl) return;

    initToolbar(composer, textarea);
    initTabs(composer, textarea, previewPane, previewUrl);
  }

  function initToolbar(composer, textarea) {
    composer.querySelectorAll('.md-btn').forEach(function (button) {
      button.addEventListener('click', function () {
        applyMarkdown(textarea, button.dataset.md);
      });
    });
  }

  function applyMarkdown(textarea, type) {
    switch (type) {
      case 'bold':
        wrapSelection(textarea, '**', '**', '太字');
        break;
      case 'italic':
        wrapSelection(textarea, '*', '*', '斜体');
        break;
      case 'strikethrough':
        wrapSelection(textarea, '~~', '~~', '打ち消し');
        break;
      case 'code':
        wrapSelection(textarea, '`', '`', 'コード');
        break;
      case 'heading':
        insertLinePrefix(textarea, '# ');
        break;
      case 'quote':
        insertLinePrefix(textarea, '> ');
        break;
      case 'unordered-list':
        insertLinePrefix(textarea, '- ');
        break;
      case 'ordered-list':
        insertLinePrefix(textarea, '1. ');
        break;
      case 'checklist':
        insertLinePrefix(textarea, '- [ ] ');
        break;
      case 'codeblock':
        wrapSelection(textarea, '```\n', '\n```', 'コード');
        break;
      case 'link':
        insertLinkLike(textarea, '[', '](https://)', 'リンクテキスト');
        break;
      case 'image':
        insertLinkLike(textarea, '![', '](https://)', '画像の説明');
        break;
      case 'hr':
        insertBlock(textarea, '\n---\n');
        break;
      default:
        return;
    }
    textarea.dispatchEvent(new Event('input'));
  }

  function wrapSelection(textarea, before, after, placeholder) {
    var start = textarea.selectionStart;
    var end = textarea.selectionEnd;
    var value = textarea.value;
    var selected = value.slice(start, end) || placeholder;

    textarea.value = value.slice(0, start) + before + selected + after + value.slice(end);
    textarea.focus();
    textarea.setSelectionRange(start + before.length, start + before.length + selected.length);
  }

  function insertLinkLike(textarea, before, after, placeholder) {
    wrapSelection(textarea, before, after, placeholder);
  }

  function insertLinePrefix(textarea, prefix) {
    var start = textarea.selectionStart;
    var value = textarea.value;
    var lineStart = value.lastIndexOf('\n', start - 1) + 1;

    textarea.value = value.slice(0, lineStart) + prefix + value.slice(lineStart);
    textarea.focus();
    var cursor = start + prefix.length;
    textarea.setSelectionRange(cursor, cursor);
  }

  function insertBlock(textarea, block) {
    var start = textarea.selectionStart;
    var value = textarea.value;

    textarea.value = value.slice(0, start) + block + value.slice(start);
    textarea.focus();
    var cursor = start + block.length;
    textarea.setSelectionRange(cursor, cursor);
  }

  function initTabs(composer, textarea, previewPane, previewUrl) {
    var editPane = composer.querySelector('.edit-pane');
    var previewPaneWrapper = composer.querySelector('.preview-pane');
    var tabs = composer.querySelectorAll('.md-tab');
    var debounceTimer = null;

    tabs.forEach(function (tab) {
      tab.addEventListener('click', function () {
        tabs.forEach(function (t) { t.classList.remove('is-active'); });
        tab.classList.add('is-active');

        if (tab.dataset.tab === 'preview') {
          editPane.classList.remove('is-active');
          previewPaneWrapper.classList.add('is-active');
          renderPreview();
        } else {
          previewPaneWrapper.classList.remove('is-active');
          editPane.classList.add('is-active');
        }
      });
    });

    textarea.addEventListener('input', function () {
      clearTimeout(debounceTimer);
      debounceTimer = setTimeout(renderPreview, PREVIEW_DEBOUNCE_MS);
    });

    function renderPreview() {
      var content = textarea.value;
      if (!content.trim()) {
        previewPane.innerHTML = '<p class="markdown-preview-placeholder">入力するとここにプレビューが表示されます</p>';
        return;
      }

      var csrfMeta = document.querySelector('meta[name="csrf-token"]');

      fetch(previewUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfMeta ? csrfMeta.content : '',
          'X-Requested-With': 'XMLHttpRequest'
        },
        body: JSON.stringify({ content: content })
      })
        .then(function (response) { return response.json(); })
        .then(function (data) {
          // サーバー側(Chat::MarkdownRenderer)でSanitize済みのHTMLのみを信頼して挿入する
          previewPane.innerHTML = data.html;
        })
        .catch(function () {
          previewPane.innerHTML = '<p class="markdown-preview-placeholder">プレビューを取得できませんでした</p>';
        });
    }
  }
});
