// 一括メール作成画面の「名前を挿入」。最後に触った欄(件名か本文。初めは本文)のカーソル位置に {{name}} を入れる。
(function () {
  'use strict';

  var lastField = null;

  document.addEventListener('focusin', function (event) {
    if (event.target.matches && event.target.matches('[data-bulk-mail-field]')) {
      lastField = event.target;
    }
  });

  document.addEventListener('click', function (event) {
    var button = event.target.closest && event.target.closest('[data-bulk-mail-insert-name]');
    if (!button) return;

    var field = (lastField && document.body.contains(lastField)) ? lastField : document.querySelector('[data-bulk-mail-body]');
    if (!field) return;

    var placeholder = button.dataset.bulkMailInsertName;
    var start = field.selectionStart != null ? field.selectionStart : field.value.length;
    var end = field.selectionEnd != null ? field.selectionEnd : start;
    field.value = field.value.slice(0, start) + placeholder + field.value.slice(end);
    var caret = start + placeholder.length;
    field.focus();
    field.setSelectionRange(caret, caret);
  });
})();
