//= require jquery3
//= require popper
//= require bootstrap-sprockets
//= require bootstrap
//= require rails-ujs
//= require activestorage
//= require turbolinks
//= require cocoon
//= require_tree .

if (document.URL.match(/sign_up/)){
  document.addEventListener('DOMContentLoaded', () => {
    const createImageHTML = (blob) => {
      const imageElement = document.getElementById('registration-image');
      const blobImage = document.createElement('img');
      blobImage.setAttribute('class', 'registration-img')
      blobImage.setAttribute('src', blob);
      imageElement.appendChild(blobImage);
    };
    document.getElementById('customer_profile_image').addEventListener('change', (e) =>{
      const imageContent = document.querySelector('img'); 
      if (imageContent){ 
        imageContent.remove(); 
      }
      const file = e.target.files[0];
      const blob = window.URL.createObjectURL(file);
      createImageHTML(blob);
    });
  });
}

document.addEventListener('DOMContentLoaded', () => {
  const internalLinks = document.querySelectorAll('a[href^="#"]');

  internalLinks.forEach(link => {
    link.addEventListener('click', function(e) {
      const targetId = this.getAttribute('href');

      if (targetId === "#" || !targetId) return;

      const targetElement = document.querySelector(targetId);

      if (targetElement) {
        e.preventDefault();
        targetElement.scrollIntoView({
          behavior: 'smooth',
          block: 'start',
        });

        history.pushState(null, null, targetId);
      }
    });
  });
});

$(document).on('turbolinks:load', function() {
  const $popover = $('#help-popover');

  $popover.popover({
    trigger: 'click',
    html: true,
    placement: 'bottom'
  });

  // 他をタップしたら閉じる（スマホ対応）
  $(document).on('click touchstart', function(e) {
    if (!$popover.is(e.target) && $popover.has(e.target).length === 0 && $('.popover').has(e.target).length === 0) {
      $popover.popover('hide');
    }
  });
});
