// イベント詳細の楽曲表で、権限者向け「過去に演奏した人」欄(依頼候補・依頼フォーム)をまとめて開閉する。
// 表示状態は保存しない。turbolinks のキャッシュ復元やブラウザバックでも常にOFFから始める。
// ボタンは type="button" なので参加フォーム(#join_btn)を送信しない。
(function () {
  var SCOPE_SELECTOR = '.js-past-performers-scope';
  var TOGGLE_SELECTOR = '.js-past-performers-toggle';
  var COLLAPSED_CLASS = 'event-show-table--past-performers-collapsed';

  function apply(scope, visible) {
    scope.classList.toggle(COLLAPSED_CLASS, !visible);
    Array.prototype.forEach.call(scope.querySelectorAll(TOGGLE_SELECTOR), function (button) {
      button.setAttribute('aria-expanded', visible ? 'true' : 'false');
      button.textContent = visible ? button.dataset.labelHide : button.dataset.labelShow;
    });
  }

  function resetAll() {
    Array.prototype.forEach.call(document.querySelectorAll(SCOPE_SELECTOR), function (scope) {
      apply(scope, false);
    });
  }

  document.addEventListener('click', function (event) {
    var button = event.target.closest && event.target.closest(TOGGLE_SELECTOR);
    if (!button) return;
    var scope = button.closest(SCOPE_SELECTOR);
    if (!scope) return;
    event.preventDefault();
    apply(scope, scope.classList.contains(COLLAPSED_CLASS));
  });

  document.addEventListener('turbolinks:load', resetAll);
  document.addEventListener('turbolinks:before-cache', resetAll);
  window.addEventListener('pageshow', resetAll);
})();
