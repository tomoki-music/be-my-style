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
  if (!form) return;

  const checkboxes = form.querySelectorAll('input[type="checkbox"]');
  const submitBtn = document.getElementById('submit_join_form');

  const toggleButton = () => {
    const isChecked = Array.from(checkboxes).some(cb => cb.checked);
    submitBtn.disabled = !isChecked;
  };

  checkboxes.forEach(cb => cb.addEventListener('change', toggleButton));
  toggleButton();
});

document.addEventListener('DOMContentLoaded', () => {
  const box = document.querySelector('.responsive-box');
  const indicator = document.getElementById('scroll-indicator');
  if (!box || !indicator) return;

  const checkScroll = () => {
    if (box.scrollWidth > box.clientWidth) {
      const atEnd = box.scrollLeft + box.clientWidth >= box.scrollWidth - 5;
      indicator.style.display = atEnd ? 'none' : 'block';
    } else {
      indicator.style.display = 'none';
    }
  };

  checkScroll();
  window.addEventListener('resize', checkScroll);
  box.addEventListener('scroll', checkScroll);
});

document.addEventListener('turbolinks:load', function() {
  var el = document.getElementById('songs');
  if (!el) return;

  Sortable.create(el, {
    handle: '.drag-handle',
    animation: 150,
    onEnd: function () {
      document.querySelectorAll('#songs .nested-fields').forEach(function(field, index) {
        var posInput = field.querySelector('.song-position');
        if (posInput) {
          posInput.value = index + 1;
        }
      });
    }
  });
});

document.addEventListener('DOMContentLoaded', () => {
  const btnAll = document.getElementById('filter-all');
  const btnComplete = document.getElementById('filter-complete');
  const btnVacant = document.getElementById('filter-vacant');
  const rows = document.querySelectorAll('.event-songs-table tbody tr');

  if (!btnAll || !btnComplete || !btnVacant) return;

  btnAll.addEventListener('click', () => {
    rows.forEach(row => row.style.display = '');
  });

  btnComplete.addEventListener('click', () => {
    rows.forEach(row => {
      row.style.display = row.classList.contains('complete') ? '' : 'none';
    });
  });

  btnVacant.addEventListener('click', () => {
    rows.forEach(row => {
      row.style.display = row.classList.contains('vacant') ? '' : 'none';
    });
  });
});

document.addEventListener('DOMContentLoaded', () => {
  $('[data-toggle="popover"]').popover({
    html: true
  });
});
