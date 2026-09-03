// スタンプ選択パネルの開閉制御。
// マークアップは app/views/shared/_stamp_picker.html.haml。
// - トグルボタンでパネルを開閉し、aria-expanded / hidden を同期する
// - パネル外クリック・Escape で閉じる
// - 開いたら最初のスタンプへフォーカスを移す（キーボード操作への配慮）
// スタンプ送信自体は各 mini フォームの submit（rails-ujs の confirm 経由）に任せる。
(function () {
  'use strict';

  function closePicker(picker) {
    var toggle = picker.querySelector('[data-stamp-picker-toggle]');
    var panel = picker.querySelector('[data-stamp-picker-panel]');
    if (!toggle || !panel) return;
    panel.hidden = true;
    toggle.setAttribute('aria-expanded', 'false');
  }

  function openPicker(picker) {
    var toggle = picker.querySelector('[data-stamp-picker-toggle]');
    var panel = picker.querySelector('[data-stamp-picker-panel]');
    if (!toggle || !panel) return;
    panel.hidden = false;
    toggle.setAttribute('aria-expanded', 'true');
    var firstChoice = panel.querySelector('.stamp-choice');
    if (firstChoice) firstChoice.focus();
  }

  function closeAll(except) {
    document.querySelectorAll('[data-stamp-picker]').forEach(function (picker) {
      if (picker !== except) closePicker(picker);
    });
  }

  function onToggleClick(event) {
    var toggle = event.target.closest('[data-stamp-picker-toggle]');
    if (!toggle) return;
    var picker = toggle.closest('[data-stamp-picker]');
    if (!picker) return;
    var isOpen = toggle.getAttribute('aria-expanded') === 'true';
    closeAll(picker);
    if (isOpen) {
      closePicker(picker);
    } else {
      openPicker(picker);
    }
  }

  function onDocumentClick(event) {
    if (event.target.closest('[data-stamp-picker]')) return;
    closeAll(null);
  }

  function onKeydown(event) {
    if (event.key !== 'Escape' && event.key !== 'Esc') return;
    var openPickerEl = document.querySelector('[data-stamp-picker] [data-stamp-picker-toggle][aria-expanded="true"]');
    if (!openPickerEl) return;
    var picker = openPickerEl.closest('[data-stamp-picker]');
    closePicker(picker);
    openPickerEl.focus();
  }

  function bind() {
    if (document.body.dataset.stampPickerBound === 'true') return;
    document.body.dataset.stampPickerBound = 'true';
    document.addEventListener('click', onToggleClick);
    document.addEventListener('click', onDocumentClick);
    document.addEventListener('keydown', onKeydown);
  }

  document.addEventListener('turbolinks:load', bind);
  document.addEventListener('DOMContentLoaded', bind);
})();
