'use strict';

if (document.URL.match(/admin/)){
  window.onload = function(){
    const adminOpen = document.getElementById('admin-open');
    const adminMenu = document.querySelector('.admin-menu-sp');
    const adminClose = document.getElementById('admin-close');

    adminOpen.addEventListener('click', () => {
      adminMenu.classList.add('show');
    });

    adminClose.addEventListener('click', () => {
      adminMenu.classList.remove('show');
    });

    adminMenu.addEventListener('click', () => {
      adminClose.click();
    });
  }
};