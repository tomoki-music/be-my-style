if (document.URL.match(/customers\/edit/)){
  document.addEventListener('DOMContentLoaded', () => {
    const createImageHTML = (blob) => {
      const imageElement = document.getElementById('edit-image');
      const blobImage = document.createElement('img');
      blobImage.setAttribute('class', 'edit-img')
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
