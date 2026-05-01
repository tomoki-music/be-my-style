document.addEventListener('turbolinks:load', function() {
  var csrfTokenEl = document.querySelector('meta[name="csrf-token"]');
  if (!csrfTokenEl) return;

  var csrfToken = csrfTokenEl.getAttribute('content');

  document.querySelectorAll('[data-reaction-url]').forEach(function(btn) {
    btn.addEventListener('click', function(e) {
      e.preventDefault();
      var url = btn.dataset.reactionUrl;

      btn.disabled = true;

      fetch(url, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        }
      })
        .then(function(res) {
          if (!res.ok) {
            throw new Error('reaction request failed: ' + res.status);
          }
          return res.json();
        })
        .then(function(data) {
          var countEl = btn.querySelector('.reaction-count');
          if (countEl) {
            countEl.textContent = data.count > 0 ? data.count : '';
          }
          if (data.reacted) {
            btn.classList.add('activity-reaction-btn--active');
          } else {
            btn.classList.remove('activity-reaction-btn--active');
          }
        })
        .catch(function() {
          // ネットワークエラーやサーバーエラー時は表示を変えずそのまま
        })
        .finally(function() {
          btn.disabled = false;
        });
    });
  });
});
