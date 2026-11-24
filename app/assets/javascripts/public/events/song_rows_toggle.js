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
    Array.prototype.forEach.call(document.querySelectorAll('.song-part-summary__entry'), syncChip);
  }

  document.addEventListener('click', function (event) {
    var button = event.target.closest && event.target.closest(TOGGLE_SELECTOR);
    if (!button) return;
    var row = button.closest(ROW_SELECTOR);
    if (!row) return;
    event.preventDefault();
    setOpen(row, !row.classList.contains(OPEN_CLASS));
  });

  var CHIP_SELECTOR = '.song-part-summary__entry';

  function checkboxFor(chip) {
    return document.getElementById('event_join_part_ids_' + chip.dataset.joinPartId);
  }

  // チップの選択表示を、送信に使う参加チェック欄(PC表と共通の1つ)の状態に合わせる。
  function syncChip(chip) {
    var checkbox = checkboxFor(chip);
    var selected = !!(checkbox && checkbox.checked);
    chip.setAttribute('aria-pressed', selected ? 'true' : 'false');
    var item = chip.closest('.song-part-summary__item');
    if (item) item.classList.toggle('is-selected', selected);
  }

  function syncChipsFor(checkbox) {
    var id = checkbox.id.replace('event_join_part_ids_', '');
    Array.prototype.forEach.call(document.querySelectorAll(CHIP_SELECTOR + '[data-join-part-id="' + id + '"]'), syncChip);
  }

  // 一覧のチップは押すたびに参加チェック欄を選択/解除するだけ。送信は右下の「参加する」で行い、
  // 確定は従来どおり確認画面の「参加する」で行う。
  document.addEventListener('click', function (event) {
    var chip = event.target.closest && event.target.closest(CHIP_SELECTOR);
    if (!chip) return;
    event.preventDefault();
    var checkbox = checkboxFor(chip);
    if (!checkbox || checkbox.disabled) return;
    checkbox.checked = !checkbox.checked;
    checkbox.dispatchEvent(new Event('change', { bubbles: true }));
  });

  document.addEventListener('change', function (event) {
    var target = event.target;
    if (!target.classList || !target.classList.contains('js-join-part-checkbox')) return;
    var row = target.closest(ROW_SELECTOR);
    if (row) syncSelected(row);
    syncChipsFor(target);
  });

  document.addEventListener('turbolinks:load', syncAll);
  window.addEventListener('pageshow', syncAll);
})();

// バンド出演枠(スマホ)の開閉。PCではボタンを出さず、CSSで常に全体を表示する。
(function () {
  document.addEventListener('click', function (event) {
    var button = event.target.closest && event.target.closest('.event-band-panel__toggle');
    if (!button) return;
    var panel = button.closest('.event-band-panel');
    if (!panel) return;
    event.preventDefault();
    var open = !panel.classList.contains('is-open');
    panel.classList.toggle('is-open', open);
    button.setAttribute('aria-expanded', open ? 'true' : 'false');
    button.textContent = open ? button.dataset.labelClose : button.dataset.labelOpen;
  });
})();

// スマホ右下の「参加する」。参加フォーム(#join_btn)の送信ボタンなので、選んだ全曲・全パートを
// そのまま確認画面へ送る(onsubmit の確認ダイアログも通る)。未選択のときだけ送信を止めて案内する。
(function () {
  var HINT_TEXT = '参加する曲・パートを選んでください';
  var hintTimer = null;

  function selectedCount(form) {
    return form.querySelectorAll('input.js-join-part-checkbox[name="event[join_part_ids][]"]:checked').length;
  }

  function syncFab() {
    var button = document.querySelector('.event-join-fab__button');
    if (!button || !button.form) return;
    var count = selectedCount(button.form);
    var badge = button.querySelector('.event-join-fab__count');
    if (badge) {
      badge.hidden = count === 0;
      badge.textContent = String(count);
    }
    var hint = button.closest('.event-join-fab').querySelector('.event-join-fab__hint');
    if (hint && count > 0) hint.hidden = true;
  }

  function showHint(button) {
    var hint = button.closest('.event-join-fab').querySelector('.event-join-fab__hint');
    if (!hint) return;
    hint.textContent = HINT_TEXT;
    hint.hidden = false;
    clearTimeout(hintTimer);
    hintTimer = setTimeout(function () { hint.hidden = true; }, 4000);
  }

  document.addEventListener('click', function (event) {
    var button = event.target.closest && event.target.closest('.event-join-fab__button');
    if (!button || !button.form) return;
    if (selectedCount(button.form) > 0) return;
    event.preventDefault();
    showHint(button);
  });

  document.addEventListener('change', function (event) {
    var target = event.target;
    if (target.classList && target.classList.contains('js-join-part-checkbox')) syncFab();
  });

  document.addEventListener('turbolinks:load', syncFab);
  window.addEventListener('pageshow', syncFab);
})();
