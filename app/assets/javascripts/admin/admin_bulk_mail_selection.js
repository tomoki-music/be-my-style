// 管理画面 TOP のメンバー一覧の選択。選んだ会員 ID は sessionStorage に持ち、絞り込みを変えても残す。
// 「条件に一致した人をすべて選択」は、表示中の行に限らずサーバーが渡した一致件数ぶんの ID を追加する。
// 送るのは会員 ID だけで、メールアドレスはサーバー側で ID から読む。
(function () {
  'use strict';

  var STORAGE_KEY = 'adminBulkMailSelection';

  function load() {
    try {
      var ids = JSON.parse(window.sessionStorage.getItem(STORAGE_KEY) || '[]');
      return Array.isArray(ids) ? ids.map(String) : [];
    } catch (e) {
      return [];
    }
  }

  function save(ids) {
    try {
      window.sessionStorage.setItem(STORAGE_KEY, JSON.stringify(ids));
    } catch (e) {
      // 保存できない環境では、この画面の中だけで選択を持つ。
    }
  }

  function setup() {
    // 送信を受け付けた画面に来たら選択を消す(同じ人へ続けて誤送信しないため)。
    if (document.querySelector('[data-bulk-select-reset]')) {
      save([]);
    }

    var root = document.querySelector('[data-admin-bulk-select]');
    if (!root) return;

    var selected = load();
    var matchingIds = [];
    try {
      matchingIds = JSON.parse(root.dataset.matchingIds || '[]').map(String);
    } catch (e) {
      matchingIds = [];
    }

    var countEl = root.querySelector('[data-bulk-select-count]');
    var idsField = root.querySelector('[data-bulk-select-ids]');
    var submit = root.querySelector('[data-bulk-select-submit]');
    var items = function () { return document.querySelectorAll('[data-bulk-select-item]'); };

    function render() {
      var set = {};
      selected.forEach(function (id) { set[id] = true; });
      items().forEach(function (box) { box.checked = !!set[box.value]; });
      if (countEl) countEl.textContent = String(selected.length);
      if (idsField) idsField.value = selected.join(',');
      if (submit) submit.disabled = selected.length === 0;
      save(selected);
    }

    items().forEach(function (box) {
      box.addEventListener('change', function () {
        selected = selected.filter(function (id) { return id !== box.value; });
        if (box.checked) selected.push(box.value);
        render();
      });
    });

    var clear = root.querySelector('[data-bulk-select-clear]');
    if (clear) {
      clear.addEventListener('click', function () {
        selected = [];
        render();
      });
    }

    var all = root.querySelector('[data-bulk-select-all-matching]');
    if (all) {
      all.addEventListener('click', function () {
        var set = {};
        selected.forEach(function (id) { set[id] = true; });
        matchingIds.forEach(function (id) {
          if (!set[id]) {
            selected.push(id);
            set[id] = true;
          }
        });
        render();
      });
    }

    render();
  }

  document.addEventListener('turbolinks:load', setup);
})();
