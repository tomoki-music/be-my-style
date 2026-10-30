'use strict';

// コミュニティ・プロジェクトの通常画面の「招待用URL」(business/shared/_share_link)。
// - 「URLをコピー」でクリップボードへ書き込み、結果を role="status" の欄に文字で出す(読み上げにも伝わる)
// - Clipboard API が使えない・失敗したときは古いコピー命令を試し、それも無理なら URL 欄を選択して手動コピーを案内する
// - ボタンは JavaScript が動くときだけ表示する(動かない環境でも URL 欄から選択してコピーできる)
// コピーは画面上の操作だけで、サーバーへは何も送らない。
(function () {
  var SUCCESS_MESSAGE = 'URLをコピーしました';
  var FAILURE_MESSAGE = 'コピーできませんでした。選択されたURLを長押し（PCは Ctrl+C / ⌘+C）してコピーしてください。';

  function showButtons() {
    var buttons = document.querySelectorAll('[data-share-copy]');
    Array.prototype.forEach.call(buttons, function (button) {
      button.hidden = false;
    });
  }

  function selectAll(input) {
    input.focus();
    input.select();
    // iOS Safari は select() だけでは範囲が選ばれないことがある。
    try {
      input.setSelectionRange(0, input.value.length);
    } catch (e) {
      // setSelectionRange に対応しない欄は select() の結果のままにする。
    }
  }

  function legacyCopy(input) {
    selectAll(input);
    try {
      return document.execCommand('copy');
    } catch (e) {
      return false;
    }
  }

  // 同じ文言を続けて出しても読み上げられるよう、いったん空にしてから書き込む。
  function announce(status, message, isError) {
    if (!status) return;
    status.textContent = '';
    status.classList.toggle('is-error', !!isError);
    window.setTimeout(function () {
      status.textContent = message;
    }, 50);
  }

  function copy(button) {
    var input = document.getElementById(button.getAttribute('data-share-copy'));
    var status = document.getElementById(button.getAttribute('data-share-status'));
    if (!input) return;

    function done() {
      announce(status, SUCCESS_MESSAGE, false);
    }

    function fallback() {
      if (legacyCopy(input)) {
        done();
      } else {
        selectAll(input);
        announce(status, FAILURE_MESSAGE, true);
      }
    }

    if (navigator.clipboard && window.isSecureContext) {
      navigator.clipboard.writeText(input.value).then(done, fallback);
    } else {
      fallback();
    }
  }

  function isShareUrl(el) {
    return el && el.matches && el.matches('[data-share-url]');
  }

  // 手動でコピーしやすいよう、URL 欄を押したら全体を選ぶ。
  // フォーカス時(キーボード)に加えてクリック時にも選ぶ(マウス・タップではフォーカスの直後に選択が解除されるため)。
  document.addEventListener('click', function (event) {
    var button = event.target.closest && event.target.closest('[data-share-copy]');
    if (button) copy(button);
    if (isShareUrl(event.target)) selectAll(event.target);
  });

  document.addEventListener('focusin', function (event) {
    if (isShareUrl(event.target)) {
      window.setTimeout(function () { selectAll(event.target); }, 0);
    }
  });

  document.addEventListener('turbolinks:load', showButtons);
  document.addEventListener('DOMContentLoaded', showButtons);
})();
