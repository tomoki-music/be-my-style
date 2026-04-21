document.addEventListener('turbolinks:load', () => {
  const isNew = document.URL.match(/communities\/new/);
  const isEdit = document.URL.match(/\/communities\/[^/]+\/edit/);
  if (!isNew && !isEdit) return;

  const input = document.getElementById('community_community_image');
  const previewArea = document.getElementById(isNew ? 'new-community-image' : 'edit-community-image');
  const previewClass = isNew ? 'new-img' : 'edit-img';
  if (!input || !previewArea) return;

  input.addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const imageContent = previewArea.querySelector(`.${previewClass}`);
    if (imageContent) {
      imageContent.remove();
    }

    const blobImage = document.createElement('img');
    blobImage.setAttribute('class', previewClass);
    blobImage.setAttribute('src', window.URL.createObjectURL(file));
    previewArea.appendChild(blobImage);
  });
});
