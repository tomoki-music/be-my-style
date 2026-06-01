document.addEventListener('turbolinks:load', function () {
  var csrfToken = document.querySelector('meta[name="csrf-token"]');

  document.querySelectorAll('.js-cheer-btn').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var reactionType     = btn.dataset.reactionType;
      var targetCustomerId = btn.dataset.targetCustomerId;
      var countEl          = btn.querySelector('.growth-card__reaction-count');

      fetch('/singing/cheer_reactions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': csrfToken ? csrfToken.content : ''
        },
        body: JSON.stringify({
          reaction_type:      reactionType,
          target_customer_id: targetCustomerId
        })
      })
        .then(function (res) { return res.json(); })
        .then(function (data) {
          if (data.reacted) {
            btn.classList.add('is-reacted');
          } else {
            btn.classList.remove('is-reacted');
          }

          if (countEl) {
            countEl.textContent = data.count;
            if (data.count > 0) {
              countEl.classList.remove('is-hidden');
            } else {
              countEl.classList.add('is-hidden');
            }
          }
        })
        .catch(function () {});
    });
  });
});
