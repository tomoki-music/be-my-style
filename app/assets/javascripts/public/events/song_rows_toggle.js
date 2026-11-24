// イベント詳細の楽曲表(スマホの1曲1行表示)で、曲ごとの詳細(参加フォーム・担当者・応援)を開閉する。
// 開閉はクラスの付け外しだけで、チェック欄はPC表と同じ1つを使い回す。閉じても選択は消えない。
// ボタンは type="button" なので参加フォーム(#join_btn)を送信しない。
(function () {
  var ROW_SELECTOR = '.event-song-row';
  var TOGGLE_SELECTOR = '.song-row-toggle';
  var OPEN_CLASS = 'is-open';

  function setOpen(row, open) {
    row.classList.toggle(OPEN_CLASS, open);
    var button = row.querySelector(TOGGLE_SELECTOR);
    if (!button) return;
    button.setAttribute('aria-expanded', open ? 'true' : 'false');
    var label = button.querySelector('.song-row-toggle__label');
    if (label) label.textContent = open ? button.dataset.labelClose : button.dataset.labelOpen;
  }

  function syncSelected(row) {
    var badge = row.querySelector('.song-row-toggle__selected');
    if (!badge) return;
    badge.hidden = !row.querySelector('input.js-join-part-checkbox:checked');
  }

  function syncAll() {
    Array.prototype.forEach.call(document.querySelectorAll(ROW_SELECTOR), syncSelected);
  }

  document.addEventListener('click', function (event) {
    var button = event.target.closest && event.target.closest(TOGGLE_SELECTOR);
    if (!button) return;
    var row = button.closest(ROW_SELECTOR);
    if (!row) return;
    event.preventDefault();
    setOpen(row, !row.classList.contains(OPEN_CLASS));
  });

  document.addEventListener('change', function (event) {
    var target = event.target;
    if (!target.classList || !target.classList.contains('js-join-part-checkbox')) return;
    var row = target.closest(ROW_SELECTOR);
    if (row) syncSelected(row);
  });

  document.addEventListener('turbolinks:load', syncAll);
  window.addEventListener('pageshow', syncAll);
})();
