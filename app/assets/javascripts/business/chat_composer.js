// Business のタイムライン / プロジェクトチャット入力欄(.business-composer)。
// マークアップは app/views/business/chat/_composer.html.haml。入力欄は書式なしの textarea。
// - 添付: 選んだファイルを一覧表示し、送信前に1件ずつ取り消せる。形式・容量・件数は
//   画面でも確認するが、最終的な判定はサーバー側(BusinessChatContent)で行う。
// - 添付画像の拡大表示([data-business-lightbox])。
(function () {
  'use strict';

  document.addEventListener('turbolinks:load', function () {
    document.querySelectorAll('[data-business-composer]').forEach(initComposer);
  });

  function initComposer(composer) {
    if (composer.dataset.composerInitialized === 'true') return;
    composer.dataset.composerInitialized = 'true';

    var textarea = composer.querySelector('.business-composer__textarea');
    var form = composer.closest('form');
    if (!textarea || !form) return;

    var files = initAttachments(composer);

    form.addEventListener('submit', function (event) {
      if (textarea.value.trim() !== '' || files.count() > 0) return;
      event.preventDefault();
      showError(composer, 'メッセージを入力するか、ファイルを選んでください。');
      enableSubmit(form);
    });
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
