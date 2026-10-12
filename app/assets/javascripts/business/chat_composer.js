// Business のタイムライン / プロジェクトチャット入力欄(.business-composer)。
// マークアップは app/views/business/chat/_composer.html.haml。
// - 書式ボタン: 選択中の文字に Markdown 記法を付ける。未選択なら入力例を入れて選択状態にする。
// - プレビュー: 送信後と同じ Chat::MarkdownRenderer の結果(サーバーでサニタイズ済み)を表示する。
// - 添付: 選んだファイルを一覧表示し、送信前に1件ずつ取り消せる。形式・容量・件数は
//   画面でも確認するが、最終的な判定はサーバー側(BusinessChatContent)で行う。
// - 添付画像の拡大表示([data-business-lightbox])。
(function () {
  'use strict';

  var PREVIEW_DEBOUNCE_MS = 400;

  document.addEventListener('turbolinks:load', function () {
    document.querySelectorAll('[data-business-composer]').forEach(initComposer);
  });

  function initComposer(composer) {
    if (composer.dataset.composerInitialized === 'true') return;
    composer.dataset.composerInitialized = 'true';

    var textarea = composer.querySelector('.business-composer__textarea');
    var form = composer.closest('form');
    if (!textarea || !form) return;

    composer.querySelectorAll('[data-format]').forEach(function (button) {
      button.addEventListener('click', function () {
        applyFormat(textarea, button.dataset.format);
      });
    });

    initPreview(composer, textarea);
    var files = initAttachments(composer);

    form.addEventListener('submit', function (event) {
      if (textarea.value.trim() !== '' || files.count() > 0) return;
      event.preventDefault();
      showError(composer, 'メッセージを入力するか、ファイルを選んでください。');
      enableSubmit(form);
    });
  }

  // ---------- 書式 ----------

  function applyFormat(textarea, format) {
    switch (format) {
      case 'bold':
        wrapSelection(textarea, '**', '**', '太字にしたい文字');
        break;
      case 'heading':
        prefixLines(textarea, '## ', '大きく表示したい文字');
        break;
      case 'list':
        prefixLines(textarea, '- ', '項目');
        break;
      case 'link':
        insertLink(textarea);
        break;
      default:
        return;
    }
    textarea.dispatchEvent(new Event('input'));
  }

  function replaceRange(textarea, start, end, text, selectFrom, selectTo) {
    var value = textarea.value;
    textarea.value = value.slice(0, start) + text + value.slice(end);
    textarea.focus();
    textarea.setSelectionRange(start + selectFrom, start + selectTo);
  }

  function wrapSelection(textarea, before, after, example) {
    var start = textarea.selectionStart;
    var end = textarea.selectionEnd;
    var selected = textarea.value.slice(start, end);
    var inner = selected || example;
    replaceRange(textarea, start, end, before + inner + after, before.length, before.length + inner.length);
  }

  // 選択範囲の各行(未選択ならカーソル行)の先頭に記号を付ける。空の行には入力例を入れる。
  function prefixLines(textarea, prefix, example) {
    var value = textarea.value;
    var start = textarea.selectionStart;
    var end = textarea.selectionEnd;
    var lineStart = value.lastIndexOf('\n', start - 1) + 1;
    var lineEndIndex = value.indexOf('\n', end);
    var lineEnd = lineEndIndex === -1 ? value.length : lineEndIndex;
    var block = value.slice(lineStart, lineEnd);

    if (block.trim() === '') {
      var text = prefix + example;
      // 前後の行とつながらないよう、必要なら改行を補う。
      var lead = lineStart > 0 && value[lineStart - 1] !== '\n' ? '\n' : '';
      replaceRange(textarea, lineStart, lineEnd, lead + text, lead.length + prefix.length, lead.length + text.length);
      return;
    }

    var lines = block.split('\n').map(function (line) {
      if (line.trim() === '' || line.indexOf(prefix) === 0) return line;
      return prefix + line.replace(/^(#{1,6}\s+|[-*+]\s+)/, '');
    });
    var result = lines.join('\n');
    replaceRange(textarea, lineStart, lineEnd, result, 0, result.length);
  }

  function insertLink(textarea) {
    var start = textarea.selectionStart;
    var end = textarea.selectionEnd;
    var selected = textarea.value.slice(start, end).trim();
    var selectedIsUrl = /^https?:\/\/\S+$/.test(selected);

    var url = selectedIsUrl ? selected : window.prompt('リンク先のURLを入力してください（https:// から始まるもの）', 'https://');
    if (url === null) return;
    url = url.trim();
    if (!/^https?:\/\/[^\s()<>]+$/.test(url)) {
      window.alert('リンクにできるのは http:// または https:// から始まるURLです。');
      return;
    }

    var label = selected && !selectedIsUrl ? selected : 'リンクの文字';
    var text = '[' + label + '](' + url + ')';
    replaceRange(textarea, start, end, text, 1, 1 + label.length);
  }

  // ---------- プレビュー ----------

  function initPreview(composer, textarea) {
    var editPane = composer.querySelector('.business-composer__edit');
    var previewPane = composer.querySelector('.business-composer__preview');
    var previewBody = composer.querySelector('.business-composer__preview-body');
    var tabs = composer.querySelectorAll('[data-composer-tab]');
    var toolbarButtons = composer.querySelectorAll('[data-format]');
    var previewUrl = composer.dataset.previewUrl;
    var timer = null;
    var requestId = 0;

    tabs.forEach(function (tab) {
      tab.addEventListener('click', function () {
        var showPreview = tab.dataset.composerTab === 'preview';
        tabs.forEach(function (t) {
          var active = t === tab;
          t.classList.toggle('is-active', active);
          t.setAttribute('aria-pressed', active ? 'true' : 'false');
        });
        editPane.hidden = showPreview;
        previewPane.hidden = !showPreview;
        toolbarButtons.forEach(function (button) { button.disabled = showPreview; });
        if (showPreview) {
          render();
        } else {
          textarea.focus();
        }
      });
    });

    textarea.addEventListener('input', function () {
      if (previewPane.hidden) return;
      clearTimeout(timer);
      timer = setTimeout(render, PREVIEW_DEBOUNCE_MS);
    });

    function setPlaceholder(message) {
      previewBody.innerHTML = '';
      var p = document.createElement('p');
      p.className = 'business-composer__placeholder';
      p.textContent = message;
      previewBody.appendChild(p);
    }

    function render() {
      var content = textarea.value;
      if (content.trim() === '') {
        setPlaceholder('入力した内容が、送信後と同じ見た目でここに表示されます。');
        return;
      }

      var currentRequest = ++requestId;
      var csrf = document.querySelector('meta[name="csrf-token"]');
      fetch(previewUrl, {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrf ? csrf.content : '',
          'X-Requested-With': 'XMLHttpRequest'
        },
        body: JSON.stringify({ content: content })
      })
        .then(function (response) { return response.json(); })
        .then(function (data) {
          if (currentRequest !== requestId) return;
          if (typeof data.html !== 'string') throw new Error('invalid');
          // サーバー側(Chat::MarkdownRenderer)でサニタイズ済みの HTML のみを挿入する。
          previewBody.innerHTML = data.html;
        })
        .catch(function () {
          if (currentRequest !== requestId) return;
          setPlaceholder('プレビューを表示できませんでした。');
        });
    }
  }

  // ---------- 添付 ----------

  function initAttachments(composer) {
    var input = composer.querySelector('.business-composer__file-input');
    var list = composer.querySelector('.business-composer__file-list');
    var maxFiles = parseInt(composer.dataset.maxFiles, 10);
    var maxSize = parseInt(composer.dataset.maxSize, 10);
    var allowed = (composer.dataset.allowedExtensions || '').split(',');
    // DataTransfer を使えない古いブラウザでは、選び直しのみ(個別の取り消しは不可)。
    var canEdit = typeof DataTransfer === 'function';
    var selected = [];

    if (!input || !list) return { count: function () { return 0; } };

    input.addEventListener('change', function () {
      var errors = [];
      var incoming = Array.prototype.slice.call(input.files);
      var next = canEdit ? selected.slice() : [];

      incoming.forEach(function (file) {
        var ext = (file.name.split('.').pop() || '').toLowerCase();
        if (file.name.indexOf('.') === -1 || allowed.indexOf(ext) === -1) {
          errors.push('「' + file.name + '」は添付できない形式です。');
        } else if (file.size > maxSize) {
          errors.push('「' + file.name + '」は' + Math.round(maxSize / 1048576) + 'MBを超えています。');
        } else if (next.length >= maxFiles) {
          errors.push('添付ファイルは' + maxFiles + '件までです。');
        } else {
          next.push(file);
        }
      });

      selected = next;
      syncInput();
      render();
      showError(composer, uniq(errors).join(' '));
    });

    function syncInput() {
      if (!canEdit) return;
      var transfer = new DataTransfer();
      selected.forEach(function (file) { transfer.items.add(file); });
      input.files = transfer.files;
    }

    function render() {
      list.innerHTML = '';
      selected.forEach(function (file, index) {
        var item = document.createElement('li');
        item.className = 'business-composer__file';

        var name = document.createElement('span');
        name.className = 'business-composer__file-name';
        name.textContent = file.name + '（' + formatSize(file.size) + '）';
        item.appendChild(name);

        if (canEdit) {
          var remove = document.createElement('button');
          remove.type = 'button';
          remove.className = 'business-composer__file-remove';
          remove.setAttribute('aria-label', '「' + file.name + '」の添付を取り消す');
          remove.textContent = '×';
          remove.addEventListener('click', function () {
            selected.splice(index, 1);
            syncInput();
            render();
            showError(composer, '');
          });
          item.appendChild(remove);
        }
        list.appendChild(item);
      });
      list.hidden = selected.length === 0;
    }

    return { count: function () { return canEdit ? selected.length : input.files.length; } };
  }

  function formatSize(bytes) {
    if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + 'MB';
    return Math.max(1, Math.round(bytes / 1024)) + 'KB';
  }

  function uniq(items) {
    return items.filter(function (item, index) { return items.indexOf(item) === index; });
  }

  function showError(composer, message) {
    var error = composer.querySelector('.business-composer__error');
    if (!error) return;
    error.textContent = message;
    error.hidden = message === '';
  }

  // rails-ujs の disable-with で無効化された送信ボタンを戻す。
  function enableSubmit(form) {
    setTimeout(function () {
      form.querySelectorAll('[data-disable-with]').forEach(function (button) {
        if (window.Rails && window.Rails.enableElement) window.Rails.enableElement(button);
      });
    }, 0);
  }

  // ---------- 画像の拡大表示 ----------

  var lastTrigger = null;

  function dialog() {
    return document.querySelector('[data-business-lightbox-dialog]');
  }

  function closeLightbox() {
    var box = dialog();
    if (!box || box.hidden) return;
    box.hidden = true;
    box.querySelector('img').removeAttribute('src');
    if (lastTrigger) lastTrigger.focus();
  }

  document.addEventListener('click', function (event) {
    var trigger = event.target.closest('[data-business-lightbox]');
    var box = dialog();
    if (trigger && box) {
      event.preventDefault();
      lastTrigger = trigger;
      var image = box.querySelector('img');
      var thumb = trigger.querySelector('img');
      image.src = trigger.getAttribute('href');
      image.alt = thumb ? thumb.alt : '';
      box.hidden = false;
      box.querySelector('[data-business-lightbox-close]').focus();
      return;
    }
    if (box && !box.hidden && (event.target === box || event.target.closest('[data-business-lightbox-close]'))) {
      closeLightbox();
    }
  });

  document.addEventListener('keydown', function (event) {
    if (event.key === 'Escape') closeLightbox();
  });

  document.addEventListener('turbolinks:before-cache', closeLightbox);
})();
