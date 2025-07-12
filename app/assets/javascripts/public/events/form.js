if (document.URL.match(/events\/new/)){
  document.addEventListener('DOMContentLoaded', () => {
    const createImageHTML = (blob) => {
      const imageElement = document.getElementById('new-event-image');
      const blobImage = document.createElement('img');
      blobImage.setAttribute('class', 'new-img')
      blobImage.setAttribute('src', blob);
      imageElement.appendChild(blobImage);
    };
    document.getElementById('event_event_image').addEventListener('change', (e) =>{
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

if (document.URL.match(/events\/edit/)){
  document.addEventListener('DOMContentLoaded', () => {
    const createImageHTML = (blob) => {
      const imageElement = document.getElementById('edit-event-image');
      const blobImage = document.createElement('img');
      blobImage.setAttribute('class', 'new-img')
      blobImage.setAttribute('src', blob);
      imageElement.appendChild(blobImage);
    };
    document.getElementById('event_event_image').addEventListener('change', (e) =>{
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

document.addEventListener('turbolinks:load', () => {
  $('body').on('cocoon:after-insert', function(e, insertedItem) {
    const insertedNode = insertedItem[0];
    if (insertedNode.querySelector('.join-part-layout')) {
      const joinPartLayout = insertedNode.querySelector('.join-part-layout');
      const addButton = insertedNode.querySelector('.js-add-join-part-field-btn');

      const defaultParts = ["Vocal", "Guitar", "Bass", "Drums", "Keyboard"];

      const selectElements = joinPartLayout.querySelectorAll('select[name*="join_part_name"]');

      // もし1つも空パートがなければ、まず1回クリックして1個目を作る
      if (selectElements.length === 0) {
        addButton.click();
      }

      // 1つ目のセレクトを確実に取得（少し待つ）
      setTimeout(() => {
        const selects = joinPartLayout.querySelectorAll('select[name*="join_part_name"]');
        if (selects.length === 0) return;

        // 1つ目は必ず Vocal
        selects[0].value = defaultParts[0];

        // 残りを順番に追加する関数
        let index = 1;
        const addNextPart = () => {
          if (index >= defaultParts.length) return;

          addButton.click();

          setTimeout(() => {
            const currentSelects = joinPartLayout.querySelectorAll('select[name*="join_part_name"]');
            const lastSelect = currentSelects[currentSelects.length - 1];
            if (lastSelect) {
              lastSelect.value = defaultParts[index];
            }
            index++;
            addNextPart();
          }, 100);
        };
        addNextPart();
      }, 100);
    }
  });
});

document.addEventListener('DOMContentLoaded', () => {
  const form = document.querySelector('.event-songs-join-form');
  const checkboxes = form.querySelectorAll('input[type="checkbox"]');
  const submitBtn = document.getElementById('submit_join_form');

  const toggleButton = () => {
    const isChecked = Array.from(checkboxes).some(cb => cb.checked);
    submitBtn.disabled = !isChecked;
  };

  checkboxes.forEach(cb => {
    cb.addEventListener('change', toggleButton);
  });

  toggleButton();
});