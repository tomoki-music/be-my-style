'use strict';

// Business(NAKAMA)ヘッダーの☰メニュー(SP)。
// - ☰で開閉し、aria-expanded / aria-label を同期する
// - 「閉じる」・Escape・項目の外側(背景)のクリックで閉じ、☰へフォーカスを戻す
// - 開いている間は Tab / Shift+Tab のフォーカスをメニュー内で循環させる
// music 側の public/header_menu.js は Business ヘッダーには反応しない(二重に開閉しないため)。
(function () {
  var FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"])';

  function setup() {
    var header = document.querySelector('.header_container--business');
    if (!header) return;

    var toggle = header.querySelector('#open');
    var menu = header.querySelector('[data-business-sp-menu]');
    var close = menu && menu.querySelector('#close');
    // Turbolinks のキャッシュから復元した DOM には属性が残るため、要素のプロパティで二重登録を防ぐ。
    if (!toggle || !menu || !close || toggle.businessMenuBound) return;
    toggle.businessMenuBound = true;

    function isOpen() {
      return menu.classList.contains('show');
    }

    function focusables() {
      return Array.prototype.slice.call(menu.querySelectorAll(FOCUSABLE));
    }

    function openMenu() {
      menu.classList.add('show');
      toggle.setAttribute('aria-expanded', 'true');
      toggle.setAttribute('aria-label', 'メニューを閉じる');
      close.focus();
    }

    function closeMenu(returnFocus) {
      if (!isOpen()) return;
      menu.classList.remove('show');
      toggle.setAttribute('aria-expanded', 'false');
      toggle.setAttribute('aria-label', 'メニューを開く');
      if (returnFocus) toggle.focus();
    }

    toggle.addEventListener('click', function () {
      if (isOpen()) {
        closeMenu(true);
      } else {
        openMenu();
      }
    });

    close.addEventListener('click', function () {
      closeMenu(true);
    });

    // 項目(リンク・ボタン・フォーム)以外の背景部分のクリックで閉じる。リンクは遷移に任せる。
    menu.addEventListener('click', function (event) {
      if (event.target.closest('a, button, form')) return;
      closeMenu(true);
    });

    current = { menu: menu, toggle: toggle, isOpen: isOpen, closeMenu: closeMenu, focusables: focusables };
  }

  // document のリスナーは1回だけ登録し、Turbolinks で差し替わった最新のヘッダー(current)を対象にする。
  var current = null;

  document.addEventListener('click', function (event) {
    if (!current || !current.isOpen()) return;
    if (current.menu.contains(event.target) || current.toggle.contains(event.target)) return;
    current.closeMenu(false);
  });

  document.addEventListener('keydown', function (event) {
    if (!current || !current.isOpen()) return;

    if (event.key === 'Escape' || event.key === 'Esc') {
      event.preventDefault();
      current.closeMenu(true);
      return;
    }

    if (event.key !== 'Tab') return;
    var items = current.focusables();
    if (items.length === 0) return;
    var first = items[0];
    var last = items[items.length - 1];
    var inside = current.menu.contains(document.activeElement);
    if (event.shiftKey && (document.activeElement === first || !inside)) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && (document.activeElement === last || !inside)) {
      event.preventDefault();
      first.focus();
    }
  });

  // 開いたままキャッシュされると、戻る操作で開いた状態が復元されるため閉じておく。
  document.addEventListener('turbolinks:before-cache', function () {
    if (current) current.closeMenu(false);
  });

  document.addEventListener('turbolinks:load', setup);
})();
