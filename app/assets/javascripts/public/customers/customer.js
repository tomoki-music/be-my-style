document.addEventListener('turbolinks:load', () => {
  if (!document.URL.match(/\/customers\/[^/]+\/edit/)) return;

  const input = document.getElementById('customer_profile_image');
  const previewArea = document.getElementById('edit-image');
  if (!input || !previewArea) return;

  input.addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const imageContent = previewArea.querySelector('.edit-img');
    if (imageContent) {
      imageContent.remove();
    }

    const blobImage = document.createElement('img');
    blobImage.setAttribute('class', 'edit-img');
    blobImage.setAttribute('src', window.URL.createObjectURL(file));
    previewArea.appendChild(blobImage);
  });
});
