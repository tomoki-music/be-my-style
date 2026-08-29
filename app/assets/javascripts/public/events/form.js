document.addEventListener('turbolinks:load', () => {
  const isNew = document.URL.match(/events\/new/);
  const isEdit = document.URL.match(/\/events\/[^/]+\/edit/);
  if (!isNew && !isEdit) return;

  const input = document.getElementById('event_event_image');
  const previewArea = document.getElementById(isNew ? 'new-event-image' : 'edit-event-image');
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

// 参加フォーム(#join_btn)の「参加確認画面へ」ボタン制御。
// 参加パート用 checkbox (.js-join-part-checkbox / name="event[join_part_ids][]") の
// checked 件数だけを見る。楽曲表内には form= 属性で #entry-invitation-form へ紐づく
// 依頼用 checkbox (.js-entry-invitation-checkbox) も DOM 上は存在するが、
// 2つのフォームのボタン制御を完全に分離するため、それらは絶対に参照しない。
const setupJoinSubmitToggle = () => {
  const form = document.getElementById('join_btn');
  const submitBtn = document.getElementById('submit_join_form');
  if (!form || !submitBtn) return;

  const joinCheckboxes = () =>
    form.querySelectorAll('input.js-join-part-checkbox[name="event[join_part_ids][]"]');

  const sync = () => {
    submitBtn.disabled = !Array.prototype.some.call(joinCheckboxes(), (cb) => cb.checked);
  };

  // ハンドラの多重登録を避ける(turbolinks:load はフォームが新ノードなので毎回 bind、
  // pageshow の bfcache 復元では同一ノードなので guard で二重 bind を防ぐ)。
  if (form.dataset.joinToggleBound !== '1') {
    form.dataset.joinToggleBound = '1';
    form.addEventListener('change', (e) => {
      const t = e.target;
      if (t && t.classList && t.classList.contains('js-join-part-checkbox')) sync();
    });
  }
  sync();
};

document.addEventListener('turbolinks:load', setupJoinSubmitToggle);
window.addEventListener('pageshow', setupJoinSubmitToggle);

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

document.addEventListener('turbolinks:load', () => {
  const select = document.querySelector('.js-song-template-select');
  const addTemplateBtn = document.querySelector('.js-add-template-song-btn');
  const addSongBtn = document.querySelector('.js-add-song-field-btn');
  if (!select || !addTemplateBtn || !addSongBtn) return;

  let pendingTemplate = null;

  addTemplateBtn.addEventListener('click', () => {
    if (select.value === '') {
      alert('テンプレートを選択してください。');
      return;
    }

    const templates = JSON.parse(select.dataset.templates || '[]');
    pendingTemplate = templates[Number(select.value)];
    if (!pendingTemplate) return;

    addSongBtn.click();
  });

  $('body').on('cocoon:after-insert', function (e, insertedItem) {
    if (!pendingTemplate) return;

    const insertedNode = insertedItem[0];
    if (!insertedNode.querySelector('.song-layout')) return;

    const template = pendingTemplate;
    pendingTemplate = null;

    const applyValue = (fieldName, value) => {
      const field = insertedNode.querySelector('[name*="[' + fieldName + ']"]');
      if (field && value !== null && value !== undefined) {
        field.value = value;
      }
    };

    applyValue('song_name', template.song_name);
    applyValue('artist_name', template.artist_name);
    applyValue('youtube_url', template.youtube_url);
    applyValue('chord_sheet_url', template.chord_sheet_url);
    applyValue('tab_sheet_url', template.tab_sheet_url);
    applyValue('musical_key', template.musical_key);
    applyValue('capo', template.capo);
    applyValue('chord_sheet_note', template.chord_sheet_note);
    applyValue('introduction', template.introduction);

    select.value = '';
  });
});
