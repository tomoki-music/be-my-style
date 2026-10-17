// イベント作成・編集フォームの「締め切り自動リマインド」欄(公開画面・管理画面共通)。
// 入力変更のたびに保存前プレビューAPIへ問い合わせ、送信予定日時・状態・送信メッセージを差し替える。
// プレビューAPIは表示用HTMLを返すだけで、保存・送信はしない。
// require_tree で直前のファイルと連結されるため、先頭の ; で直前の式の呼び出しとして解釈されるのを防ぐ。
;(() => {
  const EVENT_FIELDS = [
    'event_name', 'event_start_time', 'event_end_time', 'event_entry_deadline',
    'request_deadline', 'entrance_fee', 'place', 'community_id'
  ];
  const DEBOUNCE_MS = 500;
  // Turbolinks のキャッシュ復元では DOM の属性も復元されるため、初期化済みの判定は WeakSet で持つ。
  const initialized = new WeakSet();

  const csrfToken = () => {
    const meta = document.querySelector('meta[name="csrf-token"]');
    return meta ? meta.content : '';
  };

  // サーバー側(Ruby の String#length)と同じく、前後の空白を除いたコードポイント数で数える。
  const countChars = (text) => Array.from(text.replace(/\r\n?/g, '\n').trim()).length;

  const setupItem = (root, form, item) => {
    const url = root.dataset.previewUrl;
    const kind = item.dataset.reminderKind;
    const field = (name) => item.querySelector(`[data-reminder-field="${name}"]`);
    const textarea = field('custom_message');
    const counter = item.querySelector('[data-reminder-counter]');
    const statusArea = item.querySelector('[data-reminder-live="status"]');
    const messageArea = item.querySelector('[data-reminder-live="message"]');
    let timer = null;
    let sequence = 0;

    const buildBody = () => {
      const data = new FormData();
      EVENT_FIELDS.forEach((name) => {
        const element = form.elements[`event[${name}]`];
        if (element && !element.disabled && element.value !== undefined) data.append(`event[${name}]`, element.value);
      });
      data.append('reminder[kind]', kind);
      const enabled = field('enabled');
      if (enabled) data.append('reminder[enabled]', enabled.checked ? '1' : '0');
      const channel = item.querySelector('[data-reminder-field="channel"]:checked');
      if (channel && !channel.disabled) data.append('reminder[channel]', channel.value);
      const lead = field('lead_hours');
      if (lead && !lead.disabled) data.append('reminder[lead_hours]', lead.value);
      if (textarea && !textarea.disabled) data.append('reminder[custom_message]', textarea.value);
      return data;
    };

    const fetchPreview = () => {
      const current = ++sequence;
      return fetch(url, {
        method: 'POST',
        headers: { Accept: 'application/json', 'X-CSRF-Token': csrfToken() },
        credentials: 'same-origin',
        body: buildBody()
      })
        .then((response) => {
          if (!response.ok) throw new Error(`preview ${response.status}`);
          return response.json();
        })
        .then((json) => {
          // 入力が続いた場合、古い応答で新しい表示を上書きしない。
          if (current === sequence) {
            statusArea.innerHTML = json.status_html;
            messageArea.innerHTML = json.message_html;
          }
          return json;
        })
        .catch((error) => {
          if (current === sequence && !messageArea.querySelector('[data-reminder-preview-error]')) {
            messageArea.insertAdjacentHTML(
              'afterbegin',
              '<p class="deadline-reminder-settings__errors" data-reminder-preview-error>プレビューを取得できませんでした。時間をおいて「プレビューを更新」を押してください。</p>'
            );
          }
          throw error;
        });
    };

    const schedulePreview = () => {
      clearTimeout(timer);
      timer = setTimeout(() => fetchPreview().catch(() => {}), DEBOUNCE_MS);
    };

    const updateCounter = () => {
      if (!textarea || !counter) return;
      const max = Number(textarea.dataset.maxLength);
      const length = countChars(textarea.value);
      counter.textContent = `${length.toLocaleString()} / ${max.toLocaleString()}文字`;
      counter.classList.toggle('deadline-reminder-settings__counter--over', length > max);
    };

    item.addEventListener('click', (event) => {
      const button = event.target.closest('[data-reminder-action]');
      if (!button || button.disabled) return;

      const action = button.dataset.reminderAction;
      if (action === 'refresh') {
        fetchPreview().catch(() => {});
      } else if (action === 'reset_auto') {
        if (textarea.value.trim() !== '' && !window.confirm('編集欄を空にして、自動生成の文章に戻しますか？（保存するまで設定は変わりません）')) return;
        textarea.value = '';
        updateCounter();
        fetchPreview().catch(() => {});
      } else if (action === 'fill_auto') {
        fetchPreview().then((json) => {
          if (!json.auto_body) {
            window.alert('締め切りと開催日時を入力すると、自動生成の文章を作れます。');
            return;
          }
          if (textarea.value.trim() !== '' && !window.confirm('編集欄の文章を、現在の自動生成文で置き換えますか？')) return;
          textarea.value = json.auto_body;
          updateCounter();
          fetchPreview().catch(() => {});
        }).catch(() => {});
      }
    });

    item.addEventListener('input', (event) => {
      if (event.target === textarea) updateCounter();
      if (event.target.closest('[data-reminder-field]')) schedulePreview();
    });
    item.addEventListener('change', (event) => {
      if (event.target.closest('[data-reminder-field]')) schedulePreview();
    });

    updateCounter();
    return schedulePreview;
  };

  const setup = (root) => {
    if (initialized.has(root)) return;
    initialized.add(root);

    const form = root.closest('form');
    if (!form || !root.dataset.previewUrl) return;

    const schedulers = Array.from(root.querySelectorAll('[data-reminder-kind]')).map((item) => setupItem(root, form, item));
    const eventFieldNames = EVENT_FIELDS.map((name) => `event[${name}]`);
    const onEventFieldChange = (event) => {
      if (eventFieldNames.includes(event.target.name)) schedulers.forEach((schedule) => schedule());
    };
    form.addEventListener('input', onEventFieldChange);
    form.addEventListener('change', onEventFieldChange);
  };

  document.addEventListener('turbolinks:load', () => {
    document.querySelectorAll('.deadline-reminder-settings[data-preview-url]').forEach(setup);
  });
})();
