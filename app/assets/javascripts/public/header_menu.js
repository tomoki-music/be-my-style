'use strict';

if (document.URL.match(/public/)){

  window.onload = function(){
    const open = document.getElementById('open');
    const menu = document.querySelector('.customer-menu-sp');
    const close = document.getElementById('close');

    open.addEventListener('click', () => {
      menu.classList.add('show');
    });

    close.addEventListener('click', () => {
      menu.classList.remove('show');
    });

    menu.addEventListener('click', () => {
      close.click();
    });

  }

}