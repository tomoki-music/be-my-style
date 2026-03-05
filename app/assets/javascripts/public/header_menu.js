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

});