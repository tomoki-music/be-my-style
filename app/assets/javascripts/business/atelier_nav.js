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
  var sheetLinkClicked = false;

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

    // メニューのリンクを選んだら、新しい画面が出るまで待たずにシートを閉じる。
    // 開いたままだと、読み込み中の続けてのタップがシートの「ログアウト」などに当たる。
    // 移った先で消える要素なので、フォーカスは「メニュー」へ戻さない。
    sheet.addEventListener('click', function (event) {
      var link = event.target.closest('a[href]');
      if (!link || event.defaultPrevented || event.button !== 0) return;
      if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
      close(false);
      sheetLinkClicked = true;
      // Turbolinks はこのクリックの中で同期的に turbolinks:visit を出す。出なければ(通常の遷移など)何もしない。
      setTimeout(function () {
        sheetLinkClicked = false;
      }, 0);
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

  // 読み取り専用の欄(招待用URLなど)はキーボードが出ないため対象外。
  function isTypingTarget(el) {
    return el && el.matches && el.matches(TYPING_TARGET) && !el.readOnly && el.closest('.ba-main');
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

  // メニューのリンクで Turbolinks の画面遷移が始まったら、表示が切り替わるまでタップを受け付けない。
  // 成功・エラー画面の表示では body が入れ替わり、通信失敗では再読み込みになるため、この状態は残らない。
  document.addEventListener('turbolinks:visit', function () {
    if (!sheetLinkClicked || !document.body.classList.contains('ba-body')) return;
    sheetLinkClicked = false;
    document.body.classList.add('ba-nav-pending');
  });

  function clearNavPending() {
    document.body.classList.remove('ba-nav-pending');
  }

  // 開いたままキャッシュされると、戻る操作で開いた状態が復元されるため閉じておく。
  document.addEventListener('turbolinks:before-cache', function () {
    if (current) current.close(false);
    document.body.classList.remove('ba-is-typing');
    clearNavPending();
  });

  // ブラウザの戻る・進むでページごと復元された場合(bfcache)も、閉じて操作できる状態に戻す。
  window.addEventListener('pageshow', function (event) {
    if (!event.persisted) return;
    if (current) current.close(false);
    clearNavPending();
  });

  document.addEventListener('turbolinks:load', function () {
    clearNavPending();
    setup();
  });
})();
