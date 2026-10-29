'use strict';

// Business ログイン後画面(layouts/business)の SP メニューシートと下部ナビ。
// - 下部ナビの「メニュー」でシートを開閉し、aria-expanded を同期する
// - 「閉じる」・背景・Escape で閉じ、「メニュー」へフォーカスを戻す。開いている間は Tab をシート内で循環させる
// - SP で入力欄にフォーカスがある間は下部ナビを隠し、画面キーボードと入力欄・送信ボタンが重ならないようにする
(function () {
  var FOCUSABLE = 'a[href], button:not([disabled]), input:not([disabled]):not([type="hidden"])';
  // 画面キーボードが出る文字入力だけを対象にする。セレクト・日付・ファイル選択は OS の選択画面が出るだけなので、
  // 下部ナビを隠したままにしない。
  var TYPING_TARGET = 'textarea, input:not([type]), input[type="text"], input[type="search"], input[type="email"], input[type="url"], input[type="tel"], input[type="number"], input[type="password"]';
  var current = null;

  function setup() {
    var toggle = document.getElementById('baMenuToggle');
    var sheet = document.getElementById('baMenuSheet');
    // Business 以外の画面へ移ったら、前の画面のシートを参照しない。
    if (!toggle || !sheet) {
      current = null;
      return;
    }
    // Turbolinks のキャッシュから復元した DOM には属性が残るため、要素のプロパティで二重登録を防ぐ。
    if (toggle.baMenuBound) return;
    toggle.baMenuBound = true;

    function isOpen() {
      return !sheet.hidden;
    }

    function focusables() {
      return Array.prototype.slice.call(sheet.querySelectorAll(FOCUSABLE));
    }

    function open() {
      sheet.hidden = false;
      document.body.classList.add('ba-sheet-open');
      toggle.setAttribute('aria-expanded', 'true');
      var first = sheet.querySelector('.ba-sheet__close');
      if (first) first.focus();
    }

    function close(returnFocus) {
      if (!isOpen()) return;
      sheet.hidden = true;
      document.body.classList.remove('ba-sheet-open');
      toggle.setAttribute('aria-expanded', 'false');
      if (returnFocus) toggle.focus();
    }

    toggle.addEventListener('click', function () {
      if (isOpen()) {
        close(true);
      } else {
        open();
      }
    });

    Array.prototype.forEach.call(sheet.querySelectorAll('[data-ba-sheet-close]'), function (el) {
      el.addEventListener('click', function () {
        close(true);
      });
    });

    current = { sheet: sheet, isOpen: isOpen, close: close, focusables: focusables };
  }

  document.addEventListener('keydown', function (event) {
    if (!current || !current.isOpen()) return;

    if (event.key === 'Escape' || event.key === 'Esc') {
      event.preventDefault();
      current.close(true);
      return;
    }

    if (event.key !== 'Tab') return;
    var items = current.focusables();
    if (items.length === 0) return;
    var first = items[0];
    var last = items[items.length - 1];
    var inside = current.sheet.contains(document.activeElement);
    if (event.shiftKey && (document.activeElement === first || !inside)) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && (document.activeElement === last || !inside)) {
      event.preventDefault();
      first.focus();
    }
  });

  function isTypingTarget(el) {
    return el && el.matches && el.matches(TYPING_TARGET) && el.closest('.ba-main');
  }

  document.addEventListener('focusin', function (event) {
    if (!document.body.classList.contains('ba-body')) return;
    if (isTypingTarget(event.target)) document.body.classList.add('ba-is-typing');
  });

  document.addEventListener('focusout', function (event) {
    if (!isTypingTarget(event.target)) return;
    // 送信ボタンなど次の要素へ移る間に下部ナビが一瞬出て位置がずれないよう、フォーカス移動の後で判定する。
    setTimeout(function () {
      if (!isTypingTarget(document.activeElement)) document.body.classList.remove('ba-is-typing');
    }, 0);
  });

  // 開いたままキャッシュされると、戻る操作で開いた状態が復元されるため閉じておく。
  document.addEventListener('turbolinks:before-cache', function () {
    if (current) current.close(false);
    document.body.classList.remove('ba-is-typing');
  });

  document.addEventListener('turbolinks:load', setup);
})();
