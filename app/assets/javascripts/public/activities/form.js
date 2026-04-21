document.addEventListener('turbolinks:load', () => {
  const isNew = document.URL.match(/activities\/new/);
  const isEdit = document.URL.match(/\/activities\/[^/]+\/edit/);
  if (!isNew && !isEdit) return;

  const input = document.getElementById('activity_activity_image');
  const previewArea = document.getElementById(isNew ? 'new-activity-image' : 'edit-activity-image');
  if (!input || !previewArea) return;

  input.addEventListener('change', (e) => {
    const file = e.target.files[0];
    if (!file) return;

    const imageContent = previewArea.querySelector('.new-img');
    if (imageContent) {
      imageContent.remove();
    }

    const blobImage = document.createElement('img');
    blobImage.setAttribute('class', 'new-img');
    blobImage.setAttribute('src', window.URL.createObjectURL(file));
    previewArea.appendChild(blobImage);
  });
});
