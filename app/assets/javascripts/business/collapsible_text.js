'use strict';

// 長い文章を最初は3行までに折りたたむ(プロジェクト詳細の概要)。
// - 3行に収まらないときだけ「もっと見る」を出し、押すと全文、「閉じる」で3行表示に戻す
// - JavaScript が動かない環境では折りたたまず、全文をそのまま表示する
(function () {
  var READY_CLASS = 'is-collapsible';
  var COLLAPSED_CLASS = 'is-collapsed';

  function parts(container) {
    var toggle = container.querySelector('[data-collapsible-toggle]');
    var content = toggle && document.getElementById(toggle.getAttribute('aria-controls'));
    return { toggle: toggle, content: content };
  }

  function setExpanded(container, expanded) {
    var p = parts(container);
    container.classList.toggle(COLLAPSED_CLASS, !expanded);
    p.toggle.setAttribute('aria-expanded', expanded ? 'true' : 'false');
    p.toggle.textContent = p.toggle.getAttribute(expanded ? 'data-label-less' : 'data-label-more');
  }

  // 3行に折りたたんだ状態ではみ出すかを測り、はみ出すときだけボタンを出す。
  // 展開中に画面幅が変わっても、展開したままにする(ボタンの要否だけ測り直す)。
  function measure(container) {
    var p = parts(container);
    if (!p.toggle || !p.content) return;

    var expanded = p.toggle.getAttribute('aria-expanded') === 'true';
    container.classList.add(READY_CLASS, COLLAPSED_CLASS);
    var overflows = p.content.scrollHeight - p.content.clientHeight > 1;
    container.classList.toggle(COLLAPSED_CLASS, overflows && !expanded);
    if (!overflows) {
      container.classList.remove(READY_CLASS);
      p.toggle.setAttribute('aria-expanded', 'false');
    }
    p.toggle.hidden = !overflows;
  }

  function measureAll() {
    Array.prototype.forEach.call(document.querySelectorAll('[data-collapsible]'), measure);
  }

  document.addEventListener('click', function (event) {
    var toggle = event.target.closest && event.target.closest('[data-collapsible-toggle]');
    if (!toggle) return;
    var container = toggle.closest('[data-collapsible]');
    setExpanded(container, toggle.getAttribute('aria-expanded') !== 'true');
  });

  var resizeTimer = null;
  window.addEventListener('resize', function () {
    window.clearTimeout(resizeTimer);
    resizeTimer = window.setTimeout(measureAll, 150);
  });

  document.addEventListener('turbolinks:load', measureAll);
  document.addEventListener('DOMContentLoaded', measureAll);
  // 画像やWebフォントの読み込みで高さが変わるため、読み込み完了後にも測り直す。
  window.addEventListener('load', measureAll);
})();
