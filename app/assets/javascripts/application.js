//= require jquery3
//= require popper
//= require bootstrap-sprockets
//= require bootstrap
//= require rails-ujs
//= require activestorage
//= require turbolinks
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
