'use strict';

document.addEventListener('turbolinks:load', function(){

  const open = document.getElementById('open');
  const menu = document.querySelector('.customer-menu-sp');
  const close = document.getElementById('close');

  if(!open || !menu || !close) return;

  open.addEventListener('click', () => {
    menu.classList.add('show');
  });

  close.addEventListener('click', () => {
    menu.classList.remove('show');
  });

  menu.addEventListener('click', () => {
    close.click();
  });

  // 「その他」アコーディオン(<details>)。
  // - トグルの click は .customer-menu-sp まで伝播させない。伝播すると
  //   「メニュー内クリックで閉じる」挙動(このファイルと business/header_menu_nakama.js
  //   の両方)が走り、開いた直後に SP メニューごと閉じてしまうため。
  //   stopPropagation は <details> の開閉(既定動作)には影響しない。
  // - 開閉状態は <details> のネイティブ動作。ここでは summary の aria-expanded を同期する。
  const others = menu.querySelector('.menu-sp-others');
  const othersToggle = others && others.querySelector('.menu-sp-others__toggle');
  if (others && othersToggle) {
    othersToggle.addEventListener('click', (event) => {
      event.stopPropagation();
    });

    const syncExpanded = () => {
      othersToggle.setAttribute('aria-expanded', others.open ? 'true' : 'false');
    };
    syncExpanded();
    others.addEventListener('toggle', syncExpanded);
  }

});
