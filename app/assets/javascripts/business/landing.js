'use strict';

// Business のログイン前の紹介ページ(body.ba-lp)の「本文へスキップ」。
// ページ内リンクで移動しても Chrome ではフォーカスがリンクに残るため、移動先の本文(tabindex="-1")へフォーカスを移す。
document.addEventListener('click', function (event) {
  var link = event.target.closest && event.target.closest('.ba-lp-skip');
  if (!link) return;

  var target = document.getElementById(link.getAttribute('href').slice(1));
  if (!target) return;

  event.preventDefault();
  target.focus();
  target.scrollIntoView();
});
